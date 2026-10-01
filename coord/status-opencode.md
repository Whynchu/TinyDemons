# opencode — status

_Only opencode writes this file._

**Focus:** Repository review (composition/efficiency/practicality) + `0.3.26` release
**Updated:** 2026-10-01

## In flight

**Repository review — published as `0.3.26`.**

- `docs/repo-review-2026-10-01.md` written and registered in
  `docs/DOCUMENTATION_MAP.md`. It consolidates three advisor passes
  (architecture/code, modularity/buildability, player-facing) against `0.3.25`.
- Scorecard: composition 6.0, code efficiency 5.5, practicality/navigability 6.0,
  documentation 8.0, verification maturity 4.5, overall **6.0 / 10**.
- Headline findings: only the enemy pipeline is fully data-driven; spells have
  no authored `.tres`; three `dungeon_generation_policy` fields and the R7 route
  builder are dead; 2,198 `root` sites plus ~342 state-bag delegations;
  `scripts/` is 229 flat files with non-recursive scanners; FOCUS/combo apply to
  melee only; non-combat gameplay is a color/orb gate; 76/152 tests unverified.
- Release version bumped to `0.3.26` in `scripts/screen_state_controller.gd`
  (`GAME_VERSION`), `README.md`, and `docs/VERSIONING.md`.

**Elemental spell forms** — handed to codex on 2026-09-30; codex completed P4-P7
and shipped `0.3.25` (`0dfe755`, `2d4cf1e`, `d8e3fa3`). No longer opencode's.

**Release-gate integrity** (claim on `BOARD.md`): the optional sfx-lab skip,
project-relative paths, missing-test failure flag, and UID preflight are verified
by pure-PowerShell preflights. Curated gate execution still awaits a free editor
peer.

## Blockers

- Cannot run the curated gate or any Godot runtime while the codex Godot editor
  holds the MCP peer and the no-Godot restriction stands.

## Handoff / next

1. Structural follow-ups in the review §9: make repo scanners recursive, then
   move `scripts/` into feature folders; adopt the one "piece" standard; fix or
   delete dead authored fields; extend FOCUS/combo to magic; extract menu routes.
2. Release the editor peer, then run standalone
   `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1` and promote gate
   rows only after a green run.
