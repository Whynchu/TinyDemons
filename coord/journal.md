# Journal

Append-only. Newest at the bottom. One entry per `claim` / `handoff` / `blocker`
/ `done`. Do not edit prior entries.

## 2026-09-27T00:00Z — opencode — note
Initialized the coordination board. Protocol in `coord/README.md`. Agents:
read both status files and `BOARD.md` at task start; claim before editing.

## 2026-09-27T15:00Z — codex — claim
Claimed the enemy design-preview death-effect acceptance slice. Recording the
latest user playtest status and leaving the interactive workbench for follow-up.

## 2026-09-27T15:20Z — codex — blocker
Implemented the deterministic death-effect preview and passed the focused
headless enemy preview. Editor MCP repeatedly disconnected, leaving visual
playback and lifecycle acceptance open; the single editor remains on the enemy
preview scene for reconnection and manual verification.

## 2026-09-27T16:00Z — opencode — claim
Release-gate integrity. Touching tests/run_all_smoke.ps1 and (pending decision)
.github/workflows/web-pages.yml. Not touching docs/KNOWN_ISSUES.md or
docs/authoring-system-plan.md (codex claim).

## 2026-09-27T16:05Z — opencode — note
Repo-wide read-only audit delivered: architecture seams, verification surface,
content/player state, plus Thorn/Hexley/Pip advisories. Manifest re-check shows
the nine 2026-09-27 gate failures are now all state=verified; the live gate
defects are the optional sfx-lab venv hard-fail and hardcoded paths.

## 2026-09-27T16:30Z — opencode — done
Fixed `tests/run_all_smoke.ps1`: optional sfx-lab venv skip (opt-in
`-RequireSfxLab`), project-relative paths, missing-test failure flag, UID
preflight. Verified via PS parser + pure-PowerShell preflights (all green).
Curated gate execution still pending (editor peer held by codex).

## 2026-09-27T17:10Z — opencode — handoff
Wrote `docs/healer-slime-cast-plan.md` (Healer Slime cast: 2s interruptible
channel, frame-1 single-ally heal, green charge aura + rising "+" particles,
below-caster cast bar, behind-allies/keep-gap AI). Handing to codex for
implementation. Codex owns `scripts/enemy_preview_workbench.gd`,
`docs/authoring-system-plan.md`, `docs/KNOWN_ISSUES.md`; Phase 6 preview work
and the stale gate paragraph are codex's. No board row claimed by opencode.

## 2026-09-27T17:40Z — opencode — note
Wrote `docs/timed-floor-hazard-plan.md` (randomized room-edge spike tiles,
door-adjacent excluded; ~5s raise/retract; one hit per actor per cycle for player
and enemies; AI avoids via a steering danger term but knockback can still push
enemies on; no i-frames exist so a per-cycle fired-set is required). Verified the
asset blocker: the two spike PNGs (16x16, 128x16) live in the `.gdignore`d
`Artwork/` folder with no `.import`, and nothing is in `assets/artwork/` yet.
No board row claimed by opencode.
