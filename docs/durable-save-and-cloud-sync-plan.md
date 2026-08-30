# Tiny Demons — Durable Save and Cloud Sync Plan

Status: approved direction; implementation in progress

> Decision update — 2026-08-30: account-based authentication is no longer the
> primary recovery design. Tiny Demons will use an account-free recovery key and
> client-side encrypted cloud vault. The previously created `game_saves` table is
> retained but unused until an explicit cleanup migration is approved.

## 1. Objective

Keep Tiny Demons playable without an account while making save loss progressively
harder:

```text
local atomic save
  + browser persistence request
  + manual export/import
  + optional Supabase cloud sync
```

The cloud exit condition is specific: after deleting the Home Screen app or
clearing its browser data, a player can open the game at the canonical URL, sign
in again, and restore all three profile slots.

No browser-only mechanism can guarantee recovery after explicit deletion. Local
storage remains the fast, offline source used during play; cloud storage is a
durable replica and recovery source.

## 2. Product decisions

- Offline play and local saves remain available without registration.
- Cloud Save is opt-in and is presented as protection against device loss,
  browser-data clearing, and Home Screen app deletion.
- No email, OAuth provider, password, or Supabase Auth account is required.
- The client generates a high-entropy recovery key. It derives separate encryption,
  vault-lookup, and write-authorization material; the raw recovery key is never sent
  to Supabase.
- Profile JSON is encrypted in the browser before upload. Supabase stores only an
  opaque encrypted envelope and cannot interpret ordinary save contents.
- A rate-limited Supabase Edge Function mediates vault reads and writes. The table
  is not exposed directly to the public PostgREST roles.
- Cloud synchronization happens at durable profile boundaries, not every frame:
  explicit save, settlement, return to title/hub, and app backgrounding.
- The local save succeeds independently of the network. Cloud failure never blocks
  gameplay or settlement.
- One player owns up to three cloud slots. Row-level security prevents clients from
  reading or writing another player's rows.
- The canonical web origin remains `https://whynchu.github.io/TinyDemons/`.

## 3. Current defects and prerequisites

### Schema acceptance mismatch

`PlayerProfile.load_dictionary()` accepts schemas 8 through 11, but
`ProfileSaveService._parse_profile_json()` currently accepts only the current
schema and the immediately previous schema. This can make a valid older save look
absent before migration is attempted.

Make `PlayerProfile` the sole authority for supported schemas. Prefer a typed parse
result that distinguishes:

- missing save;
- valid current save;
- valid migrated save;
- corrupt JSON;
- unsupported future/obsolete schema.

Never silently replace a corrupt or unsupported save with a fresh profile before
offering recovery/export diagnostics.

### Existing browser protection

The existing `localStorage` mirror protects against an incomplete Godot IndexedDB
flush. It is not a separate backup because both stores are controlled by the same
browser/origin lifecycle.

### PWA identity

Keep a stable manifest ID, start URL, scope, and GitHub Pages origin across
releases. Players should update by reopening the installed app; release
instructions must not tell them to uninstall first.

## 4. Target ownership

| Owner | Responsibility |
| --- | --- |
| `PlayerProfile` | Validate and migrate profile dictionaries. |
| `ProfileSaveService` | Atomic local slot reads/writes, backup, import/export primitives. |
| `CloudSaveService` (new Node) | Edge Function transport, vault upload/download, and retry state. |
| `SaveSyncCoordinator` (new typed owner) | Decide when to sync and resolve local/remote state without enlarging `gameplay.gd`. |
| `SaveFlowController` | Present cloud status, sign-in, restore, import/export, and conflicts. |

`gameplay.gd` only wires these owners and forwards lifecycle events. Cloud services
must not mutate `PlayerProfile` directly; they return typed results to the sync
coordinator.

## 5. Supabase encrypted-vault design

### Recovery identity

MVP flow:

1. Player chooses **Protect Saves**.
2. The browser generates 256 bits of cryptographically secure random recovery
   material.
3. The game displays a grouped recovery key and QR code and requires the player to
   confirm that it was copied.
4. Separate encryption key, vault ID, and write verifier are derived with HKDF-SHA-256
   using fixed, versioned context labels.
5. Existing local slots are packed into one versioned envelope, encrypted with
   AES-256-GCM using a fresh 96-bit nonce, and uploaded.
6. On a fresh install, the player enters/scans the recovery key; the client derives
   the identifiers, downloads the ciphertext, authenticates/decrypts it, validates
   the save envelope, and offers the slots for restoration.

Use the browser Web Crypto API through a narrow `JavaScriptBridge` adapter. Do not
invent cryptographic primitives in GDScript. The versioned envelope must permit a
future algorithm or derivation migration without reinterpreting existing vaults.

Use the public/publishable Supabase key only to invoke the Edge Function. Store the
service-role key in Supabase's managed function environment only. Never ship it,
the database password, or any recovery key in the Godot export, logs, analytics, or
repository.

### Table

Target migration (supersedes the unused account-owned `game_saves` table):

```sql
create table private.recovery_vaults (
  vault_id text primary key,
  write_verifier text not null,
  revision bigint not null default 1 check (revision > 0),
  cipher_version smallint not null,
  ciphertext text not null,
  updated_at timestamptz not null default now(),
  expires_at timestamptz
);
```

Before launch, set conservative ciphertext and request-size limits at both the Edge
Function and database boundary. The client also rejects oversized downloads/imports
before decryption or parsing.

### Grants and RLS

Place the vault table in a non-exposed `private` schema. Revoke access from `anon`
and `authenticated`; only the Edge Function's server-side service role may touch it.
The function exposes narrowly validated create/read/update operations. It never
returns the stored write verifier. A correct high-entropy vault ID is required to
read; a write proof is additionally required to update. Apply per-IP and per-vault
rate limits and uniform not-found responses.

### Client integration

Use Godot `HTTPRequest` against the Supabase Edge Function for transport. Keep
request creation, cancellation, timeouts, retry policy, and JSON parsing inside
`CloudSaveService`; keep Web Crypto calls in a separate `WebSaveCrypto` adapter.

Configuration consists only of a project URL and publishable key. Supply them to
the Web export through a generated, ignored configuration resource or CI-injected
HTML/runtime configuration. CI and pull-request artifacts must not expose any
privileged credential.

## 6. Save envelope and compatibility

Local exports and cloud rows carry an envelope around the existing profile JSON:

```json
{
  "format": "tiny-demons-save",
  "format_version": 1,
  "game_version": "0.1.20",
  "slot": 0,
  "profile_schema": 11,
  "revision": 12,
  "saved_at": "2026-08-30T00:00:00Z",
  "content_hash": "sha256:...",
  "profile": {}
}
```

The hash detects accidental corruption; it is not an authenticity/security claim.
Import validates the envelope, size, JSON types, schema support, and profile
invariants before touching the active save. Import writes through the existing
temporary-file/backup path and keeps the previous valid profile recoverable.

Unknown future schemas are never downgraded or overwritten automatically.

## 7. Synchronization and conflict rules

Each slot tracks the last successfully synchronized `revision` and
`content_hash` locally.

- Local changed, remote unchanged: upload a new revision.
- Remote changed, local unchanged: offer/download the remote copy.
- Hashes match: mark synchronized without rewriting.
- Both changed since the common revision: show a conflict screen.
- Missing local, present remote: offer **Restore Cloud Save**.
- Present local, missing remote: offer **Back Up This Save**.
- Network/server-authorization failure: retain a pending-sync marker and retry at the next durable
  boundary with bounded exponential backoff.

Conflict UI shows slot, character name, level, playtime if available, game/schema
version, and save date. It provides **Keep This Device**, **Use Cloud**, and
**Cancel**. Neither choice destroys the discarded side immediately: retain the
local backup and, when practical, one previous cloud revision or a short-lived
conflict archive.

Do not compare device clocks to select a winner. Server timestamps are useful for
display, while revision and known-base hash establish causality.

## 8. UX

Add a **SAVE DATA** panel reachable from title settings and the pause/hub menu:

- Local: `Saved` / `Problem`.
- Browser protection: `Persistent` / `Best effort`.
- Cloud: `Not connected`, `Syncing`, `Protected`, `Offline`, `Needs attention`.
- Actions: **Protect Saves**, **Sync Now**, **Restore**, **Export**, **Import**,
  and **Disconnect**.

After a successful local save, gameplay never waits on a cloud spinner. Show a
small non-blocking status change. Recovery-key setup, import overwrite, cloud restore,
conflict resolution, and cloud-backup deletion require explicit full-screen confirmation.

On web startup, request `navigator.storage.persist()` after a deliberate user
gesture and record whether it was granted. Describe it as extra local protection,
not a backup.

## 9. Ordered implementation

### Phase 1 — Repair and characterize local migration

- Centralize the supported-schema decision in `PlayerProfile`.
- Add fixtures for schemas 8, 9, 10, 11, corrupt JSON, and a future schema.
- Verify every slot and backup fallback.
- Surface invalid-save status instead of presenting an empty slot silently.

Exit: every schema the profile knows how to migrate is discoverable through
`ProfileSaveService`, and unsupported data is preserved for diagnosis.

### Phase 2 — Export/import and persistent-storage request

- Implement save-envelope creation and validation.
- Add Web download and file-picker import through `JavaScriptBridge`; retain a
  platform-neutral byte/string API underneath for future desktop dialogs.
- Request and display browser persistence status.
- Add overwrite confirmation and rollback coverage.

Exit: a save exported before app deletion can be imported into a clean browser and
round-trips without loss.

### Phase 3 — Supabase vault and security baseline

- Create separate development and production Supabase projects.
- Commit SQL migrations and Edge Function code, not dashboard-only undocumented
  state.
- Create the private recovery-vault table without deleting the already-applied
  `game_saves` table.
- Deploy the create/read/update Edge Function with strict schemas, body-size limits,
  constant-shape errors, write-proof verification, and rate limiting.
- Establish free-tier database export/backups during development and choose a paid
  backup policy before making a production durability promise.

Exit: direct public table access is impossible; incorrect random vault IDs and write
proofs cannot read or modify a vault; the function never receives plaintext saves
or raw recovery keys.

### Phase 4 — Cryptography and cloud transport

- Implement secure recovery-key generation, encoding/checksum, HKDF derivation,
  AES-GCM encrypt/decrypt, and typed crypto errors.
- Implement vault create/download/update with request timeouts.
- Never log recovery material, derived keys, ciphertext, or plaintext saves.
- Add fake-transport tests for success, timeout, rejected write proof, invalid JSON, and
  retry behavior.

Exit: a recovery key can upload and download all three slots, a wrong key fails
without data disclosure, tampered ciphertext fails authentication, and offline/local
play remains unchanged.

### Phase 5 — Sync coordinator and conflict UI

- Add revision/hash metadata and sync only at durable save boundaries.
- Add first-link upload/restore choice; never overwrite implicitly.
- Add all conflict states and retain rollback copies.
- Coalesce rapid saves so settlement produces one eventual cloud write.

Exit: two browsers can intentionally diverge a slot, receive a conflict, choose
either side, and converge without silent loss.

### Phase 6 — Recovery, rollout, and operations

- Test uninstall/reinstall recovery on Safari iOS and Chrome Android using the
  actual GitHub Pages release.
- Add **Delete Cloud Backup** with recovery-key/write-proof confirmation.
- Add coarse operational counters (success/error class and latency), without save
  contents or player identity in analytics.
- Roll out behind a remote/config flag: internal testers, opt-in beta, then public.
- Document Supabase project ownership, billing alerts, database exports, key
  rotation, incident response, and service shutdown/export procedure.

Exit: a player can delete local app data, enter the recovery key, inspect cloud slot
metadata, restore, and continue. A Supabase outage leaves local play and saving
functional.

## 10. Verification matrix

### Automated

- Supported-schema discovery and migration for every historical fixture.
- Export/import round-trip for all three slots.
- Corrupt, oversized, truncated, unknown-schema, and wrong-hash imports rejected.
- Local save success when cloud is offline, slow, unauthorized, or rate-limited.
- Upload/download equality after migration to the current schema.
- Sync state transitions and simultaneous-edit conflict coverage.
- SQL tests proving no public table access; Edge Function tests for invalid vault IDs,
  write proofs, replay/conflict revisions, oversized bodies, and throttling.
- No service-role secret in repository history, generated Web artifact, or logs.

### Manual release checks

- Safari iOS: install, save, sync, remove Home Screen app/data, reopen URL, sign in,
  restore.
- Chrome Android: same flow.
- Existing pre-cloud local save: update in place, create recovery key, upload, reload.
- Offline launch/save, reconnect, and eventual sync.
- Lost/wrong recovery key, checksum typo, and QR/manual-entry retry.
- Conflict between phone and desktop browser.
- Export file restored with no Supabase connection.

Do not run the full standalone Godot smoke runner while an MCP editor/runtime peer
is active. Start with focused save and cloud tests, then use the supervised full
gate described in `AGENTS.md`.

## 11. Risks and controls

| Risk | Control |
| --- | --- |
| Old valid save appears empty | Central schema authority; invalid-save UI; migration fixtures. |
| First cloud sync overwrites progress | Explicit upload/restore choice and conflict metadata. |
| Supabase key exposure | Publishable key only; service role stays server-side. |
| Vault enumeration or unauthorized writes | 256-bit derived identifiers, private table, write proof, uniform errors, and rate limits. |
| Recovery key lost | Mandatory copy confirmation plus manual encrypted export; clearly state that support cannot reset it. |
| Offline/network outage blocks play | Local-first writes and queued bounded retry. |
| Free project pause or lacks backups | Development-only free tier; scheduled exports or production paid backup policy. |
| Recovery-code guessing | Server-only verification, high entropy, hashing, rotation, and rate limits. |
| Future client destroys newer save | Reject unknown future schemas and never auto-overwrite. |

## 12. Definition of done

- Updating the game at the same URL preserves and migrates supported local saves.
- Export/import provides a backend-independent recovery path.
- Browser persistent mode is requested and accurately reported.
- Cloud Save is optional, client-side encrypted, and does not affect offline play.
- Fresh-install recovery-key entry restores all cloud-backed slots with explicit
  player choice.
- Conflicting device edits cannot silently overwrite one another.
- Secrets, privacy, deletion, backups, monitoring, and outage behavior are documented
  before the feature is described publicly as durable cloud storage.
