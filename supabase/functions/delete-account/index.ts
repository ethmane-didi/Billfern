// Billfern: permanently delete the caller's account.
//
// Trusted server-side function. The service-role key is provided by the
// Supabase Edge runtime (SUPABASE_SERVICE_ROLE_KEY) and never leaves the
// server; the app only sends the user's own access token.
//
// Requirements
// * A valid user JWT in the Authorization header (the caller can only delete
//   themselves; no user id is accepted from the request body).
// * An explicit confirmation phrase in the JSON body.
//
// Deleting the auth user cascades (ON DELETE CASCADE) to profiles,
// subscriptions, revisions, payment records and sync operations. Afterwards
// the foreign key to auth.users prevents any stale device from recreating
// records for the deleted account.
//
// Backups: Supabase database backups are retained according to the
// project's plan and are not rewritten by this function. See README.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CONFIRMATION = "DELETE MY ACCOUNT";

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  if (!token) {
    return json(401, { error: "not_authenticated" });
  }

  let body: { confirm?: unknown } | null = null;
  try {
    body = await request.json();
  } catch {
    body = null;
  }
  if (body?.confirm !== CONFIRMATION) {
    return json(400, { error: "confirmation_required" });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return json(500, { error: "server_not_configured" });
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Validates the JWT and resolves the caller. Never trust a client-sent id.
  const { data, error } = await admin.auth.getUser(token);
  const user = data?.user;
  if (error || !user) {
    return json(401, { error: "invalid_session" });
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    // Do not echo internal details or user data.
    console.error("delete-account failed", deleteError.status ?? "unknown");
    return json(500, { error: "deletion_failed" });
  }

  return json(200, { deleted: true });
});
