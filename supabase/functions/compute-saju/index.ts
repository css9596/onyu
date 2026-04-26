// compute-saju
//
// POST /functions/v1/compute-saju
// Body: ComputeSajuRequest (see below)
// Auth: Bearer <user JWT>
//
// Calculates the user's Four Pillars from birth info and persists to
// public.saju_profiles. Idempotent: returns 409 if a profile already exists
// for this user (saju_profiles is immutable per design — see docs/data_model.md).
//
// Response: { data: SajuProfileRow | null, error: string | null }

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { DateTime } from "luxon";
import { getFourPillars } from "@gracefullight/saju";
import { createLuxonAdapter } from "@gracefullight/saju/adapters/luxon";

// Default longitude for solar time correction when no birth_location given.
const SEOUL_LONGITUDE_DEG = 126.9778;

interface ComputeSajuRequest {
  birth_date: string;             // 'YYYY-MM-DD'
  birth_time?: string | null;     // 'HH:MM' (24h) — null means hour unknown
  birth_calendar: "solar" | "lunar";
  birth_is_leap_month?: boolean;
  birth_location?: string | null;
  longitude_deg?: number | null;  // optional override of SEOUL_LONGITUDE_DEG
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
  if (!supabaseUrl || !anonKey) {
    return cors(jsonResp({ data: null, error: "server_misconfigured" }, 500));
  }
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userRes, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return cors(jsonResp({ data: null, error: "unauthenticated" }, 401));
  }
  const userId = userRes.user.id;

  // ---- Parse + validate body ----
  let body: ComputeSajuRequest;
  try {
    body = await req.json();
  } catch {
    return cors(jsonResp({ data: null, error: "invalid_json" }, 400));
  }
  const validationError = validate(body);
  if (validationError) {
    return cors(jsonResp({ data: null, error: validationError }, 400));
  }

  // ---- Compute pillars ----
  let pillars: unknown;
  try {
    const adapter = await createLuxonAdapter();
    const [hh, mm] = body.birth_time
      ? body.birth_time.split(":").map((x) => parseInt(x, 10))
      : [12, 0]; // hour unknown → noon as a neutral fallback (DB still stores null)
    const [y, mo, d] = body.birth_date.split("-").map((x) => parseInt(x, 10));
    const solar = DateTime.fromObject(
      { year: y, month: mo, day: d, hour: hh, minute: mm },
      { zone: "Asia/Seoul" },
    );
    if (!solar.isValid) {
      return cors(jsonResp({ data: null, error: `invalid_date: ${solar.invalidReason}` }, 400));
    }
    pillars = getFourPillars(solar, {
      adapter,
      longitudeDeg: body.longitude_deg ?? SEOUL_LONGITUDE_DEG,
    });
  } catch (e) {
    return cors(jsonResp(
      { data: null, error: `pillars_calc_failed: ${(e as Error).message}` },
      500,
    ));
  }

  // ---- Persist (RLS: insert_own policy ensures auth.uid() = user_id) ----
  const { data: saved, error: insertErr } = await userClient
    .from("saju_profiles")
    .insert({
      user_id: userId,
      birth_date: body.birth_date,
      birth_time: body.birth_time ?? null,
      birth_calendar: body.birth_calendar,
      birth_is_leap_month: body.birth_is_leap_month ?? false,
      birth_location: body.birth_location ?? null,
      pillars,
    })
    .select()
    .single();

  if (insertErr) {
    // 23505 = unique_violation → already has a profile (immutable).
    const status = insertErr.code === "23505" ? 409 : 500;
    return cors(jsonResp({ data: null, error: insertErr.message }, status));
  }

  return cors(jsonResp({ data: saved, error: null }, 200));
});

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

function validate(body: ComputeSajuRequest): string | null {
  if (!body || typeof body !== "object") return "body_must_be_object";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(body.birth_date ?? "")) {
    return "birth_date_invalid_format (expected YYYY-MM-DD)";
  }
  if (body.birth_time != null && !/^\d{2}:\d{2}$/.test(body.birth_time)) {
    return "birth_time_invalid_format (expected HH:MM)";
  }
  if (!["solar", "lunar"].includes(body.birth_calendar)) {
    return "birth_calendar_invalid (expected 'solar' or 'lunar')";
  }
  if (body.birth_calendar === "lunar") {
    // Lunar input requires an extra solar-conversion step that is not yet
    // covered by tests. Reject explicitly so we don't silently store wrong
    // pillars. TODO: enable after lunar→solar conversion is verified.
    return "lunar_input_not_yet_supported";
  }
  return null;
}
