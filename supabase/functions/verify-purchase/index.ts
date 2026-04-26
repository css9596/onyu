// verify-purchase
//
// POST /functions/v1/verify-purchase
// Body: { store: 'appstore' | 'playstore' | 'mock', product_id: string, receipt: string }
// Auth: Bearer <user JWT>
//
// Validates an in-app purchase receipt server-side, persists a row in
// `subscriptions`, and syncs `profiles.subscription_tier='premium'` via
// service_role (the column is locked from authenticated by the RLS hardening
// migration).
//
// Currently supports:
//   - store = 'mock'                       → always succeeds, expires in 30 days
//   - store = 'appstore' or 'playstore'    → returns 501 not_implemented (TODO)
//
// Set MOCK_PURCHASES=true in env to also accept appstore/playstore inputs as mock.

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const PRODUCT_PREMIUM_MONTHLY = "onyu_premium_monthly";
const PREMIUM_DURATION_MS = 30 * 24 * 60 * 60 * 1000;

interface VerifyRequest {
  store: "appstore" | "playstore" | "mock";
  product_id: string;
  receipt: string;
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
  let body: VerifyRequest;
  try {
    body = await req.json();
  } catch {
    return cors(jsonResp({ data: null, error: "invalid_json" }, 400));
  }
  if (!body || typeof body !== "object") {
    return cors(jsonResp({ data: null, error: "body_must_be_object" }, 400));
  }
  if (!["appstore", "playstore", "mock"].includes(body.store)) {
    return cors(jsonResp({ data: null, error: "store_invalid" }, 400));
  }
  if (typeof body.product_id !== "string" || !body.product_id) {
    return cors(jsonResp({ data: null, error: "product_id_required" }, 400));
  }
  if (typeof body.receipt !== "string") {
    return cors(jsonResp({ data: null, error: "receipt_required" }, 400));
  }

  // ---- Validate receipt ----
  const mockOverride = Deno.env.get("MOCK_PURCHASES") === "true";
  const useMock = body.store === "mock" || mockOverride;

  let validated: ValidatedReceipt;
  if (useMock) {
    validated = {
      store: body.store === "mock" ? "mock" : body.store,
      productId: body.product_id || PRODUCT_PREMIUM_MONTHLY,
      originalTransactionId: `mock-${userId}`,
      latestTransactionId: `mock-${userId}-${Date.now()}`,
      status: "active",
      expiresAt: new Date(Date.now() + PREMIUM_DURATION_MS).toISOString(),
      rawPayload: { mock: true, receipt_preview: body.receipt.slice(0, 32) },
    };
  } else if (body.store === "appstore") {
    // TODO: Validate via App Store Server API v2.
    //   - Get signed JWT (issuerId, keyId, p8 from secrets)
    //   - GET https://api.storekit.itunes.apple.com/inApps/v1/transactions/{txId}
    //   - Parse JWS payload
    return cors(jsonResp(
      { data: null, error: "appstore_validation_not_implemented" },
      501,
    ));
  } else {
    // TODO: Validate via Google Play Developer API.
    //   - Service account JSON from secrets
    //   - GET androidpublisher.purchases.subscriptionsv2
    return cors(jsonResp(
      { data: null, error: "playstore_validation_not_implemented" },
      501,
    ));
  }

  // ---- Persist subscription (UPSERT on (store, original_transaction_id)) ----
  const upsertRes = await adminClient
    .from("subscriptions")
    .upsert(
      {
        user_id: userId,
        store: validated.store,
        product_id: validated.productId,
        original_transaction_id: validated.originalTransactionId,
        latest_transaction_id: validated.latestTransactionId,
        status: validated.status,
        expires_at: validated.expiresAt,
        raw_payload: validated.rawPayload,
      },
      { onConflict: "store,original_transaction_id" },
    )
    .select()
    .single();
  if (upsertRes.error) {
    return cors(jsonResp(
      { data: null, error: `subscription_upsert_failed: ${upsertRes.error.message}` },
      500,
    ));
  }

  // ---- Sync profile tier ----
  const newTier = validated.status === "active" ? "premium" : "free";
  const tierRes = await adminClient
    .from("profiles")
    .update({ subscription_tier: newTier })
    .eq("id", userId);
  if (tierRes.error) {
    return cors(jsonResp(
      { data: null, error: `tier_sync_failed: ${tierRes.error.message}` },
      500,
    ));
  }

  return cors(jsonResp({
    data: {
      subscription: upsertRes.data,
      subscription_tier: newTier,
    },
    error: null,
  }, 200));
});

interface ValidatedReceipt {
  store: "appstore" | "playstore" | "mock";
  productId: string;
  originalTransactionId: string;
  latestTransactionId: string;
  status: "active" | "expired" | "in_grace_period" | "revoked";
  expiresAt: string;
  rawPayload: Record<string, unknown>;
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
