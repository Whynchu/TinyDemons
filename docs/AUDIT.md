# Tiny Demons — Current Codebase Audit and Refactor Plan

Status: engineering closeout complete; release compliance pending

Audit date: 2026-08-22

Branch: `refactor/2026-08-18`

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

- `PlayerChromaComponent` is the sole runtime owner of aspect, quantized Chroma,
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

### Next active route — Elemental Chroma product work

The refactor audit is complete. New feature work resumes against the Elemental
Chroma documents, with [`elemental-chroma-handoff.md`](elemental-chroma-handoff.md)
as the decision log and [`elemental-chroma-implementation-plan.md`](elemental-chroma-implementation-plan.md)
as the execution plan.

The next bounded slice is design completion for the Triangle ability contract:
approve the Gray action, the Fire/Water/Electric actions, their animation-facing
interfaces, and the small flame-bound stat effects before adding more ability code.
Binding, blending, Primordial swapping, and broader elemental room expansion remain
later slices.

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
