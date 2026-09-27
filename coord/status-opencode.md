# opencode — status

_Only opencode writes this file._

**Focus:** Release-gate integrity — fixes applied, awaiting supervised run
**Updated:** 2026-09-27

## In flight

DONE (uncommitted) in `tests/run_all_smoke.ps1`:
- Optional SFX-lab pytest no longer hard-fails/aborts the gate when its venv is
  absent (it is). It now probes Windows/POSIX venv layouts, skips by default, and
  fails only under the new opt-in `-RequireSfxLab`.
- Removed hardcoded absolute `C:\Development\...` paths (project-relative,
  cross-platform).
- Missing test scripts now set the failure flag instead of silently passing.
- Added `tools/validate_godot_uids.ps1` to the gate preflight (was only in
  `dev.ps1 verify`).
- Verified by PS parser (PARSE_OK) and by running the pure-PowerShell preflights:
  UID OK (353 sidecars), manifest OK (145/143/44), composition self-test + floor OK.

## Blockers

Cannot execute the curated gate to triage the remaining 6 `unverified` + 1
`environment` gate rows while the codex Godot editor holds the MCP peer
(AGENTS.md MCP-first rule). The 9 historical 2026-09-27 failures are already
`state=verified` in `tests/manifest.csv`; only `settings_service_smoke` is
`environment` ("restricted run could not write user://").

## Handoff / next

1. Release the editor peer, then run standalone:
   `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`
2. Promote the 6 unverified gate rows to `verified` with evidence only after a
   green run (update `tests/manifest.csv`, NOT `docs/KNOWN_ISSUES.md` — codex
   claim).
3. Decide CI coverage (see journal). `docs/KNOWN_ISSUES.md:500-508` still
   records the stale "nine failed" result even though the manifest now shows
   them verified — codex should reconcile that when it releases its claim.
