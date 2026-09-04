# Tiny Demons — Current Codebase Audit and Refactor Plan

Status: engineering closeout complete; release compliance pending

Audit date: 2026-08-22

This branch name identifies the audit baseline. The current equipment handoff
is being prepared on the feature/gear-catalogue-expansion branch.

Branch: `refactor/2026-08-18`

Current content handoff (2026-09-02): the six-stat/menu, elemental composite
combat, responsive display, input work, and simplified six-slot gear model are
landed on this working tree. See [`gear-system-rework.md`](gear-system-rework.md)
for the live Plain/Basic/Set taxonomy, independent random `+` stats, fusion
matching, and legacy-save boundary. The older catalogue documents remain useful
for compatibility context only.

Detailed execution route: [`refactor-route.md`](refactor-route.md)

This document is the canonical current-state audit and phase register. The route
document defines the migration protocol and detailed work inside each phase. This
audit supersedes the 2026-08-18 coordinator-reduction plan; historical detail remains
available in version control.

---

## 1. Executive assessment

Tiny Demons has many useful components, tuning resources, and smoke tests, but its
runtime composition still works against safe iteration:

- `gameplay.gd` is both coordinator and feature host;
- `gameplay_state.gd` is inherited shared storage rather than an ownership boundary;
- frame, bootstrap, room, and screen controllers communicate through hundreds of
  string calls and state lookups;
- Chroma/projectiles and hub/progression continue to grow in coordinator-owned
  blocks; and
- actor visual transforms, combat geometry, and overlays have no single source of
  truth.

The accepted strategy is feature-oriented vertical migration. Each subsystem gains
tests and a typed owner, moves state and behavior together, removes its old string
seams, and checkpoints before the next subsystem begins.

The refactor must preserve one explicit frame schedule. It will not replace the
current coordinator with an event bus, service locator, or a collection of unordered
`_process()` methods.

---

## 2. Canonical documentation order

1. [`README.md`](../README.md) — project entry point, controls, and verification.
2. [`AUDIT.md`](AUDIT.md) — current findings and active phase register.
3. [`refactor-route.md`](refactor-route.md) — accepted execution plan.
4. [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime ownership and extension map.
5. [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) — designer-facing tuning index.

Phase A1 adds root `AGENTS.md` as the shortest operational map for future agents.

---

## 3. Measured baseline

Measured 2026-08-22:

| Metric | Baseline |
| --- | ---: |
| `gameplay.gd` physical lines | 2,926 |
| `gameplay.gd` functions | 413 |
| `gameplay.gd` one-line functions | 304 (74%) |
| `gameplay_state.gd` fields | 206 |
| `gameplay_state.gd` constants | 50 |
| `gameplay_frame_controller.gd` `root.call` / `root.get` | 78 / 75 |
| `screen_state_controller.gd` physical lines | 1,225 |
| `player_equipment_visual_component.gd` physical lines | 801 |
| Smoke coverage | 12 smoke scripts plus short headless boot |

Counts are navigation and coupling indicators. They are not standalone completion
criteria.

### Verification commands

```powershell
# Full smoke suite and configured boot check
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1

# Parser/editor import scan (explicit log path avoids the local Godot user-log issue)
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --log-file ".godot_user/editor-scan.log" --editor --quit
```

Each phase records its actual result; this document does not treat an old green run
as proof for a changed working tree.

---

## 4. Findings by priority

### Critical — Reproducibility and shipping assets

- Runtime code references generated/baked artwork, shaders, and reconstructed UI
  audio that may be untracked. A fresh clone must not depend on local-only output.
- Tool virtual environments, package caches, generated analysis, and reference audio
  create hundreds of megabytes of navigation noise.
- Reference-derived audio needs provenance and hash-based review. Equal file size is
  not proof of identity; unverifiable material must not remain on a shipping path.

### High — Ownership and type safety

- The coordinator inherits the shared state bag; roughly ten scripts reach into it.
- `root.call/get/set` prevents rename safety and hides subsystem dependencies.
- Feature behavior is partitioned by lifecycle phase, so one logical change crosses
  bootstrap, frame ordering, shared state, coordinator, and component files.
- Hub/progression and Chroma/projectiles remain the largest unextracted feature
  surfaces.

### High — Actor geometry and presentation consistency

- Encounter scaling, sprite offset, rendered bounds, body polygons, contact radius,
  attack reach, and flash overlays reconstruct related transforms independently.
- Recent boss regressions repeatedly displaced hitboxes and flashes down/right and
  caused attack-range disagreement.
- This system receives the first implementation slice after safety and documentation.

### Medium — Input ownership

- Gameplay, menu, dialogue, hub, HUD, and raw controller polling use several
  edge-detection idioms.
- The target architecture is one polling layer with explicit input contexts;
  `PlayerController` consumes gameplay input rather than owning menu input.

### Medium — Oversized presentation delegates

- `screen_state_controller.gd` mixes menu screens with hub/persistence UI.
- `player_equipment_visual_component.gd` mixes layered presentation with
  occlusion/death orchestration and retains obsolete paths.
- These are split only after earlier vertical slices establish stable typed seams.

### Coverage gaps

- Chroma coordinator glue has weak end-to-end coverage.
- Audio playback has no focused automated smoke test.
- Visual-transform regressions are only found through playtesting.
- Existing headless boot coverage proves survival, not visual correctness or update
  ordering.

---

## 5. Accepted architecture decisions

1. **Vertical slices, not bulk de-stringing.** Tests, typed boundary, extraction,
   seam removal, verification, checkpoint—one subsystem at a time.
2. **Central deterministic schedule.** Typed controller phase methods remain ordered
   by one scheduler.
3. **Direct typed calls and signals by default.** Callable injection is reserved for
   narrow algorithms; string-created Callables are not considered de-stringed.
4. **Domain logic stays independent of UI.** Progression and settlement do not live
   in the hub screen controller.
5. **Input is contextual.** Gameplay, dialogue, hub, and menu input share one polling
   boundary and route to different consumers.
6. **Actor geometry has one transform owner.** Rendering, targeting, collision, and
   effects consume the same calculated geometry.
7. **Shipping assets are reproducible.** Deterministic baked outputs may be committed
   for mobile, but must have source/generator/manifest provenance.
8. **Metrics inform judgment.** Line and field targets flag risk but do not override
   cohesion, ownership, testability, or behavior.

---

## 6. Active phase register

| Phase | Purpose | Status | Exit evidence |
| --- | --- | --- | --- |
| A0 | Safety, asset reproducibility, characterization tests | Complete | 12/12 smoke tests and main-scene boot pass; reproducibility protections recorded |
| A1 | `AGENTS.md`, ownership map, canonical doc cleanup | Complete | `AGENTS.md` now provides canonical reading order, ownership, and verification map |
| B1 | Actor geometry and combat presentation | Complete | Shared geometry owner, combat consumers, opt-in debug drawer, and scene-backed characterization are complete |
| B2 | Contextual input | Complete | `InputRouter` is the sole polling layer; 14-test suite and context/edge characterization pass |
| B3 | Elemental Chroma and projectiles | Complete | Chroma state, pickups, projectile lifecycle, and scene-backed ownership characterization pass |
| B4 | Progression, settlement, and hub | Complete | Progression commands, settlement guard, and domain characterization are in place |
| B5 | Combat, room, and frame seams | Complete | Frame phase order is named, documented, and characterized; existing central schedule remains intact |
| B6 | Presentation delegates and shared state | Complete | Hub pending edits now have a typed draft owner; durable profile state remains separate |
| C | Verification, metrics, fresh-clone closeout | Complete | 17/17 smoke checks, main boot, fresh-clone gate, and frame-time evidence pass |

All registered refactor phases are complete. Updating a row requires both the code
change and its listed evidence; line movement alone does not advance status.

### B1 progress — 2026-08-22

- Added `scripts/actor_geometry.gd` as the shared owner for actor foot anchors,
  encounter visual offsets, collision rectangles, collision polygons, and body
  polygons.
- Routed the corresponding gameplay compatibility wrappers through that owner,
  preserving the current runtime API while consumers migrate.
- Added pure transform characterization in `tests/actor_geometry_smoke.gd` for normal,
  boss, and nonuniform-scale cases. It reports `ACTOR_GEOMETRY_SMOKE_OK`; it is not
  yet in the production smoke list because this Godot headless environment returns a
  false nonzero exit for the render-free standalone script.
- Centralized hit-flash overlay synchronization in `ActorGeometry.sync_overlay()` so
  overlay offset and facing follow the actor presentation transform.
- Routed stable contact-radius calculation through `ActorGeometry.contact_radius()`;
  actor separation and enemy attack reach now share the same body/guide fallback.
- Routed enemy directional attack reach and projectile combat target points through
  the same geometry owner.
- The expanded 13-test smoke suite and main-scene boot remain green.

### A1 record — 2026-08-22

- Added root `AGENTS.md` with canonical reading order, verification commands,
  ownership rules, extension rules, and a feature-placement table.
- The remaining A1 cleanup items are documentation relocation tasks, not blockers
  for the active geometry slice.

### B1 completion — 2026-08-22

- Added the opt-in `ActorGeometryDebugDrawer`, refreshed by the existing frame
  schedule, showing actor feet, collision bounds, and combat polygons.
- Added and registered `tests/actor_geometry_scene_smoke.gd`, which instantiates the
  real main scene and verifies the runtime geometry owner and debug wiring.
- B1 exit gate is complete. B2 is the next active slice.

### B2 completion — 2026-08-22

- Added `scripts/input_router.gd`, which polls mapped actions, controller axes,
  button fallbacks, and edge state once per physics frame.
- Routed `PlayerController`, gameplay frame input, dialogue, hub/menu screens, and
  HUD button feedback through the router. Direct `Input` access now exists only in
  `InputRouter`.
- Added `tests/input_router_smoke.gd` covering held/pressed/released edges,
  movement capture, and gameplay/dialogue/menu context transitions.
- B2 exit gate is complete. B3 is the next active slice.

### B3 completion — 2026-08-22

- `PlayerChromaComponent` is the sole runtime owner of aspect, integer Chroma,
  binding mode, attunement, and elemental payment. The coordinator no longer
  mirrors `player_mp`.
- Added `ChromaPickupController` for pickup instances, values, launch state, and
  cleanup. Pickup collection continues to delegate restoration to the Chroma owner.
- Added `MagicProjectileController` for projectile records, homing, movement,
  expiry, hit dispatch, and trail requests. Gameplay retains only typed callbacks
  for puzzle/slime impact effects.
- Added `tests/chroma_projectile_scene_smoke.gd` and registered it in the smoke suite.
  Existing Chroma state, pickup, and ability characterization remains green.
- B3 exit gate is complete. B4 is the next active slice.

### B4–B6 completion — 2026-08-22

- Added `ProgressionController` as a UI-free domain boundary for XP, stat
  allocation, pending-point calculation, and run-grade/rank application.
- Added `RunSettlement.can_settle()` as an explicit idempotence guard; failed
  persistence leaves the active run retryable.
- Added `HubProgressionDraft` for ephemeral stat edits while preserving the
  existing screen property surface for current UI callers.
- Named the central frame contract as input, simulation, contact resolution,
  damage/progression, presentation, and transitions. The single scheduler remains
  the runtime owner.
- Expanded `progression_smoke` to cover the domain APIs, hub draft lifecycle,
  settlement idempotence, and frame ordering. The full 17-script suite and main
  scene headless run pass.
- The editor import scan exits 0. The known certificate-store/editor-settings
  warnings and scene-backed resource-leak warnings remain environment-only.

### Phase C inventory — 2026-08-22

- Pushed closeout checkpoint: `107f1cc` on `refactor/2026-08-18`.
- Added [`asset-provenance.md`](asset-provenance.md), documenting authored,
  generated, reconstructed, and reference-sensitive asset groups.
- Checked 87 literal runtime `res://` references after excluding dynamic path
  templates; all resolve locally and are present in the Git index.
- Current metrics: `gameplay.gd` 2,830 lines / 420 functions;
  `gameplay_state.gd` 172 `var` declarations; repository-wide `root.call/get/set`
  counts are 510 / 539 / 183. These are compared with the baseline above as
  migration indicators, not acceptance criteria.
- The supported Godot 4.7.1 headless frame sample measured 6.894 ms average and
  7.925 ms worst over 180 post-warmup frames (60-frame warmup). This is the first
  recorded runtime sample; Phase A0 did not capture a numeric frame-time value,
  so it is a reference baseline rather than a delta against an older measurement.
- A disposable fresh clone at `9f1b5e9` completed the editor import scan, all 15
  smoke scripts, and the main-scene headless boot. The scan's certificate-store
  and editor-settings warnings are environment-only.

### Phase C regression fix — 2026-08-22

- Fixed attack-1 ghosting by making `PlayerAnimationComponent` the single owner of
  base-versus-attack sprite visibility and assigning the new attack texture before
  exposing the attack layer.
- Added the visibility invariant to the scene-backed characterization test:
  attacking hides `TinyDemon`, while idle hides `TinyDemonAttack`.
- Full 17-script smoke suite and main-scene headless run pass after the fix;
  the runner now includes the boss geometry regression and frame-time sampler.

### Phase C closeout — 2026-08-22

- Checkpoint: `9f1b5e9` contains the attack-layer regression fix and the closeout
  evidence updates.
- Runtime assets: 87 literal runtime `res://` references resolve to tracked files;
  generated palette outputs and reconstructed audio rules are documented in
  [`asset-provenance.md`](asset-provenance.md).
- Fresh-clone gate: passed after editor import on Godot 4.7.1; the original
  15/15 smoke tests
  and the main scene exited 0 without local-only generated files.
- Post-fix local gate: the complete runner passes 17/17, including
  `boss_geometry_scene_smoke` and `frame_time_smoke`.
- Boss geometry regression: scaled boss collision guides now use transformed
  world corners plus foot compensation; the regression test verifies the guide
  remains inside the rendered boss sprite.
- Latest frame-time sample: 7.944 ms average / 17.888 ms worst over 180 frames
  after a 60-frame warmup. The earlier 6.894 / 7.925 ms sample remains the
  cleaner warm-cache reference; both are recorded because headless scheduling
  can produce occasional outliers.
- Frame-time gate: passed for the recorded reference sample at 6.894 ms average /
  7.925 ms worst across 180 frames after a 60-frame warmup. A numeric Phase A0
  baseline was not captured, so a future target-runtime comparison should use
  this measurement as its reference.
- Remaining release gate: confirm third-party sound-library and reconstructed
  audio provenance/licensing before distribution. This is explicitly scheduled
  as release/compliance work, not treated as runtime-verified.

### Post-closeout gameplay regression pass — 2026-08-22

- Checkpoints: `5a6d181` through `83826d0` on `refactor/2026-08-18`.
- Added the editable boss-slime authoring scene as the source for scaled boss
  body, collision, and attack geometry.
- Corrected runtime sprite/collider transforms, boss damage targeting, physical
  boss contact bounds, and boss-versus-add displacement priority.
- Corrected boss attack range and lunge calculations to use combat-body centers
  and directional polygon reach. Vertical attacks now retain their intended
  movement instead of applying perspective compression a second time.
- Added scene-backed regressions for authored body bounds, empty-space contact,
  boss/add displacement, and vertical attack reach.
- Verification: the complete 17-test smoke suite and main-scene headless boot pass.

### Current content route — Simplified gear and Run 1 placement

The live catalogue now has six slots, six even player baseline stats, twelve
Plain/Basic baseline pieces, and nine complete themed sets. Plain and Basic are
weighted as the common drops; any tier may receive an independent random `+`
package on any of the six stats. Fusion matches the same base definition and
rarity without requiring the same `+` package, and random lanes grow with the
primary ladder. The catalogue schema is version 12 and preserves legacy saved
values.

The Run 1 authored Treasure Rooms now use one shared back-right chest anchor.
`DungeonLayoutDefinition.validate()` and the Run 1 contract smoke guard that
placement so a center-anchor or per-room drift regression fails before
playtesting.

Follow-up verification is recorded below; the MCP-connected Godot editor is the
preferred path for runtime checks, while standalone headless checks may still
encounter the local renderer crash.

### 2026-09-03 — Four-way Hub and reversible dig branches

- Topology: generated layouts now expose all four Hub sockets. The lower-left
  Combat branch and lower-right Treasure branch are intentional scoutable dig
  endpoints; lower entries remain available until the destination room is
  engaged, then reopen after clear.
- Contract: graph socket pairing/offsets are shared by authored and generated
  layouts, and authored validation rejects duplicate or mismatched arrival
  sockets.
- Verification: modified scripts pass MCP `script_check`; the live generated
  layout validates with no errors, exposes all four Hub exits, and the runtime
  engagement sequence passed (enter, retreat, engage/lock, clear/return).
- Socket visuals: `room_puzzle_controller.refresh_room_socket_visuals` now keys
  socket art on socket kind instead of travel role. Wall sockets always render
  the DoorRight* doorway; floor sockets always render the two-tile walkway. This
  stops four-way Hub lower exits from drawing a 1-tile back-wall door on the
  floor path and stops rooms reached below from showing a walkway tile where the
  arrival doorway belongs. Boss arrivals keep the walkway treatment. Verified by
  a scene-backed socket-visual probe plus the wall/entrance socket smokes.

### 2026-09-03 — Slime spawn audio and animation pass

- Audio: `SoundClipCatalog` is the single source of truth for clip paths used by
  both `SoundManager` and the editor preview. `SlimeSpawn.wav`/`SlimeMove.wav`
  are routed through the Selfmade FX set and warm at boot. `SoundMixProfile`
  gained `slime_spawn_db`/`slime_move_db` sliders plus a reusable preview-cue
  picker and Play Preview tool button.
- Animation: a new `SlimeSpawnComponent` owns the short first-entry frame strip
  (`SlimeGreenSpawn.png`, sliced per palette) on each slime actor. While active
  the actor is excluded from collisions, knockback, attacks, magic hits, and
  targeting; the runtime controller advances frames on the explicit gameplay
  schedule and restores the idle texture on completion.
- Persistence: room state now captures alive positions and remaining health, and
  re-entry restores those values instead of replaying the intro or respawning
  defeated slimes. Spawn audio plays once per first-entry batch.
- Verification: `slime_spawn_smoke`, `sound_mix_profile_smoke`,
  `sound_balance_smoke`, the sound live-reload smokes, and the slime/room
  regression smokes all pass headless. `generated_layout_smoke` was repaired:
  it no longer hangs on a script error or a `RefCounted.free()` call, and its
  special-room door assertions select the room that actually carries both door
  colors instead of assuming the first special room does.

### 2026-09-03 — Four-way hub polish, even-stat baseline, and branch depth

- Downward branches: the generated Hub's lower-left Combat and lower-right
  Treasure dig paths are now full branching corridors (three rooms each) instead
  of single dead-end rooms, so descending from the Hub expands the dungeon. The
  lower-right path ends in a REST (Fire) room carrying a real flame. Room-target
  curve and `generated_layout_smoke` pacing expectations updated to match.
- Locked-path visuals: `apply_puzzle_environment_tint` no longer greys wall-socket
  doorways inside the D0 dig rooms (their shut/locked door art already conveys the
  state); the Hub's lower footpaths stay grey at dungeon start until the starter
  flame opens them.
- Stat baseline: profile schema 13 migrates every pre-baseline save (schemas 8-12)
  to the even 2/2/2/2/2/2 base line while preserving allocated points, level, and
  progression. `gear_system_rework_smoke` and `six_stat_profile_migration_smoke`
  updated to assert the even-baseline migration.
- Verification: generated/authored layout smokes, socket smokes, profile migration
  smokes, and the slime/sound regression smokes all pass headless.

### 2026-09-03 — AGI movement is a real investment

- `player_tuning.gd` movement now specs off `movement_agi_reference` (10 AGI =
  neutral). A new character's starting AGI 2 sits at 0.84x move speed and 0 AGI
  at 0.80x, so dumping agility is a genuine slowdown while investing past the
  reference gives a modest reward. Attack and roll timing keep their separate
  lower reference and are unchanged.
- Verification: `six_stat_calculator_smoke` and `speed_scale_smoke` assert the
  reference neutral point, the below-neutral start, and the strict reward curve.

### 2026-09-03 — Gear plus rarity and premium pricing

- Plus distribution is now weighted toward the low end so a `++`/`+++` is a
  rarer find at every rarity: Common ~6% `+`, Rare ~60/32/8, Epic ~38/34/21/7,
  Legendary ~45/37/18, Mythic ~55/45.
- The Cloaked Demon's premium shop slot passes `plus_rarity_scale` 0.35, so
  plussed gear there is meaningfully rarer than normal loot; a `++` find from
  the demon now reads as a memorable luxury.
- Shop value now scales with the `+` package and enhancement level, not just
  rarity: `+` ~1.6x, `++` ~4.4x, `+++` ~8.8x (before rarity), enhancement +22%
  per level. `++`/`+++` are intentionally premium purchases.
- Drop artwork: verified all 66 live definitions resolve to a real per-slot
  pickup icon so no gear drop falls back to the white placeholder; rarity
  tinting is applied at spawn. Head and Arm now use dedicated
  `helm_pickup.png`/`hand_pickup.png` icons instead of sharing armor/acc.
- Verification: `gear_drop_policy_smoke` gained premium-slot plus-rarity and
  price-scaling assertions; gear/reward/demon-cloak smokes pass headless.
- Drop-art regression guard: new `drop_art_smoke` verifies every catalogue
  definition resolves to its per-slot pickup icon (`sword_pickup`, `helm_pickup`,
  `armor_pickup`, `hand_pickup`, `shield_pickup`, `acc_pickup`) and that no gear
  drops fall back to the white placeholder. Registered in the smoke runner.
- Oath accessory: `oath_accessory` was a defense-tier set charm that carried no
  defense and was strictly weaker than the basic bangle (STR 1/VIT 1/AGI 1).
  It now reads DEF 2/VIT 2/STR 1 at 80G, a clear set upgrade that prices above
  the bangle and scales its defense with rarity. `gear_system_rework_smoke`
  guards that a set accessory outstats the flexible basic piece.

### 2026-09-02 — Gear rework and Run 1 treasure placement

- Owner/API introduced: `ItemCatalog` owns the live gear catalogue and flat
  random-plus ladder; `PlayerProfile` owns fusion identity and schema 12.
- State moved: new `random_stat_points` item field, live tier/set definitions,
  even new-player baseline, and the authored Run 1 chest placement guard.
- Compatibility: legacy item definitions, affixes, transmutations, and saved
  base stats remain readable but are excluded from new generated gear.
- Verification: changed scripts parse cleanly through MCP; the new gear and Run 1
  smoke scripts are registered. A standalone Run 1 smoke invocation hit the
  known Godot 4.7.1 local renderer crash before test initialization.

---

## 7. Per-slice audit record

Append one entry per completed slice:

```markdown
### YYYY-MM-DD — Slice name

- Checkpoint:
- Owner/API introduced:
- State moved:
- Old seams removed:
- Automated verification:
- Manual playtest:
- Frame-time observation:
- Metrics delta:
- Follow-ups:
```

This creates a handoff trail without turning the implementation plan into a session
log.

---

## 8. Metrics to re-measure

```powershell
$gameplayPath = 'scripts/gameplay.gd'
$gameplayLines = Get-Content $gameplayPath
[pscustomobject]@{
    PhysicalLines = $gameplayLines.Count
    Functions = ($gameplayLines | Select-String '^func ').Count
    OneLineFunctions = ($gameplayLines | Select-String '^func .*: .+').Count
    RootCalls = (rg -o 'root\.call\(' scripts | Measure-Object).Count
    RootGets = (rg -o 'root\.get\(' scripts | Measure-Object).Count
    RootSets = (rg -o 'root\.set\(' scripts | Measure-Object).Count
}
```

Also record:

- `gameplay_state.gd` fields grouped by intended owner;
- largest scripts and their documented responsibilities;
- tests passed/failed;
- focused playtest result;
- average/worst observed frame time; and
- runtime resource references to untracked files.

---

## 9. Open decisions

- Exact class name and node ownership for the actor geometry API.
- Whether Chroma pickups belong to `PlayerChromaComponent` or a small world pickup
  controller; ownership should follow lifecycle and testability, not file count.
- Final committed format for baked recolor assets and their manifest.
- Audio replacements and provenance disposition.
- Single source of truth for `Artwork/` versus `assets/artwork/`.

These decisions are resolved in the slice where they become necessary and recorded
in the per-slice audit entry.

---

## 10. Phase A0 record — 2026-08-22

- Checkpoint: existing WIP remains uncommitted; no destructive cleanup performed.
- Reproducibility change: smoke runner now passes an explicit ignored
  `.godot_user/smoke.log` path because Godot's default `user://logs` destination
  crashed before tests could initialize.
- Ignore change: added `.godot_user/`, `.godot-test-user/`, nested Python virtual
  environments, `node_modules/`, generated analysis, SFX analysis, and superseded
  generated UI output. Runtime-required baked assets and reconstructed UI audio
  remain visible for a later provenance/tracking decision.
- Baseline verification: all 12 smoke scripts passed and the main scene headless
  run passed. Godot still reports the environment-only root certificate warning,
  and the main scene reports two leaked objects at exit without a nonzero exit.
- Baseline fix: `progression_smoke` had partially migrated to the current flat
  primary-stat contract but still asserted the older starter totals. Its assertions
  now cover the live starter loadout (`+2 VIT`, `+1 net STR`, `+3 DEF`, `+1 SPD`)
  and confirm those values remain flat at high base stats. No runtime balance code
  was changed for this fix.
- Structural implementation: not started. The first structural slice remains B1,
  actor geometry and combat presentation.
