# Tiny Demons — Known Issues and Verification Gaps

Status: live register for the `0.3.x` cycle

Updated: 2026-10-02

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.3.18`. The current smoke inventory is 149 manifest
rows / 147 runnable paths / 44-path default gate; the counts quoted in older
sections below are historical snapshots. The authoring and verification
sequence is in [`authoring-system-plan.md`](authoring-system-plan.md).

The 0.3.0 checkpoint includes the authored start-position and teleport
correction, working controller access to the pause Debug preference, debug
level/stat-budget behavior, shared Skeleton variant geometry, boss-preview
geometry, and a Debug page styled with the pause menu's pixel frame, text, and
cursor. Bone-hit attack preservation is accepted from playtesting. The mobile
room freeze remains open for profiling.

This page is the short navigation view of current problems. The detailed
reports, reproduction notes, and acceptance criteria remain in
[`current-issues-and-resolution-plan.md`](current-issues-and-resolution-plan.md),
[`AUDIT.md`](AUDIT.md), and [`test-target-audit.md`](test-target-audit.md).

“Implemented in source” means that a code path and focused assertions exist. It
does not mean that cold-start timing, every display orientation, physical
touch input, browser behavior, or a complete player journey has been verified.

## 2026-10-02 polish pass — Fire cone aim, Orb height, transition/pickup hitches

Three player-reported issues. All three are fixed in source; runtime frame-time
evidence and player acceptance are still open.

### Fire Cinder Cone aimed at the closest enemy instead of sideways

**Cause.** The lateral-only aim rule ran in `begin_magic_animation`, but the
ordinary tap-and-release cast never reaches that line with a form in hand. A
magic press starts a *candidate* animation (`_begin_magic_candidate`) with
`pending_magic_form = null` and `pending_magic_direction` already pointing at
the closest enemy. The form is only chosen on release, in
`execute_current_aspect_ability`, which captured the selection and went straight
to the cast frame. So the cone kept the raw closest-enemy vector and the
horizontal snap was effectively dead code for the normal input.

**Fix.** The rule is now `apply_horizontal_cone_aim(context)`, called from both
entry points. It resolves to `Vector2.LEFT`/`Vector2.RIGHT` from the requested
aim's horizontal component, falling back to the player's remembered facing when
that component is inside `ActorMotor.HORIZONTAL_FACING_DEADZONE`, and it also
re-faces the cast sprite so the player and the plume agree. Every other form is
untouched and keeps its aimed vector.

**Coverage.** `tests/cone_aim_contract_smoke.gd` drives
`execute_current_aspect_ability` through both paths across eight target
geometries and both remembered facings, with a non-cone control case. It fails
on the pre-fix source and passes after. Registered in `tests/manifest.csv`.

### Orb-room Orb floated above the floor

**Cause.** `room_puzzle_controller.gd` carried a hard-coded
`ORB_ROOM_VISUAL_OFFSET := Vector2(0, -7)` applied on top of the authored
`ORB_CENTER` marker, so the runtime orb sat at y=73 while the editor preview
sprite in `scenes/orb_room.tscn` was hand-mirrored to the same value. The
authored marker (y=80) matches the RestFire anchor in the same room; the extra
`-7` lifted the 9x9 art to 68.5–77.5 against a floor surface at ~88.5, leaving
roughly 11 px of air under it. The same `-7` also made the release-gate
assertion "EntryOrb shares the authored center marker" fail, since the scene
drifted in `b454529` while the test still expected the marker value.

**Fix.** The constant is gone. The authored `ORB_CENTER` marker is the single
source for both the preview sprite and the runtime orb, and the scene was
resynced to it. The walkable-bounds fallback is unchanged for room scenes
without the marker.

### Room transitions and item pickups hitched

Both moments wrote the player profile synchronously inside one physics tick.
`ProfileSaveService.save_profile` serializes the whole profile, writes a temp
file, **re-opens and re-parses that file, and rebuilds a full `PlayerProfile`**
to verify it, then does four more filesystem operations. On a transition that
ran unconditionally plus again via the gold-settle path; on a pickup it ran on
the exact contact frame alongside the particle burst, the audio start, and the
HUD count-up. Three writes could land in one tick.

**Fixes, in order of measured cost:**

1. **Write verification no longer re-parses.** The write is checked by stored
   byte length against the payload, which still catches a truncated write
   without the deserialize.
2. **The write is queued, not performed.** `ProfileSaveService.request_save`
   records a live profile reference; `flush_deferred_save` refuses to write on
   the requesting frame and rate-limits to one write per 400 ms. The frame
   controller drains the queue at the front of the gameplay tick, before pickup,
   door, and enemy work. Room transitions and pickups now only *request*.
3. **Safe boundaries still force a write.** `RunCheckpointService.save_profile_now`
   and `RunSettlement` force the queue before persisting, and
   `_save_active_run_checkpoint` forces it before capturing a run snapshot, so
   the profile can never be older than the snapshot paired with it.
4. **Room prefabs are reused by prefab, not by room ID.** Most rooms share the
   generic shell; the reuse guard keyed on `room_id`, so every door crossing
   re-instantiated the same 11 KB scene and freed the previous one. Reuse is now
   keyed on `prefab_id`, and the rebind (sockets, floor/socket references,
   accent geometry root) still runs on every mount — only the instantiate and
   the `queue_free` are skipped.
5. **Sprite sheets are sliced once.** `SpriteFrameLibrary.slice_frames` and
   `slice_sheet_row` re-sliced their sheets on every room entry and minted new
   `ImageTexture` objects each time. That defeated every texture-keyed cache
   downstream — including the occlusion renderer's per-pixel warm — so a fresh
   image pass ran per room entry and its dead cache entries accumulated. Slices
   are now cached by path and frame size; callers still receive a fresh array.
6. **Floor tile geometry is read once.** `_collect_tile_regions` instantiated
   and freed a 228-byte four-point scene on every room entry to read one polygon.
7. **HUD count-up is bounded.** Gold and soul count-ups rasterized a new
   pixel-text texture every frame of the roll (420/second at 60 Hz is ~7 new
   keys per frame, each rebuilding a ~70-glyph table and uploading a texture).
   The step is now capped at `COUNTUP_MAX_STEPS` visible updates per payout, and
   the chroma reaction tint is cached per color.
8. **Audio prewarm covers pickups.** `item_pickup`, `mana_pickup`,
   `chest_reward`, and `ui_use_item` were absent from the boot prewarm list, so
   their first play imported and decoded on the contact frame.
9. **Catalog projections are cached.** `ItemCatalogData` rebuilt
   `authored_definition_data()` and `authored_live_ids()` on every
   `ItemCatalog.new()`, which pickups and chest opens do per call. Both are
   derived from the already-cached authored resource set and are now cached
   beside it, and invalidated with it.

**Instrumentation added.** `room_transition` (the door-touch frame),
`profile_save_queue_delay` (how long a pickup or door crossing waited for its
write to land), and `profile_save_write` are now recorded scopes.
`tests/performance_scenario_harness.gd` no longer hardcodes
`layout_ms`/`activate_ms` to `-1.0` — it times the same calls the runtime makes
— and gained an `item_pickup` scenario, which
`docs/gameplay-stability-investigation-plan.md` had asked for.

**Still open.** These are source-level fixes informed by reading the frame
paths. The first post-change desktop harness run (2026-10-02, seed `24681357`)
reports an `item_pickup` single-contact frame of **1.50 ms** and steady state
unchanged at ~6.9 ms avg / ~7.3 ms worst, but there is **no pre-fix
comparison, no rendered playtest, and no device profile.** The boss entry
remains the worst transition case and this pass does not claim to have moved
`docs/AUDIT.md` section 11.2 — the same run measured the boss entry at 52.7 ms
and the regular room transition at 41.0 ms, both single samples inside the
already-documented noise band. `tools/run_perf_harness.ps1`, an F9 capture, and
the Samsung A17 profile are the next evidence.

### Pre-existing failures found while verifying this pass

Three gate rows fail on unmodified `main` and are **not** caused by this work.
They are recorded here rather than fixed, because each is a separate concern
from the three reported issues.

| Test | Symptom | Evidence |
|---|---|---|
| `hub_binding_smoke` | `FAILED: Hub Binding owners are composed` | Fails identically with `scripts/` stashed to `HEAD` |
| `equipment_menu_scene_smoke` | `TEST_ABORTED` after `update_hub_ui` hits a null node at `screen_state_controller.gd:2468` | Fails identically with `scripts/` stashed to `HEAD` |
| `imbue_spell_scene_smoke` | `Invalid cast: could not convert value to 'Dictionary'` at line 191; the abort skips `quit()` so the process hangs instead of exiting | The test asserts `imbue_outline_overlays`, which `d6e1f8b` (0.3.19) removed from `player_equipment_visual_component.gd`; the property exists nowhere in the tree |

## Tooling verification gaps — Slice 0 resolved 2026-09-20

These issues were independently reproduced with Godot 4.7.1 headless (`-s`
script runs, no editor peer active) and resolved in Slice 0 of
[`authoring-system-plan.md`](authoring-system-plan.md):

- **Resolved: stale global class cache blocked focused content tests.** With the
  pre-existing `.godot/global_script_class_cache.cfg` (25 KB, missing newer
  classes), `tests/encounter_definition_smoke.gd` and
  `tools/report_catalogs.gd` fail at parse time with
  `Identifier "EncounterDefinition" not declared`. A `--import` pass
  regenerated the cache (35 KB, 189 classes) and both then ran
  (`ENCOUNTER_DEFINITION_SMOKE_OK`, report exit 0). A clean checkout has no
  cache at all, so the runner and focused tools must import first.
- **Resolved: `puzzle_map_r5.tres` declared `plan_id = "r4"`.** The validator
  now checks the R5 identity explicitly.
- **Resolved: definition-resource UID coverage.** The reported UID warning was
  caused by the stale class/import cache; the resource UID matches its script
  sidecar and `validate_godot_uids.ps1` now checks definition resources.
- **Resolved: tool portability.** `tools/validate_composition.ps1 -SelfTest` hardcoded
  `pwsh`, and `tools/run_headless.ps1` hardcodes both the development Godot path
  and its own `$ProjectRoot` default. They work on the primary development
  machine and fail on hosts without `pwsh` or the same directory layout.
- **Resolved: catalog reporting and definition coverage.** The report preloads
  its definition scripts, returns nonzero on load failures, and the validator
  recursively covers all 15 authored resources in `resources/definitions/`.
- **Open: one curated-gate scene timeout remains environment-sensitive.** The
  focused content suite and authoring preflight pass, but the standalone
  2026-09-20 curated gate timed out in `chroma_projectile_scene_smoke` before
  reaching its assertions. `tests/run_all_smoke.ps1` now records that timeout
  on Windows PowerShell instead of crashing while killing the worker; this is
  separate from the enemy authoring proof.

- **Implemented in source: enemy registry validation detects duplicate stable
  IDs.** `SlimeVariantCatalogData` now validates every distinct embedded or
  standalone source before runtime lookup deduplicates IDs. A conflict reports
  the stable ID and both resource paths, while valid runtime lookup order stays
  unchanged. The authoring dock exposes this check as `Validate Enemies`, beside
  the placement-only `Validate Scene` action. Offline GDScript diagnostics pass;
  the Godot definition validator and editor interaction have not been rerun
  under the current no-process-launch restriction.

- **Implemented in source: enemy and item catalogs consume kind-specific
  generated manifests.** The deterministic resource-reference manifests are
  generated by the shared dock/CLI service; the all-resource manifest feeds
  definition preflight and freshness checks. Each runtime catalog preloads only
  its own references into exported builds. Typed discovery and duplicate
  validation cover `resources/definitions/` and `resources/content/`, while the
  item catalog retains its explicit special-item references. Exported-PCK
  loading and add/move/delete refresh acceptance still need editor/export
  evidence. The dock now schedules a coalesced refresh for save, reimport, and
  filesystem-change events in addition to the manual Refresh action.

## Focused baseline verification — 2026-09-11

The smoke inventory found `114` registered test paths with `0` missing files.
Because no Godot editor peer or runtime was active, focused tests were run as
individual standalone Godot processes. The full process-per-test suite was not
run.

Passing contracts included dungeon map events, authored R3/R4/R5 layouts, the
Run 2 authored layout, room prefab construction, slime spawning, enemy-room
engagement, gear effects, gear-slot migration, Chroma state and pickup rules,
aspect abilities, starter-flame setup, and generated flame progression.

The following contracts failed in that baseline run and need triage before they
can serve as release evidence; the follow-up below records resolved items.

- `active_run_recovery_contract_smoke`: a valid snapshot failed schema/slot
  validation;
- `cloud_save_contract_smoke`: the source contract still lacks the expected
  explicit runtime-safe types in the cloud panel;
- `demon_hub_menu_scene_smoke`, `equipment_menu_scene_smoke`, and
  `touch_controls_smoke`: current menu geometry, cursor/selection state, and
  touch-target contracts disagree with the tests;
- `gear_catalogue_expansion_smoke` and `gear_drop_policy_smoke`: current
  starter/package expectations disagree with the catalogue and shop policy;
- `elemental_binding_smoke`: generated R7 validation and fusion-state
  assertions fail;
- `generated_minimap_smoke`, `run1_minimap_smoke`, and
  `run_music_flame_gate_smoke`: minimap draw order, undiscovered-room
  visibility, and starter-flame music-gate assertions fail.

The active-run snapshot fixture and the R6+ generator were corrected during the
2026-09-13 follow-up. Isolated focused checks now pass for
`active_run_recovery_contract_smoke`, `r6_plus_risk_reward_generation_smoke`,
`elemental_binding_smoke`, `generated_run_scene_smoke`, `run1_door_path_smoke`,
`wall_socket_geometry_smoke`, and the new `room_transition_result_smoke`.
Those results do not replace the unresolved contracts listed above.

The compatibility-named `r7_native_generator_smoke`, neighboring
`generated_layout_smoke`, and bound-reachability checks were also rerun in
isolated headless processes. They pass: the active R6+ route stays inside the
declared compact 35x35 map, preserves its logical-edge projection, remains
deterministic across the sampled starter-flame and seed cases, and keeps the
required bound/recovery gates reachable. No new test path was added.

### 2026-09-13 focused triage of the newly registered and previously stalled checks

The six checks that were outside the runner are now registered and were run one
at a time in isolated headless processes:

- `actor_geometry_smoke` had a harness defect (its success path called
  `quit(0)` without `return`, then fell through to `quit(1)`); fixed, and the
  test now passes.
- `cloud_panel_touch_smoke`, `demon_cloak_smoke`, `hub_content_scroll_smoke`,
  and `resource_drop_motion_smoke` pass in the isolated runner (the earlier
  stalls were environment/add-on teardown noise). `resource_drop_motion_smoke`
  reports four engine resources still in use at exit.
- `touch_menu_scroll_smoke` fails its ghost-accept and stale-hold assertions;
  this is an `input & touch` product-area finding, not a harness stall.
- At that earlier stage, `menu_route_scene_smoke` and
  `gear_system_rework_smoke` ran to completion but failed real assertions
  (game-over directional navigation; head/arm source drop counts). These were
  `hub & menus` and `gear & fusion` findings respectively.

At that point, result states were recorded in `tests/manifest.csv` (state
`open` for the three assertion failures, `verified` for the five passing
checks).

### 2026-09-13 contract decisions and resolutions

All three open findings from the triage are now resolved with documented
contract decisions:

- `menu_route_scene_smoke` was a harness defect: the test injected
  `_menu_directions` directly, but `update_game_over_input` reads
  `_menu_direction_events` (populated only inside `poll()`). The test now
  injects the field the code actually reads; product code was unchanged and the
  test passes.
- `gear_system_rework_smoke` was a stale expectation. Decision: Plain pieces
  drop from chests for every slot under the same rules; the Demon Cloak remains
  the only shop-purchased non-set item. `plain_hood` and `plain_wraps` are no
  longer `starter_only`, and the head/arm "needs introduction" check now keys on
  the Plain tier (zero-power) instead of a starter-only flag. The gear, drop,
  and catalogue tests pass.
- `touch_menu_scroll_smoke` was a stale expectation. Decision: blank non-dialogue
  menu taps stay inert; the ghost-accept/stale-hold mechanism belongs to the
  dialogue context. The test now exercises scroll delta in the hub/menu context
  and the ghost-accept hold in the dialogue context; it passes.

A separate pre-existing finding surfaced during verification:
`six_stat_equipment_smoke` fails its INT/MND flat bonus assertions (a
`gear & fusion` product-area finding tracked in `tests/manifest.csv`).

### 2026-09-13 gear stat-ladder regression fix

Investigating `six_stat_equipment_smoke` exposed a real product regression in
the gear stat ladder, not just a stale test:

- The original design (`item_catalog.gd`) adds `rarity_flat_points` (rank × 2,
  which already carries the "+1 from the rarity jump" and the "+1 earned from
  the previous track's ten levels") plus a per-track enhancement term of +0.1
  per level (`MASTERY_BONUS_PER_LEVEL`), resetting to 0 on promotion.
- A later refactor computed the enhancement term as
  `max(fusion_stat_points, enhancement_level)`. `fusion_stat_points` is the
  monotonic total that never resets on promotion, so any promoted item received
  its prior-track fusion points a second time on top of the rarity rank.
- `combat-economy-overhaul.md` documents the intended per-track model ("reaching
  the same +1.0 at +10"). `gear-economy-progression-implementation-plan.md`
  documents monotonic `fusion_stat_points` as storage/migration, not as a second
  stat-ladder term.
- Fix: the enhancement term now uses `enhancement_flat_points(enhancement_level)`
  (the per-track +0..+10 counter). Fused gear now follows the intended ladder
  (common+0 STR 3 → common+10 STR 4 → rare+0 STR 5 → rare+10 STR 6 → mythic+10
  STR 12 for the tier-stat sword) and a fused-up rare equals a fresh rare at the
  same track position.
- `six_stat_equipment_smoke` aggregate expectations were also stale (equipment
  INT is 5.0, not 4.0); corrected and the test passes.

### 2026-09-13 menu/equipment test fixes

Two further pre-existing failures were stale test expectations, not product bugs
(the product matches the documented contracts; the tests described older layouts
or raced the cursor motion):

- `six_stat_calculator_smoke` asserted the level-one starter deals 3–5 physical
  damage, which assumed the old Basic starter gear. Plain starters are
  intentionally zero-power (per the starter contract), so the benchmark is now
  the base-stat 2.0 and the test asserts the 1–3 band.
- `equipment_menu_scene_smoke` had four stale assertions: the cursor bob checks
  sampled a single frame while the cursor was still in its short glide, the
  slot-description check expected a bonus strip for zero-power plain gear, and
  the Shop check expected the legacy list cursor instead of the modern
  `ShopMenuLayout` cursor layer. All corrected; the test passes.
- `pause_menu_scene_smoke` now passes its authored frame, rail, responsive, and
  route contract; manual Pause Equipment swipe/clipping evidence remains open.

### 2026-09-13 touch/cloud contract reconciliation

- `cloud_save_contract_smoke` passes in an isolated headless run. Its existing
  source assertions now have current evidence for the cloud panel's runtime-safe
  pixel UI types, web crypto path, migration, and recovery-vault edge function.
- `touch_controls_smoke` passes after its fixture supplies the optional pause
  callbacks expected by `ScreenStateController.build_hub()`. The remaining
  expectation changes are contract alignment: the current hub stat-row target is
  69.5x12 logical pixels, a non-dialogue blank menu tap is inert, and dialogue
  retains the explicit tap-anywhere accept path. No new test file was added.

### 2026-09-13 web export gate output fix

`web_export_smoke.ps1 -RequireExport` now stages local verification in a fresh
temporary directory, avoiding stale ignored `dist` artifacts held open by an
editor. The GitHub Pages workflow passes `-OutputDirectory dist` explicitly, so
the publishable artifact contract is unchanged. The local single-threaded Web
export passes; browser/device and hosted Pages verification remain open.

A supervised full-run attempt on 2026-09-13 reached ordinary assertion
failures without a native headless renderer crash. It was stopped at the
broader R6+ seed failure, which the focused elemental-binding and R6+ checks
now cover. The full suite remains a release gate rather than a claim of zero
behavioral failures.

The earlier native R7 generator smoke report is retained as historical
evidence: it repeatedly reported rooms and connections outside the declared
compact 35x35 map, including `room_9_11` at `(35, 10)`, under the superseded
route contract. The current compatibility-named check exercises the active R6+
route and is verified in `tests/manifest.csv`. Several other standalone checks
still stalled during the add-on MCP runtime startup/teardown path without
producing a reliable assertion result; those checks remain unverified rather
than passing or failing by inference. The certificate-store and MCP registry
messages are environment warnings seen across the direct runs, not product
assertions.

Detailed command output and target interpretation are tracked in
[`test-target-audit.md`](test-target-audit.md). This snapshot is evidence for
triage, not a release gate.

### 2026-09-13 Demon Hub/Shop contract reconciliation

`demon_hub_menu_scene_smoke` now passes in an isolated Godot process. The
focused contract covers the authored Hub shell, animated nested Shop cursors,
responsive nested reflow, exact enhancement/random-roll sell variants, the
quantity sale route, and pause overlay separation. The active cursor assertion
now samples its bob range instead of requiring a single tween frame, while the
outer Hub breadcrumb remains stable when only the nested Shop view is resized.

The Shop amount route now hides the inactive `ShopBackButton` while the explicit
SELL cancel control owns that state. The existing `equipment_menu_scene_smoke`
was also rerun with a deterministic plain-starter fixture and save restoration;
it passes without relying on whatever gear a previous local run left equipped.
`pause_menu_scene_smoke` also passes after restoring the live profile it uses for
its Pause Equipment touch route.
`player_hud_scene_smoke` also passes after its two ability-prompt paths were
aligned with the authored cooldown-icon hierarchy.
`gear_catalogue_expansion_smoke` and `gear_drop_policy_smoke` pass their
six-slot catalogue, Plain starter, deterministic drop, shop coverage, premium
plus, pricing, and anti-repeat contracts. The earlier open labels were stale
audit metadata; no gear source change was needed in this slice.
`fusion_tooltip_smoke` and `fusion_menu_scene_smoke` also pass the existing
Hub/Fusion presenter, authored panel, clipped list, Soul footer, and touch
signal contracts. The remaining Fusion evidence is the live next-rank
transaction matrix, not a scene-construction failure.
No new test file was added, and the web export path was not reopened because
the existing local gate is already accepted for this pass.

## 2026-09-28 healer presentation and hub gear menus — open

### Healer cast endpoints and boss jump presentation

**Player report:** The healer's green casting arc appears to leave from the
slime's foot and land around the target's middle. It should connect the top
center of the healer sprite to the top center of the target sprite. The boss
also has a small healer-related visual defect while jumping. The cast progress
bar should move one more pixel upward.

**Source audit:** `scripts/slime_support_component.gd` starts the effect using
`magic_target_point`, whose enemy fallback is the combat-body center in
`scripts/magic_runtime_controller.gd`. `scripts/enemy_target_arc.gd` then uses
`ActorGeometry.body_polygon` and clips the line to that collision/body polygon's
edges. The boss jump changes the root `Sprite2D.offset` in
`scripts/boss_jump_slam_component.gd`; the body-hitbox child remains anchored to
the floor, so re-evaluating the current polygon does not make the endpoint
follow the raised boss sprite. The arc already updates each frame, but it is
tracking combat geometry rather than the visible sprite. The current cast-bar
offset is four pixels above the shared guard-bar offset.

**Acceptance criteria:** Resolve the source and target anchors from each actor's
visible sprite bounds, using the top-center point after the sprite's current
frame, offset, and world transform are applied. Update the anchors during the
cast so animations and the boss jump remain followed. Keep the target outline
attached to the target's visible sprite. The same rule must work for current
Slimes, the enlarged boss, Skeletons, and future enemy actor roots with a sprite
visual. Move the healer bar exactly one additional world pixel upward from its
current placement. Healing, range, and combat collision geometry must keep their
existing behavior.

### Healer cast animation loading and endpoint reticle

**Player report:** Healing stopped restoring health and the cast animations
looked wrong. A small target reticle also appeared where the arc touched the
target and should be removed.

**Source audit:** The connected editor log reported zero frames from both
`SlimeGreen_Casting.png` and `SlimeGreen_Spell_Cast.png`. The sheets were loaded
by path at runtime. If no spell frames loaded, the fallback release duration
could be shorter than the configured impact delay (`4 × 0.08s`), ending the
cast before `_resolve_heal()` ran. `EnemyTargetArc._draw_target_marker()` drew
the endpoint crosshair over the target outline.

**Acceptance criteria:** Statically include and slice both authored animation
sheets for web exports, use a visible animation fallback when either sheet is
empty, and keep the cast alive until the configured heal impact resolves even
when no spell frames are available. Remove only the endpoint reticle; preserve
the outline, connecting arc, and moving glimmers.

### Fusion menu inventory-size slowdown

**Player report:** Opening Fusion in the Demon Hub slows substantially when the
player has a large gear pool.

**Source audit:** `scripts/hub_flow_controller.gd` invalidates the cached Fusion
list whenever the Hub opens and rebuilds it on the first Fusion-list read. The
builder groups inventory, then calls `PlayerProfile.fusion_material_count` and
`can_salvage_overflow` for each grouped target. Those helpers each search the
inventory again (and the material helper reconstructs item instances while
scanning); the sort comparator also recomputes gear names and stat totals.
Consequently, the first open can do repeated full-inventory work for every
distinct candidate even though later UI reads use the cached candidate list.

**Acceptance criteria:** Build the same candidate set, equipped-first ordering,
material eligibility, and overflow-salvage state with one inventory aggregation
pass plus candidate sorting. Preserve the existing explicit invalidation on Hub
open and gear transactions, as well as the fusion transaction rules. Opening
Fusion and moving between rows should not trigger a full inventory scan per
candidate.

### Shop BUY/SELL gear-stat comparison

**Player report:** A buyer cannot tell the highlighted item's own stats because
the panel compares the player's current total stats with the totals after
hypothetically equipping it. The player requested a direct comparison with the
currently equipped piece on the left and the highlighted piece on the right,
with the existing red/green meaning preserved. SELL should receive the same
clarity if it currently uses the same panel.

**Source audit:** `scripts/screen_state_controller.gd::_shop_stat_comparison`
currently builds a live player snapshot, substitutes the highlighted item into
its slot using `EquipmentComponent`, and reports before/after character totals.
That same function supplies the Shop presenter for both BUY and SELL.
`scripts/shop_menu_layout.gd::render_shop` already has left/right stat columns
and colors the right value by its delta, so the presentation can show gear-piece
bonuses directly without changing the shop's transaction or navigation flow.
The SELL list excludes equipped pieces; its comparison currently remains the
same hypothetical character-total panel rather than an equipped-piece versus
selected-sale-item comparison.

**Acceptance criteria:** For every highlighted BUY or SELL row, show the
currently equipped item's six core gear-stat bonuses in the left column and the
highlighted item's bonuses in the right column. Apply the existing green/red
color rule to the right value when it is higher/lower than the equipped piece;
equal values remain neutral. Use the same rarity, enhancement, and random-stat
bonus calculation already used by gear, and show zero for an empty current slot.
Browsing or selling must not equip or otherwise mutate either item.

### Fusion EQUIP/ITEM comparison and header alignment

**Player report:** Fusion's `EQUIP` and `ITEM` headers sit lower than their Shop
counterparts and should use the same comparison function as Shop.

**Source audit:** `ShopMenuLayout.render_shop()` places the shared headers at
y=46. `FusionMenuLayout._apply_fusion_geometry()` moves Fusion's stat rows to
start at y=41 but leaves those headers at y=46, below the first stat row. The
Fusion model currently calls `_fusion_stat_comparison()`, which places the
selected gear's current bonuses on the left and the projected post-fusion
bonuses on the right. Shop's `_shop_stat_comparison()` instead places the
currently equipped piece on the left and the highlighted piece on the right,
including mastery bonuses. As a result, Fusion's visible `EQUIP`/`ITEM` labels
do not describe its current values.

**Acceptance criteria:** Place both headers above the first stat row in Fusion's
body panel and keep them aligned with their columns through responsive reflow.
Use the Shop comparison semantics for Fusion: currently equipped piece on the
left, selected Fusion item on the right, mastery and item bonuses included, and
the existing green/red/neutral value colors. Show zero for an empty equipment
slot. The comparison must be read-only and must not affect Fusion's transaction.

### Run-based gear reward progression

**Player report:** Late-game gear acquisition feels stale. The player wants gear
odds to improve after each run and at least a substantially higher gear volume
to make Fusion viable.

**Source audit:** `PlayerProfile.completed_runs` is persisted and advances
after a clear. Existing reward curves use difficulty rank, run grade, and chest
exploration. The player clarified that the new guaranteed progression must use
completed runs only, with no current-run depth contribution. In-run chests use
the number of previously completed runs. The run-clear award uses the count
including the run just completed. Failed attempts do not advance the profile
count.

**Acceptance criteria:** Increase gear odds and the number of gear items
available from chest and run-clear rewards, without increasing chest frequency.
Keep completed-run progression monotonic through its
declared cap, preserve deterministic seeded rolls, and guarantee two items from
a vault. Keep existing rank/grade terms as separate modifiers; do not use room
depth or elapsed run progress for completed-run progression. Record rates in
`GAMEPLAY_TUNING.md`.

**Implemented in source (2026-09-28):** Chest frequency remains at its existing
0.50 chance per regular combat room. Standard chest gear chance uses a 0.45
base, 0.40 floor, and 0.92 cap; risk
chests retain their +0.12 bonus and 0.95 cap. The clear-award base rises to
0.40. Double/triple/quad item thresholds use bases 0.50/0.025/0.01 and caps
0.85/0.22/0.12. Vaults guarantee two items. Existing completed-run increments
remain unchanged and still count completed runs only; room depth does not
contribute.

### Healing-burst particle art

**Player report:** The green healing `+` particles were too small and faint to
read reliably. The enlarged replacements looked harsh and cluttered, so the
burst needs a more deliberate pixel-art treatment.

**Source audit:** The first replacement repeated the same large 9x9 cross six
times, used fractional scaling, and let noise spread the particles unevenly.
The shared 3x5 `gearplus3x5.png` remains the pixel-text glyph and must not be
changed for this effect.

**Acceptance criteria:** Use a crisp outlined pixel cross as the primary heal
cue, with a few smaller sparkle accents to reduce repetition. Keep pixel-aligned
scaling and controlled upward motion, preserve the 3x5 text glyph, and make the
effect readable without covering actors or combat feedback.

**Implemented in source:** the arc now anchors to the visible Sprite2D's
transformed `get_rect()` top center and updates during the cast, so the boss's
animated `Sprite2D.offset` is reflected. The bar uses a five-pixel upward offset
from the shared guard-bar position. Fusion now aggregates unequipped counts by
definition and rarity during its inventory pass, caches candidate details, and
sorts using precomputed name/stat keys. Shop BUY and SELL now compare the current
equipped item's six gear bonuses against the highlighted item's bonuses, with
`EQUIP` and `ITEM` column headers and the existing green/red delta colors.
Fusion uses those same equipped-piece/item comparison semantics and positions
its headers at y=33 over the y=41 stat rows. Heal bursts now pair one crisp 9x9
outlined cross with smaller 5x5 sparkle accents, at integer scale and with
controlled upward motion; the 3x5 text glyph is unchanged. Gear rewards now
increase from completed-run count alone: chest chance and multi-drop thresholds,
clear-award chance, and rarity probability all progress monotonically to their
20-run cap. The clear award counts the run just completed; in-run chests use
previously completed runs. Vault quantity is now two items. Healer animation
sheets are now statically preloaded for web builds; empty-sheet fallback keeps
the cast visible and waits through the configured heal impact time. The arc's
endpoint crosshair is removed while the target outline and glimmers remain.

**Runtime acceptance remains open:** no Godot editor/playtest or large-inventory
timing sample was run because the current session is still under the recorded
Godot crash restriction. Offline GDScript diagnostics passed for all five
changed scripts, and `git diff --check` passed.

## Player-facing findings still needing runtime evidence

### Elemental statuses and actor-render follow-up — implemented in source, open for runtime acceptance (2026-09-28)

The first four elemental statuses and their shared actor-local state, combat
application/tick paths, movement and stun effects, HUD marks, sibling outline,
and four data-selected edge-particle styles are present in the working tree.
Burn uses an ember trail matching the motion of the player's imbue trail;
Poison uses rising motes, Stun uses electric sparks, and Slow uses frost
crystals. `status_component_smoke` and
`status_combat_smoke` are registered in the manifest but have not been run.
Catalog/definition validation, native-resolution readability, and web/browser
playtesting remain open.

The overhead status marker previously cast a stored built-in Array to
`Array[Sprite2D]`, then could retain child sprites after their actor freed them.
The cached array is now pruned before both hidden-bar handling and update, and
player markers receive the same lifetime guard. Particle cleanup also drops
freed sprites before casting. The reported `Trying to cast a freed object`
error has a source fix; runtime confirmation remains open.

The user also reported status outlines appearing offset or oversized. The
outline now lives beside the actor sprite, copies its global transform, and
crops AtlasTexture regions, Sprite2D regions, and the current animation-sheet
frame before generating the border. Status particles use those same visible
pixels.

The imbue overlay now copies the same full transform and only offsets
uncentered sprites. Focused offline MCP diagnostics pass for the changed HUD,
aura, particle, combat, reward, and item scripts. Visual alignment remains
unverified; no test suite or game runtime was launched.

The reported translucent player sprite on death is not confirmed to be caused
by Demon Cloak. `PlayerAnimationContext` carries the death-state callback used
by the animation guard, and source tracing found attack-animation completion
branches that could set player visibility back to true. Animation frame/tick
entry points now keep the player and attack layer hidden once death starts, and
death entry restores opaque white before hiding the sprite. The registered
`player_death_visibility_smoke` remains unrun, and cloak/death visual acceptance
is open.

The transient magenta rectangle over the actor and hitbox remains unresolved.
No capture was available, and no explicit magenta assignment was found in the
audited render scripts/shaders. The cause is unknown; reproduce it in a color
playtest before making a shader or overlay change.

### Doorway geometry — verified

Doorways were checked in gameplay on 2026-09-13 and are functioning as intended:
the player can traverse active openings and closed doorway behavior is correct
for the current authored rooms. This verifies socket traversal and closed-door behavior; it does not cover sustained combat contact in the opening. The 2026-09-26 combat-pinning report reopens that separate case under the gameplay stability plan. On 2026-09-13,
`wall_socket_geometry_smoke` was reconciled with the current portal-based
walkability model and passed in the isolated headless runner. The test covers
closed-socket portal exclusion, closed transition rejection, open portal
participation, and normal open-entrance movement.

Note (2026-09-17): the curated release gate at `0.2.32` still reports
`wall_socket_geometry_smoke` failing on "the authored normal-room geometry
target exists" (`room_-1_1`), reproduced identically at the pre-composition
baseline `8b162a2`. This is a pre-existing gate failure, not a composition
regression; the isolated focused pass above does not replace the gate outcome.
The gate also retains the pre-existing `run1_door_path_smoke` failure. A real
composition regression (`chroma_projectile_scene_smoke` calling the pre-A1
`equipment.tick(gameplay)` signature) was found in the same gate run and fixed.
These two remaining failures need triage before they can serve as release
evidence.

**Triage outcome (2026-09-17, at `0.2.47`):** both remaining failures were
reconciled and now pass. `wall_socket_geometry_smoke` was a transient gate flake
(a scene test dependent on main-scene frame timing) and passes via the runner.
`run1_door_path_smoke`'s failing assertion pinned an obsolete legacy bug — the
room-wide `door_active` now correctly activates after a successful clear (the
"legacy room-wide lock" is resolved), so the assertion was updated to verify the
modern contract while keeping the per-socket enterable-exit assertions.
`run1_map_contract_smoke` (owner role) had the same stale pattern — the D9
arrival exit is intentionally escapable in authored rooms, so its assertion was
reconciled to the authored-room escape contract. All run1/dungeon/map/door
smokes pass.

| Area | Current state | Evidence still required |
|---|---|---|
| Demon Hub SELECT/BACK presentation | Focused Hub/Shop contract verified; visual orientation check remains | Compare all hub routes at native and supported responsive layouts |
| Shop functional sell variants | Focused live transaction verified; performance timing remains | Measure open, row movement, sale, and post-sale refresh with representative inventory |
| Shop sell performance | Cache/rebuild pass exists; no timing baseline | Measure open, row movement, sale, and post-sale refresh with representative inventory |
| Fusion batch capacity | Next-rank cap and `xN/M` amount display exist | Confirm +0/+9/+10/Mythic +10 limits through the live Fusion transaction |
| First flame-room music start | Music warmup/cache exists | Cold versus warm room pickup frame profile and audio-start check |
| Pause equipment clipping | Candidate clip and local scroll bounds exist | Fast swipe/release checks in Pause and Hub at supported aspect presets |
| R5/R6 route identity | New runs preserve authored R5 and use generated R6+ | Fresh-run identity, fixed-seed layout, and active-run recovery checks |
| Flame-room fast travel | Basic travel works in the R7 playthrough; no travel SFX or transition animation yet | Save/load and repeated travel; add travel sound and transition presentation |
| Bound identity at zero Chroma | Domain path preserves bound identity and desaturates | Live body/equipment presentation, depletion, pickup restore, and save/load |
| Gray/Normal Chroma collection | Collection path exists | Live collection while Gray, storage amount, and unchanged Normal state |
| Needed-color Chroma pickups | Selection path exists | Visual color checks for each current need and neutral/Normal state |

The source-level status for each item is maintained in the detailed issue
tracker. Update both documents when a focused check changes the status.

### 2026-09-13 generated-room spawn verification

The focused `generated_bound_reachability_smoke`, `generated_layout_smoke`,
`generated_run_scene_smoke`, and `enemy_room_entrance_scene_smoke` checks pass
in isolated Godot processes. The route invariants, generated scene entry,
enemy-slot spawning, spawn walkability, and engagement-door behavior all pass;
the room controller's spawn solver continues to validate collision geometry
against the active walkable area. No generated-room spawn defect reproduced in
the focused headless paths. A manual late-generated-room playtest remains open
because those checks do not replace visual/gameplay verification of every late
R6+/R7 encounter.

### 2026-09-15 curated gate and verification preflight

The manifest preflight passed before the curated gate: `tests/manifest.csv`
contains 123 registered scripts, 121 runnable checks, 2 report scripts, and 43
gate checks. The runner now gives each Godot test process its own temporary
`user://` profile, preventing settings/profile state from leaking between
checks. The curated gate completed without an engine crash.

Passing infrastructure evidence included SFX lab pytest (25/25), the Web
export, main-scene boot, room transition, HUD scene, generated-room, doorway,
and other existing gate contracts. `imbue_spell_scene_smoke` also passes in
isolation after its stale six-entry cooldown assertion was aligned with the
current three-icon HUD.

The Chroma/magic presentation contract is resolved: the magic cast now uses
the authored five-frame body timeline, with the projectile firing on frame 3,
and the MP bar assertion follows the active player palette accent. The
responsive Hub and restored-controller input contracts are also resolved; their
focused checks pass after making cursor-anchor and wall-clock handoff assertions
deterministic. The remaining focused gate findings are the two settings
persistence checks listed below, which are environment findings on this
restricted host.

`settings_panel_scene_smoke` and `settings_service_smoke` remain environment
findings on this restricted host because their `user://` persistence path is
not writable. They are not treated as product failures.

### R6+ risk/reward generation implementation status

The active generated-run slice now uses an ungated critical route with one
safe/risk fork, guaranteed Fire/Water/Electric flame rooms, and one or two
optional elemental Orb vaults. Dangerous shortcut rooms receive a stronger
encounter profile and risk reward tier; vault rooms receive an elite profile and
guaranteed enhanced gear through the existing chest item generator. New route
metadata is carried through layout, graph, room state, minimap plans, and active
run room-state snapshots. The focused generator, elemental-binding, generated
scene, and enemy spawn/walkability checks pass in isolated Godot processes; the
2026-09-13 R7 playthrough accepted the minimap landmark visibility behavior.
Manual late-generated-room placement, reward, save/load, touch, and
flame-travel checks remain outstanding.

### 2026-09-13 minimap landmark visibility reconciliation

The intended minimap contract is now explicit: the Hub, boss/downstairs rooms,
Orb rooms, and Fire/Rest or flame-bearing landmarks are visible at run start;
unvisited flame landmarks are grey; ordinary rooms remain hidden until entered.
The user-confirmed R7 playthrough matched that behavior. Both
`generated_minimap_smoke` and `run1_minimap_smoke` pass the focused contract,
including landmark colors, ordinary-room discovery, and destination cursor draw
order. Their older `open` entries were stale and are now `verified` in
`tests/manifest.csv`. Flame-travel recovery/repeat evidence and browser/device
verification remain separate evidence gaps.

### 2026-09-13 flame-travel presentation note

The R7 playthrough confirmed that Hub/flame-room travel functions correctly.
There is currently no dedicated travel sound effect or transition animation;
those are polish tasks, not route defects. Save/reload and repeated-travel
verification remain open alongside browser/device verification.

### 2026-09-13 starter-flame music gate reconciliation

`run_music_flame_gate_smoke` now passes against the sound owner's documented
audio policy: `Dungeon-Crawl.wav` is the source path and
`Dungeon-Crawl.ogg` is selected automatically when present. The run track stays
silent before starter-flame attunement and starts after it. The separate cold
versus warm pickup timing/profile remains open.

The neighboring sound-balance and sound-mix-profile checks also pass. Their
canonical runtime key is `sword_beam_charge` for charging and `sword_beam` for
the launched projectile; both now have explicit catalog/profile coverage.

### 2026-09-27 gameplay stability reports - active

Playtesting reported doorway combat pinning, hitches around pickups/flame
interaction, intermittent freezes during mobile-browser boss AOE/reward
sequences, and skeletons closing inside a useful throwing distance. The latest
playtest reports that bone hits no longer interrupt player attacks as intended.
The collection path confirms synchronous profile writes; this is a plausible hitch
source, not a confirmed explanation for every report. Same-frame pickup saves
are now coalesced. Doorway contact handling and skeleton range steering have
initial source corrections; focused movement and in-game acceptance remain
open. The mobile freeze remains a potentially open issue and is untriaged
pending isolated Web profiling. Do not close it based on desktop stability.

The investigation, owners, evidence plan, and acceptance bar are recorded in
[`gameplay-stability-investigation-plan.md`](gameplay-stability-investigation-plan.md).
The same plan records bone hits preserving active player attacks and sword-beam
charge as resolved by the latest user playtest. The mobile freeze, collection
hitches, and doorway escape still need their own acceptance evidence, but the
latest player update below says hitches are much better and skeleton combat is
working well. These older reports should not drive the next work slice without
a new reproduction or other evidence.

**Player update (2026-09-27):** the latest user playtest reports that hitches
are much better and skeleton combat is fun and working well. Chroma, bound
identity, save/load, and flame travel also feel good. These areas are not the
next priority; the earlier reports remain historical context rather than a
request for immediate changes. This update is player feedback, not a measured
performance result or a broad compatibility verification.

Touch follow-up: the Equipment menu needs direct touch interaction across its
routes. The first tap on an item should highlight it without activating it;
touch should not require the controller's separate Equip confirmation, and
tapping an item while Equip is highlighted should enter that item's equipment
flow. Record and resolve this separately from the existing Pause Equipment
scroll-clipping report.

### 2026-09-26 gear-drop distribution correction

Review found an 8x Head/Arm introduction weight in the shared chest and
clear-reward slot selector. That catch-up bonus has been removed so eligible
slots roll evenly. Plain and Basic definition weights were also eased slightly
against Set pieces; the chance that a chest offers gear and the clear-reward
anti-repeat window are unchanged.

### Popup hold and pause Debug menu — implemented in source

The requested four-update popup pause and opt-in pause `DEBUG` page have a
design handoff in [`popup-and-debug-menu-plan.md`](popup-and-debug-menu-plan.md).
Runtime, touch, and responsive-layout proof remains open. `R#` means the player-facing run number
(for example, finishing R5 advances to R6), not room depth; the selector and
reset action use that run number.

### 2026-09-23 intermittent gameplay hitch observation - open

Manual playtesting observed occasional frame hitches or skips during room
transitions, enemy deaths, and some other effect-heavy moments. The cause is
not yet confirmed. Cold asset/shader work, synchronous room-transition setup,
and CPU-side pixel-image work used by death particles are plausible suspects,
but this note deliberately does not promote any of them to a diagnosis.

Next evidence: capture cold-versus-warm frame-time samples around a room
transition and enemy death, record the first-use resource/shader path, and
compare the result with the existing `performance_scenario_harness` before
moving work off the transition frame or adding more prewarming. This remains a
performance investigation, not a gameplay-contract failure.

## Verification surface audit — open

The repository has a large test/report inventory. `tests/manifest.csv` now
classifies all 149 scripts with a role (gate/owner/reference/diagnostic/report),
state, owner, target, and load kind. The runner derives its grouping from that
manifest: the default release gate selects 44 paths; `-TestGroup all` covers the
147 runnable paths. The 2026-09-13 pruning slice removed the stale
`backtrack_popcorn_smoke` expectation and consolidated the three identical
R3/R4/R5 layout wrappers into `authored_layouts_smoke`; no gate coverage or web
export coverage was removed. The separate classification and pruning issue is
[`verification-surface-audit.md`](verification-surface-audit.md). Until its
remaining exit criteria are met, the total smoke count is an inventory metric,
not a quality score or release gate.

## Floating popup timing and pause DEBUG page — implemented in source

Floating damage/reward text now uses one pop, four-update hold, then drift/fade
lifecycle. Gold uses the same shadowed number path. A focused lifecycle smoke
script covers the hold boundary; it is registered but not yet run.

Settings now include a persisted, default-off `DEBUG MENU` preference. When
enabled, the pause rail opens a separate DEBUG page with a confirmed R# reset,
temporary player-level override, invulnerability, unlimited Chroma, enemy
pause, and geometry-guide toggles. R# is the player's run number; the override
changes the generated route, runtime rank/rewards, and HUD together without
writing `completed_runs` to the profile. A debug-selected route is omitted from
ordinary active-run checkpoints. Cheat toggles and the level override clear at
the END DEBUG action. A selected route remains the active run's identity until
that run settles, then the ordinary profile-derived number resumes.

Focused checks pass for controller selection of the persisted DEBUG setting,
the pause Debug page's pixel frame/text/cursor treatment, composition, manifest,
definitions, and Web export. The 2026-09-27 Windows run of the 44-path curated
gate did not pass: nine paths failed or timed out (Demon Hub, responsive display,
generated-bound reachability, generated layout, generated run construction,
player HUD, touch controls, wall-socket geometry, and Equipment menu setup), and
the runner then stopped because the optional SFX-lab virtualenv was absent.
Subsequent focused runs now mark those nine manifest entries `verified`; six
curated paths remain `unverified` and `settings_service_smoke` remains
`environment`. The full 44-path gate has not been rerun after those focused
checks, so it is still open. Manual Debug-page exploration with
mouse/touch/controller across aspect ratios and run-reset/session cleanup checks
also remain useful follow-up.

## Infrastructure findings

| Finding | Impact | Next evidence or decision |
|---|---|---|
| Full smoke runner has 147 runnable manifest paths; the default gate selects 44 and launches one Godot process per selected path | Slow feedback and possible Windows renderer/memory failure avalanche | Use the default gate for release checks and `-TestGroup all` only as a supervised inventory; runner isolates each worker with temporary user data and Dummy audio |
| Boss-room door entry is a genuine slow path (measured 300–385 ms on loaded runs, 100–165 ms on quiet runs) | The boss transition is the worst synchronous path; the harness's single-sample reading is too noisy to gate on | Average the boss-entry measurement across several door entries, then optimize the accent placer, boss activation/spawn, and synchronous profile-save phases after the A17 device profile. Tracked in [`AUDIT.md`](AUDIT.md) section 11.2 |
| Six formerly unregistered `role:owner` checks are now triaged and resolved | All six have reliable states recorded in `tests/manifest.csv` | `actor_geometry_smoke` harness fixed; `cloud_panel_touch_smoke`, `demon_cloak_smoke`, `hub_content_scroll_smoke`, `resource_drop_motion_smoke` verified; `touch_menu_scroll_smoke` rewritten for the dialogue-context contract and verified |
| Browser/device verification remains incomplete | Local export support does not prove shipped web behavior | Verify touch, controller prompts, save/reload, audio, responsive layout, and Pages artifact |
| `screen_state_controller.gd` remains a large mixed menu/hub/persistence owner | Menu changes carry broad regression risk | Pause root/status and the Hub summary now use a typed presenter context; continue one complete screen boundary at a time |
| `gameplay_state.gd` remains a shared state bag and compatibility surface | Ownership and rename safety are obscured | Continue retiring wrappers only after each typed slice reaches its last consumer |
| `root.call/get/set` remains widespread across runtime controllers | Hidden dependencies and runtime-only failures | Reduce calls by feature, measuring before/after rather than performing a global rewrite |
| Six core tuning defaults now live in external `.tres` resources; the index still lists hardcoded gaps | Newly discovered balance knobs are not all inspector-facing yet | Add future knobs incrementally; preserve per-runtime deep-copy isolation and keep balance changes separate |
| Per-pixel image work and synchronous startup paths exist in rendering/audio/UI | Device-specific frame hitches remain possible | Capture repeatable frame-time scenarios before optimization |

## Documentation findings

- Some plans still contain historical dates, branch names, or completion claims;
  use [`DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md) to decide authority.
- Dungeon documents cover authored and generated routes with overlapping names;
  each plan needs explicit run scope before it is reopened.
- Several implemented handoffs do not yet identify a current code owner or
  verification path.
- Historical documents should be archived only after incoming links and save or
  gameplay compatibility rationale have been checked.

## Status language

Use these labels consistently:

- `open`: behavior or evidence is still missing;
- `implemented in source`: focused source/test work exists, runtime proof is
  incomplete;
- `verified`: the stated test or manual matrix passed at a named version/commit;
- `blocked`: external state prevents the specified verification, with the
  blocking condition recorded; and
- `superseded`: the old behavior or plan is retained only for history.

Do not promote an item to `verified` because a test file exists or because a
runner completed only part of its batch.
