import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://whynchu.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const encoder = new TextEncoder();
const requestWindows = new Map<string, { count: number; reset: number }>();

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

async function sha256(value: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function validId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{32,128}$/.test(value);
}

function validProof(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{40,128}$/.test(value);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return response(405, { error: "method_not_allowed" });

  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const now = Date.now();
  const window = requestWindows.get(ip);
  if (!window || window.reset <= now) requestWindows.set(ip, { count: 1, reset: now + 60_000 });
  else if (++window.count > 30) return response(429, { error: "rate_limited" });

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > 1_100_000) return response(413, { error: "request_too_large" });

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return response(400, { error: "invalid_request" });
  }
  const action = body.action;
  const vaultId = body.vault_id;
  if (!validId(vaultId)) return response(400, { error: "invalid_request" });

  const url = Deno.env.get("SUPABASE_URL");
  const managedSecrets = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  const serviceKey = managedSecrets.default ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return response(503, { error: "service_unavailable" });
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

  if (action === "read") {
    const { data, error } = await db.rpc("td_vault_read", { requested_vault_id: vaultId });
    if (error || !data) return response(404, { error: "vault_not_found" });
    return response(200, data);
  }

  const writeProof = body.write_proof;
  if (!validProof(writeProof)) return response(400, { error: "invalid_request" });
  const verifier = await sha256(writeProof);

  if (action === "create") {
    const ciphertext = body.ciphertext;
    if (typeof ciphertext !== "string" || ciphertext.length < 24 || ciphertext.length > 1_048_576)
      return response(400, { error: "invalid_request" });
    const { data, error } = await db.rpc("td_vault_create", {
      requested_vault_id: vaultId, requested_write_verifier: verifier,
      requested_ciphertext: ciphertext,
    });
    if (error || !data) return response(409, { error: "vault_exists" });
    return response(201, { revision: 1 });
  }

  if (action === "update") {
    const ciphertext = body.ciphertext;
    const expectedRevision = Number(body.expected_revision);
    if (typeof ciphertext !== "string" || ciphertext.length < 24 || ciphertext.length > 1_048_576 ||
        !Number.isSafeInteger(expectedRevision)) return response(400, { error: "invalid_request" });
    const { data: nextRevision, error } = await db.rpc("td_vault_update", {
      requested_vault_id: vaultId, requested_write_verifier: verifier,
      requested_revision: expectedRevision, requested_ciphertext: ciphertext,
    });
    if (error || !nextRevision) return response(409, { error: "revision_conflict" });
    return response(200, { revision: nextRevision });
  }

  if (action === "delete") {
    const { data } = await db.rpc("td_vault_delete", {
      requested_vault_id: vaultId, requested_write_verifier: verifier,
    });
    return data ? response(200, { deleted: true }) : response(404, { error: "vault_not_found" });
  }

  return response(400, { error: "invalid_request" });
});
