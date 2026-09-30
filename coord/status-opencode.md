# opencode — status

_Only opencode writes this file._

**Focus:** Element spell forms (guaranteed spell proc) + release-gate integrity
**Updated:** 2026-09-29

## In flight

**Element spell forms** (claim on `BOARD.md`):

- Added `docs/game-design-document.md` and `docs/elemental-spell-forms-plan.md`,
  and registered both in `docs/DOCUMENTATION_MAP.md`.
- Implemented P1 of the spell-forms plan: **spells guarantee their payload
  status**. Threaded a guaranteed flag through `magic_hit_slime` →
  `damage_slime_with_number` → `try_apply_status` →
  `StatusApplicationRequest.guaranteed_proc`; `StatusApplication.apply` skips the
  roll when guaranteed. The Triangle orb passes guaranteed; the sword beam
  (`is_beam`) and melee keep the chance-based roll.
  Files: `scripts/magic_runtime_controller.gd`,
  `scripts/combat_runtime_controller.gd`, `scripts/status_application.gd`,
  `scripts/status_application_request.gd`, `scripts/gameplay_state.gd` (one-line
  signature; `GameplayState` line count unchanged).
- Offline `script_check` passes for four of the five files. `gameplay_state.gd`
  reports only the known stale-class-cache parse error
  (`argument 1 should be "GameplayState" but is gdscript://<temp>`) on untouched
  lines (391, 438, 439, 453, …), not from this change.
- Implemented P2: added `scripts/spell_form_definition.gd` (typed `Delivery`
  enum + form schema) and `scripts/spell_form_catalog.gd` (interim code registry,
  `selected_form_for` picks bound-else-current). `magic_runtime_controller.gd`
  now routes the cast through a new `deliver_spell` seam; all eight forms are
  still `PROJECTILE`, so behavior is unchanged. `script_check` clean on all three.
- Next: P3 Electric Skyfall (`INSTANT_TARGET`). Open decisions are in the plan §10.

**Release-gate integrity** (claim on `BOARD.md`):

- DONE (uncommitted) in `tests/run_all_smoke.ps1`: optional SFX-lab pytest no
  longer hard-fails the gate when its venv is absent (opt-in `-RequireSfxLab`);
  hardcoded `C:\Development\...` paths removed; missing test scripts set the
  failure flag; `tools/validate_godot_uids.ps1` added to the preflight.
- Verified by PS parser (PARSE_OK) and pure-PowerShell preflights (UID,
  manifest, composition).

## Blockers

- The composition floor fails **independent of this work**: `RoomController`
  measures 2,294 lines against the recorded baseline 2,251, and
  `scripts/room_controller.gd` is unmodified in the working tree — the growth is
  in HEAD from the room-prefab work. P2 changed no counted metric
  (`GameplayState` 1,718/286; definitions 23/23). Flagged for codex.
- Spell-proc runtime/playtest acceptance is blocked by the recorded no-Godot
  restriction (`coord/status-codex.md`); source only so far.
- Cannot execute the curated gate while the codex Godot editor holds the MCP
  peer (AGENTS.md MCP-first rule).

## Handoff / next

1. When a Godot runtime may be launched: playtest the guaranteed magic status
   proc (Fire/Ice/Electric/Shadow always apply on an orb hit; sword beam and
   melee unchanged), then proceed to P2/P3 of the spell-forms plan.
2. Release the editor peer, then run standalone:
   `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`
3. Promote the 6 unverified gate rows to `verified` with evidence only after a
   green run (update `tests/manifest.csv`, NOT `docs/KNOWN_ISSUES.md`).
