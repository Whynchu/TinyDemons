# Encrypted Cloud Save Deployment

Tiny Demons cloud saves are account-free. The Web client encrypts the complete
three-slot envelope with AES-256-GCM and sends only ciphertext to Supabase.

## Supabase deployment

The original `game_saves` migration is not used by this design. Leave that table
in place until a separate cleanup change is approved.

1. In **Supabase → SQL Editor**, run the complete contents of
   `supabase/migrations/20260830_create_recovery_vaults.sql`.
2. Install and authenticate the Supabase CLI, then from the repository root run:

   ```powershell
   supabase link --project-ref pzmrtzypkkxpoimwbgcs
   supabase functions deploy recovery-vault --no-verify-jwt
   ```

   Alternatively, create a `recovery-vault` Edge Function in the Supabase
   dashboard and use `supabase/functions/recovery-vault/index.ts` as its source.
   Disable JWT verification for this function: possession of the derived vault ID
   and write proof is the account-free authorization contract.
3. Do not add a service-role secret manually. Hosted Supabase Edge Functions
   receive `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` through their managed
   environment.
4. Never place the service-role key in Godot, GitHub Pages, Actions variables, or
   the repository. The committed `sb_publishable_...` key is intentionally public
   and can only invoke public APIs.

## Release verification

Use a disposable save and recovery key:

1. Open the published Web build and select **CLOUD SAVE**.
2. Create a local profile, choose **CREATE**, and copy the displayed recovery key.
3. In Supabase Table Editor, confirm `private.recovery_vaults` is not exposed. Use
   SQL Editor with an administrator session if ciphertext inspection is necessary.
4. Make more progress and choose **SYNC**; confirm the revision increases.
5. In a clean browser profile, enter the key and press **RESTORE** twice to confirm.
6. Confirm all expected slots appear and load.
7. Alter one character of the key; restore must fail without revealing whether a
   nearby vault exists.
8. Alter stored ciphertext in a disposable vault; AES-GCM authentication must reject
   it.
9. Press **DELETE** twice and confirm the key can no longer restore the vault.

The recovery key is not recoverable by support. A player who loses both the local
installation and the copied key loses access to the cloud backup.
