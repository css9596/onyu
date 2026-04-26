// delete-account
//
// POST /functions/v1/delete-account
// Auth: Bearer <user JWT>
//
// Deletes the calling user's auth.users row, which CASCADEs through
// profiles → conversations → messages, saju_profiles, and subscriptions.
// (See `supabase/migrations/20260426113402_initial_schema.sql`.)
//
// This endpoint exists primarily because Google Play Store (since 2023)
// and Korea's PIPA both require an in-app account deletion path.
//
// Response: { data: { deleted: true } | null, error: string | null }

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
  if (req.method !== "POST") {
    return cors(jsonResp({ data: null, error: "method_not_allowed" }, 405));
  }

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

  // Resolve the calling user from the JWT.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userRes, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userRes?.user) {
    return cors(jsonResp({ data: null, error: "unauthenticated" }, 401));
  }
  const userId = userRes.user.id;

  // Hard-delete via the admin API (only available with service_role).
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { error: deleteErr } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteErr) {
    return cors(jsonResp(
      { data: null, error: `delete_failed: ${deleteErr.message}` },
      500,
    ));
  }

  return cors(jsonResp({ data: { deleted: true }, error: null }, 200));
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
