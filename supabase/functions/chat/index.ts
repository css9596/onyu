// chat
//
// POST /functions/v1/chat
// Body: { conversation_id?: string | null, content: string }
// Auth: Bearer <user JWT>
//
// Sends a message in a conversation, calls Claude with the user's saju as
// context, persists both the user and assistant messages, and returns them.
//
// If MOCK_ANTHROPIC=true is set in env, returns a deterministic stub response
// so the full pipeline can be tested without an Anthropic API key.

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import Anthropic from "@anthropic-ai/sdk";

const HISTORY_LIMIT = 20;          // last N messages sent as context
const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const MAX_OUTPUT_TOKENS = 2048;
const CONTENT_MAX_CHARS = 4000;
const MOCK_ANTHROPIC = Deno.env.get("MOCK_ANTHROPIC") === "true";

interface ChatRequest {
  conversation_id?: string | null;
  content: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
  if (req.method !== "POST") {
    return cors(jsonResp({ data: null, error: "method_not_allowed" }, 405));
  }

  // ---- Auth ----
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return cors(jsonResp({ data: null, error: "missing_bearer" }, 401));
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey =
    Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return cors(jsonResp({ data: null, error: "server_misconfigured" }, 500));
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: userRes, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return cors(jsonResp({ data: null, error: "unauthenticated" }, 401));
  }
  const userId = userRes.user.id;

  // ---- Parse body ----
  let body: ChatRequest;
  try {
    body = await req.json();
  } catch {
    return cors(jsonResp({ data: null, error: "invalid_json" }, 400));
  }
  if (typeof body?.content !== "string" || body.content.trim().length === 0) {
    return cors(jsonResp({ data: null, error: "content_required" }, 400));
  }
  const content = body.content.trim();
  if (content.length > CONTENT_MAX_CHARS) {
    return cors(jsonResp({ data: null, error: "content_too_long" }, 400));
  }

  // ---- Load profile + saju ----
  const [profileRes, sajuRes] = await Promise.all([
    userClient
      .from("profiles")
      .select("subscription_tier, daily_message_limit")
      .eq("id", userId)
      .single(),
    userClient
      .from("saju_profiles")
      .select("pillars")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);
  const profile = profileRes.data;
  if (!profile) {
    return cors(jsonResp({ data: null, error: "profile_missing" }, 500));
  }
  if (!sajuRes.data) {
    return cors(jsonResp({ data: null, error: "saju_profile_required" }, 403));
  }
  const sajuPillars = sajuRes.data.pillars as Record<string, unknown>;

  // ---- Daily limit (free tier only) ----
  if (profile.subscription_tier === "free") {
    const usageRes = await userClient
      .from("daily_usage_view")
      .select("user_message_count")
      .eq("usage_date", currentSeoulDate())
      .maybeSingle();
    const used = (usageRes.data?.user_message_count as number | undefined) ?? 0;
    const limit = profile.daily_message_limit as number;
    if (used >= limit) {
      return cors(jsonResp(
        { data: null, error: "daily_limit_reached", limit, used },
        429,
      ));
    }
  }

  // ---- Conversation: validate or create ----
  let conversationId: string;
  if (body.conversation_id) {
    const convRes = await userClient
      .from("conversations")
      .select("id")
      .eq("id", body.conversation_id)
      .maybeSingle();
    if (!convRes.data) {
      return cors(jsonResp({ data: null, error: "conversation_not_found" }, 404));
    }
    conversationId = convRes.data.id as string;
  } else {
    const newConvRes = await userClient
      .from("conversations")
      .insert({ user_id: userId, title: content.substring(0, 30) })
      .select("id")
      .single();
    if (newConvRes.error || !newConvRes.data) {
      return cors(jsonResp(
        { data: null, error: `conversation_create_failed: ${newConvRes.error?.message}` },
        500,
      ));
    }
    conversationId = newConvRes.data.id as string;
  }

  // ---- Load last N messages (chronological) ----
  const histRes = await userClient
    .from("messages")
    .select("role, content")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: false })
    .limit(HISTORY_LIMIT);
  if (histRes.error) {
    return cors(jsonResp(
      { data: null, error: `history_load_failed: ${histRes.error.message}` },
      500,
    ));
  }
  const history = (histRes.data ?? []).reverse();

  // ---- System prompt (admin client; app_config has no client RLS) ----
  const cfgRes = await adminClient
    .from("app_config")
    .select("value")
    .eq("key", "chat_system_prompt")
    .maybeSingle();
  if (cfgRes.error || !cfgRes.data?.value) {
    return cors(jsonResp({ data: null, error: "system_prompt_missing" }, 500));
  }
  const systemPrompt = (cfgRes.data.value as string).replace(
    "{{user_saju}}",
    formatSaju(sajuPillars),
  );

  // ---- Call Claude (or mock) ----
  let assistantContent: string;
  let tokensIn = 0;
  let tokensOut = 0;

  if (MOCK_ANTHROPIC) {
    assistantContent =
      `[mock 응답] "${content.substring(0, 40)}…" 에 대한 풀이 자리. ` +
      `실제 Claude 호출은 ANTHROPIC_API_KEY 설정 후 활성화됩니다. ` +
      `(현재 사주: ${formatSaju(sajuPillars)})`;
  } else {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return cors(jsonResp({ data: null, error: "anthropic_key_missing" }, 500));
    }
    try {
      const client = new Anthropic({ apiKey });
      const claudeResp = await client.messages.create({
        model: ANTHROPIC_MODEL,
        max_tokens: MAX_OUTPUT_TOKENS,
        system: systemPrompt,
        messages: [
          ...history.map((m) => ({
            role: m.role as "user" | "assistant",
            content: m.content as string,
          })),
          { role: "user", content },
        ],
      });
      const block = claudeResp.content[0];
      assistantContent = block?.type === "text" ? block.text : "(빈 응답)";
      tokensIn = claudeResp.usage.input_tokens;
      tokensOut = claudeResp.usage.output_tokens;
    } catch (e) {
      return cors(jsonResp(
        { data: null, error: `anthropic_error: ${(e as Error).message}` },
        502,
      ));
    }
  }

  // ---- Save messages (user first, then assistant) ----
  const userMsgRes = await userClient
    .from("messages")
    .insert({ conversation_id: conversationId, role: "user", content })
    .select("id, content, created_at")
    .single();
  if (userMsgRes.error) {
    return cors(jsonResp(
      { data: null, error: `user_msg_save_failed: ${userMsgRes.error.message}` },
      500,
    ));
  }
  const asstMsgRes = await userClient
    .from("messages")
    .insert({
      conversation_id: conversationId,
      role: "assistant",
      content: assistantContent,
      tokens_input: tokensIn || null,
      tokens_output: tokensOut || null,
    })
    .select("id, content, tokens_input, tokens_output, created_at")
    .single();
  if (asstMsgRes.error) {
    return cors(jsonResp(
      { data: null, error: `asst_msg_save_failed: ${asstMsgRes.error.message}` },
      500,
    ));
  }

  return cors(jsonResp({
    data: {
      conversation_id: conversationId,
      user_message: userMsgRes.data,
      assistant_message: asstMsgRes.data,
    },
    error: null,
  }, 200));
});

function currentSeoulDate(): string {
  // Asia/Seoul is UTC+9, no DST.
  const seoul = new Date(Date.now() + 9 * 60 * 60 * 1000);
  return seoul.toISOString().split("T")[0];
}

function formatSaju(pillars: Record<string, unknown>): string {
  const y = pillars.year ?? "?";
  const m = pillars.month ?? "?";
  const d = pillars.day ?? "?";
  const h = pillars.hour ?? "?";
  return `년주 ${y}, 월주 ${m}, 일주 ${d}, 시주 ${h}`;
}

function jsonResp(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function cors(res: Response): Response {
  res.headers.set("Access-Control-Allow-Origin", "*");
  res.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.headers.set("Access-Control-Allow-Headers", "authorization, content-type");
  return res;
}
