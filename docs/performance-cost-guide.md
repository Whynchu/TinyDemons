# Runtime Performance Cost Map and Practices

Status: current implementation cost guide

Scope: source-backed map of the gameplay, presentation, effects, and rendering work visible in the Run 30 editor benchmark

Owner: runtime performance owners with each subsystem's feature owner

Current code: `gameplay_frame_controller.gd`, `gameplay_state.gd`, `slime_runtime_controller.gd`, `slime_geometry_queries.gd`, `enemy_actor.gd`, `slime_brain.gd` (`EnemyBrain`), family brain behavior components, `slime_actor.gd`, `walkable_area.gd`, `actor_collision_system.gd`, `slime_support_component.gd`, `enemy_target_arc.gd`, `actor_status_runtime_controller.gd`, `effects_spawner.gd`, `pickup_runtime_controller.gd`, and `occlusion_renderer.gd`

Verification: source trace plus editor-connected Run 30 captures; the latest unscoped result is recorded below and in the incident plan

Supersedes: none; the incident-specific execution sequence remains in [mixed-encounter-performance-correction-plan.md](mixed-encounter-performance-correction-plan.md)

Updated: 2026-10-10

## The contract

The acceptance surface is the game running in the Godot editor. The Run 30 editor floor remains 60 FPS with full gameplay timing, actor counts, collision behavior, healing, and authored effects. The 200+ FPS uncapped desktop target in the incident plan is additional headroom; it does not replace the editor floor.

Treat each visible system as a workload to trace, not a presumed bottleneck. A line, outline, navigator, particle field, or large scene tree can be expensive, but appearance alone does not establish cost. This guide labels evidence as **measured**, **source-based suspect**, or **not attributed**.

## What the editor captures say

An editor-connected fixed-seed Run 30 capture recorded 275 frames across 41.584 seconds. The game reported 6.613 FPS, 151.215 ms mean wall interval, p95 190.115 ms, p99 220.865 ms, and 2,153 scheduled physics callbacks: 7.829 callbacks per rendered frame. The environment was Godot 4.7.2, Windows, Mobile renderer, 960×640, editor/debug build, and a 60 Hz display with VSync enabled. The game window was no longer focused at the end of capture, so this is diagnostic evidence and not a valid acceptance result.

| Scope | Cost per rendered frame | Calls in capture | Reading |
| --- | ---: | ---: | --- |
| Scheduled physics callback | 137.346 ms | 2,153 | Catch-up simulation is consuming the frame budget. |
| `frame_controller` (inclusive) | 135.388 ms | — | Enclosing schedule; overlaps the scopes below. |
| `slime_runtime` (inclusive) | 110.983 ms | — | Largest located subsystem. |
| `slime_actor_ticks` | 66.202 ms | 2,021 passes | Repeated full-rate actor work. |
| `slime_actor_runtime` | 50.006 ms | 28,734 calls | Main actor loop body. |
| `slime_scoot_updates` | 32.282 ms | 15,024 calls | Movement work is a major measured slice. |
| `slime_contact_snapshot` | 15.262 ms | 2,021 | Contact-pair snapshot work. |
| `slime_enemy_separation` | 15.418 ms | 2,021 | Separation work. |
| `slime_player_contacts` | 6.714 ms | — | Player/enemy contact resolution. |
| `enemy_status_visuals` | 9.968 ms | 28,734 calls | Repeated status presentation work is material. |
| `slime_actor_status_ticks` | 10.311 ms | 28,734 calls | Status tick path; preserve authoritative pulse timing. |
| `enemy_overhead_hud` | 1.613 ms | — | Measured, but not the current largest opportunity. |
| `actor_occlusion` | 0.210 ms | — | Current captured occlusion update is small. |

The scope values are inclusive or nested and **must not be added together**. Their useful result is the ranking: enemy runtime dominates, with actor updates, movement, contacts, and status presentation accounting for large parts of it. With almost eight physics callbacks per rendered frame, a slow callback makes the renderer process a backlog. This points first to cheaper full-rate simulation, not fewer enemies or slower combat.

The first coordinated full-rate source batch was followed by a focused, editor-focused 40.685-second capture (230 frames): 5.653 FPS, 176.891 ms mean wall interval, p95 239.543 ms, and p99 263.796 ms. It recorded slime runtime at 118.987 ms/render, actor ticks at 66.349, scoot movement at 31.243, contact snapshot at 17.965, separation at 18.212, player contacts at 7.491, and status visuals at 5.991. Compared with the earlier diagnostic window, status visuals fell by 3.977 ms/render, while the whole capture was slower and movement/contact scopes did not materially improve. These are separate windows, not a controlled single-variable comparison; treat the differences as direction, not causal savings. The follow-up remains far below the 60 FPS editor gate.

After the actor-contact broadphase/cache correction, a second focused editor
capture recorded 278 frames over 37.460 seconds: 7.421 FPS, 134.748 ms mean
wall interval, p95 170.905 ms, and p99 190.330 ms. The window remained focused.
Slime runtime was 94.001 ms/render, actor ticks 56.133, scoot movement 26.562,
contact snapshot 12.627, separation 9.276, player contacts 7.503, and status
visuals 5.433. Contact snapshot plus separation fell from 36.177 to 21.903
ms/render versus the preceding focused window; total throughput improved, but
the 60 FPS editor requirement remains unmet. These captures are diagnostic
direction, not a controlled single-variable comparison.

The latest focused, unscoped Run 30 capture, `capture-2026-10-13T09-18-13.json`,
ran 43.318 seconds / 2,590 frames at 59.790387 FPS. Its wall p95/p99/worst were
23.872/30.595/75.974 ms; 1,101 sampled frames were at least 16.67 ms. Scopes
were disabled. The window remained focused on Godot 4.7.2 / Windows Mobile,
960×640, VSync on, and a 60 Hz display. It fails the strict average and p99
targets. It was captured before the P3 steering-world change and does not
attribute the tail to a subsystem; see the [incident plan](mixed-encounter-performance-correction-plan.md).

Earlier Run 30 windows in the incident record report different frame rates. Compare runs only when the same code, encounter age, editor focus, renderer, display settings, and workload window are held constant.

## Cost map across the visible game

| Surface | Evidence | Source path and current interpretation | Cost-conscious approach that preserves gameplay |
| --- | --- | --- | --- |
| Frame schedule and catch-up | **Measured:** 7.829 physics callbacks/render; `frame_controller` is 135.388 ms/render inclusive. | [`gameplay_frame_controller.gd`](../scripts/runtime/controllers/gameplay_frame_controller.gd) owns the explicit phase order. The scheduler is spending most of the frame draining fixed-rate work. | Keep the 60 Hz authoritative schedule. Reduce repeated work inside phases and keep pure presentation out of catch-up callbacks. Do not lower tick rate to hide the backlog. |
| Enemy actor simulation | **Measured:** latest slime runtime 94.001 ms/render and actor passes 56.133; earlier windows were 110.983/66.202 and 118.987/66.349. | [`slime_runtime_controller.gd`](../scripts/runtime/controllers/slime_runtime_controller.gd)::`move_slimes` runs actor AI, statuses, movement, contacts, separation, and player contacts. | Cache stable component/callback/geometry data; update intent when relevant state changes; continue movement, attack windows, collision, and status simulation at their authored ticks. |
| Movement and collision | **Measured:** latest scoot 26.562 ms/render, snapshots 12.627, separation 9.276; player contacts 7.503. Earlier windows measured scoot 32.282/31.243, snapshots 15.262/17.965, and separation 15.418/18.212. | [`slime_brain.gd`](../scripts/components/slime_brain.gd) (`EnemyBrain`)::`tick_scoot`, [`slime_runtime_controller.gd`](../scripts/runtime/controllers/slime_runtime_controller.gd)::`try_move_actor_axes`, and [`actor_collision_system.gd`](../scripts/actors/actor_collision_system.gd) perform repeated movement validation and exact contact work. The candidate list is the player, enemies, and chest; the scene's thousands of nodes are not all collision candidates. | Use conservative broadphase buckets before exact tests; reuse local shapes and static-obstacle data with explicit invalidation; retain swept movement and exact narrowphase for candidates that can touch. |
| AI steering and navigation | **Source-based suspect:** decision work is not separated in the capture. | [`slime_brain.gd`](../scripts/components/slime_brain.gd) (`EnemyBrain`)::`context_steering_direction` scores candidate directions and samples actor geometry when a new direction is needed. Target/route searches also exist in enemy behavior. | Recompute paths and steering when a target, relevant geometry revision, or intent changes. Keep movement integration and immediate attack reactions on the physics tick. Avoid a path query every frame for an unchanged target. |
| Healer target selection | **Source-based suspect:** healer scans have no individual timing scope. | [`slime_support_component.gd`](../scripts/components/slime_support_component.gd) checks heal eligibility, alerted allies, and injured candidates. Target selection makes multiple passes over the actor pool. | Maintain a nearby/eligible ally set or spatial lookup and invalidate it on health, aggro, spawn, death, or room changes. Select again when the current target becomes invalid or a relevant ally changes. Keep cast, cancel, and heal timing unchanged. |
| Healer target arc | **Source-based suspect:** the current capture has no arc-specific CPU or GPU timing. | [`enemy_target_arc.gd`](../scripts/actors/enemy_target_arc.gd)::_process updates endpoints and queues a redraw every rendered frame. `_draw` rebuilds sampled points; its sample count grows with distance up to 1,024. Outline points are cached by the renderer, but world-space anchor transforms are repeated. | Cache the stable path and anchor transforms until source/target position, animation frame, or geometry changes. Draw moving sparks as a separate small animated layer so the whole arc need not rebuild for each spark step. Preserve the visible cast line and cast duration. |
| Status simulation and status visuals | **Measured:** status visuals fell 9.968 → 5.991 → 5.433 ms/render; actor status ticks 10.311 → 6.335 → 5.763. | [`actor_status_runtime_controller.gd`](../scripts/runtime/controllers/actor_status_runtime_controller.gd) advances actor statuses; `ElementAuraComponent` and effects update their visuals. The timed visual scope is broad and overlaps actor ticks. | Keep damage/stun pulses, duration, and transmission authoritative on physics ticks. Refresh cached aura/outline data only when status, source frame, or geometry revision changes; update purely presentational transforms once after simulation. |
| Outlines and actor occlusion | **Measured:** `actor_occlusion` 0.210 ms/render in this window. This does not measure the healer arc's endpoint work. | [`occlusion_renderer.gd`](../scripts/runtime/world/occlusion_renderer.gd) caches images, outline textures, and outline points by source texture. | Retain the existing caches and invalidation rules. Do not rewrite all outlines based on the arc suspicion; time the line's CPU geometry and GPU fill separately if it remains a candidate. |
| Projectiles and combat effects | **Not attributed:** no exclusive projectile/effect scope in this capture. | [`magic_runtime_controller.gd`](../scripts/runtime/controllers/magic_runtime_controller.gd) schedules projectiles; [`effects_spawner.gd`](../scripts/runtime/services/effects_spawner.gd) updates pixel particles, notices, sparks, charge auras, and floating numbers. Many source textures/bounds are already cached. | Keep spawning and hit timing exact. Bound active transient work and pool only if allocation or lifetime processing is measured as material. Batch visuals that share textures/materials where the renderer supports it. |
| Pickups and interactions | **Not attributed:** no dedicated pickup, prompt, or interaction timing. | [`pickup_runtime_controller.gd`](../scripts/runtime/controllers/pickup_runtime_controller.gd) updates item, gold, chroma, and soul drops; interaction and prompt work lives in gameplay/player owners. | Restrict proximity checks to nearby candidates; use overlap/state-change events to refresh prompts and pickup eligibility instead of rescanning every object every frame. Keep pickup radius, priority, and input response unchanged. |
| HUD, health bars, and feedback | **Measured:** enemy overhead HUD 1.613 ms/render in this capture. Damage/status feedback is not isolated. | HUD and floating feedback are updated by their runtime owners. Some values can be interpolated for display while their authoritative state changes on fixed ticks. | Update displayed content on value/state changes; interpolate only presentation. Preserve immediate damage, healing, shield, and cast feedback. |
| World rendering, particles, transparency, and lighting | **Not attributed to GPU:** the capture showed roughly 143–178 draw calls and 700–918 render objects, but it did not include GPU frame time or per-layer overdraw. | Static tiles, layered pixel effects, transparent sprites, lights, and materials share the final render. Object count alone does not identify a GPU bottleneck. | Keep texture/material changes low, avoid unnecessary transparent coverage, and profile GPU time before changing art, layers, or lights. Do not assume a low draw-call count means GPU cost is low. |

## Recommended fix order

1. **Resolve the measured contact path safely.** The source correction now uses actor-size-aware bounds, invalidates geometry caches on grid changes, and refreshes cells before another separation pass. The focused editor capture shows lower contact cost, while contact behavior still uses the original narrowphase.
2. **Reduce full-rate movement work.** The first bounded source pass hoists guide transforms and passes the tick's existing aggro result into scoot presentation; headless per-call data below is promising but not a substitute for the editor acceptance capture.
3. **Do not prioritize healer scans, the target arc, outlines, effects, pickups, or GPU work from appearance alone.** Their individual costs are unmeasured here. Reconsider them only if a future report supports the cost, using coarse existing scopes instead of subsystem playtests.

## Practices supported by Godot's guidance

- Use the profiler's inclusive and self time to find where cost is owned; nested totals are not additive. Profiling itself adds overhead, so use the narrowest capture that answers the question. See [The Profiler](https://docs.godotengine.org/en/latest/tutorials/scripting/debug/the_profiler.html).
- Godot's custom 2D drawing caches draw commands until `queue_redraw()` is requested. Dirty the geometry when it changes instead of rebuilding an unchanged path each frame. See [Custom drawing in 2D](https://docs.godotengine.org/en/4.5/tutorials/2d/custom_drawing_in_2d.html).
- Navigation queries should follow meaningful target changes, not run unconditionally every frame. See [Optimizing Navigation Performance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html).
- Low-level rendering/physics servers are an option only after profiling demonstrates scene-system overhead. Server queries can introduce synchronization costs, so lower-level code is not automatically faster. See [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html).
- GPU work needs GPU-specific evidence. Similar textures/materials can batch, while transparent overdraw and extra material changes can cost more than their draw-call count suggests. See [GPU optimization](https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html).

These practices lead to the same broad architecture used by performance-sensitive games: fixed-rate authoritative simulation; slower, invalidation-driven decisions; spatial broadphase followed by precise tests; cached immutable geometry/assets; state-driven presentation; and bounded transient effects. They improve the amount of work without changing how often the game moves, attacks, heals, collides, or shows feedback.

## Quick headless CPU triage

Run the fixed-seed mixed Run 30 scene through the existing headless wrapper:

    pwsh -NoProfile -ExecutionPolicy Bypass -File tools/run_headless.ps1 -Script res://tools/profile_run30_headless.gd

The profile warms for one second, samples ten seconds of runtime, writes a JSON
report under user://performance-captures/, prints the absolute report path,
and exits. The report includes boot phase times, sampled engine counters,
scoped CPU costs, and the exact fixture path. Headless removes editor rendering,
VSync, and window focus from the measurement. Use the scope ranking to choose
CPU-side source work; its FPS and render counters are not editor acceptance
evidence. Confirm changes with one focused Run 30 capture in the editor.

## Headless movement correction diagnostic (2026-10-10)

The retained Run 30 correction preserves every floor-shape vertex, edge midpoint,
and center check while reading the guide transform once per validation and
calling the owning `WalkableArea` directly. The actor tick also passes its
already-computed aggro boolean into the scoot update, avoiding a second aggro
query on the same physics tick. Optional callback arguments retain the existing
fallback for direct callers.

Four Godot 4.7.1 headless runs used the same fixed-seed fixture. Their rendered
FPS varied widely, so compare the scoped costs per call rather than per rendered
frame. `slime_runtime` is one outer scope per `move_slimes` invocation; some
scheduled callbacks do not enter that gameplay path. The other actor scopes are
per actor call.

| Report | Source state | Physics calls | Scoot calls | Scoot update per call | Actor runtime per call | Slime runtime per call |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `capture-2026-10-10T12-11-54.json` | Baseline | 654 | 3,810 | 538 µs | 570 µs | 13.225 ms |
| `capture-2026-10-10T12-18-54.json` | Guide transform/query hoist | 654 | 3,811 | 517 µs | 582 µs | 14.577 ms |
| `capture-2026-10-10T12-22-29.json` | Geometry and outer aggro result reuse (retained) | 647 | 3,787 | 439 µs | 470 µs | 11.171 ms |
| `capture-2026-10-10T12-27-57.json` | Tried deeper aggro reuse in `SlimeBrain.tick_scoot`; reverted | 653 | 3,767 | 447 µs | 499 µs | 12.020 ms |

These raw reports initially appeared to show lower per-call costs after the
movement correction. A later process audit found an orphaned Run 30 headless
worker still consuming CPU during all four captures, so the source comparisons
are contaminated and cannot support causal savings claims. Keep the table for
traceability only. Rendering metrics were unavailable; a focused editor
capture remains the acceptance check.

The additional attempt to pass the aggro result into `SlimeBrain.tick_scoot`
was removed. Its headless comparison is also contaminated by that worker and
should not be used to estimate the change's effect.

## Typed spawn dispatch diagnostic (2026-10-10)

The Run 30 spawn sweep still spent about 1 ms per `move_slimes` callback. The
controller was resolving each actor's `Spawn` node and calling its state checks
dynamically. `SlimeActor` already caches its component references, so the spawn
component now has a typed class and the runtime uses that cached reference for
the active check, tick, cancel, and spawn-lock query. Skeleton notice
presentation also reads the actor's cached `Brain` reference. Spawn frame timing,
visibility pause behavior, collision re-entry, and the fixed-rate schedule are
unchanged.

The editor later reported that `SlimeSpawnComponent` was absent from its
generated global script-class cache. The actor and runtime controller now use a
local `preload()` constant for that component's static type, preserving direct
typed calls while avoiding that cache dependency. This is a type-resolution
correction; the recorded timing results above were not rerun for it.

| Report | Source state | `slime_spawn_tick` per callback | Headless FPS |
| --- | --- | ---: | ---: |
| `capture-2026-10-10T12-54-49.json` | Before typed dispatch | 1.156 ms | 18.48 |
| `capture-2026-10-10T12-57-22.json` | Typed cached component | 0.872 ms | 25.34 |
| `capture-2026-10-10T12-58-31.json` | Typed cached component repeat | 0.873 ms | 35.36 |
| `capture-2026-10-10T13-06-39.json` | Final source after reverting active-list experiment | 0.838 ms | 42.52 |

The immediate pre-change and three later captures suggest the spawn scope is
about 24–28% lower, or roughly 0.28–0.32 ms per `move_slimes` callback. Older
pre-change reports ranged from 0.899 to 1.036 ms, so this remains directional
headless evidence rather than a controlled causal comparison. An active-only
spawn-list experiment varied from 0.815 to 0.960 ms per callback and was
removed because it did not show a repeatable gain.

A process audit found an orphaned headless `profile_run30_headless.gd` worker
from 12:09 still consuming CPU during the 12:11–12:27 reports; those earlier
captures are contaminated and should not support causal comparisons. The
orphaned workers were stopped. A separate Godot 4.7.2 editor remained open for
the later captures, so their throughput also reflects an uncontrolled host.
The final 13:06 report recorded 519 frames, 42.52 average headless FPS, and a
59.812 ms wall-frame p95. Rendering metrics were unavailable; this does not
pass the 60 FPS editor gate.

## Run 30 follow-up — 2026-10-13

Two focused captures followed the full-rate movement and hidden-HUD-path work.
Both used `scenes/debug/boss_room_debug.tscn`, Godot 4.7.2, Windows Mobile
renderer at 960×640, a focused game window, 60 Hz display, and VSync enabled.
The scoped report includes instrumentation and must be read separately from the
unscoped result.

| Capture | Scopes | Duration / frames | Average FPS | Average process | Wall p95 / p99 / worst |
| --- | --- | ---: | ---: | ---: | ---: |
| `capture-2026-10-13T08-00-42.json` | On | 82.548 s / 4,939 | 59.831855 | 16.957 ms | 23.537 / 29.486 / 122.55 ms |
| `capture-2026-10-13T08-02-40.json` | Off | 78.361 s / 4,701 | 59.991577 | 16.4663 ms | 22.647 / 28.56 / 44.42 ms |

The unscoped average is less than one frame short of the theoretical 60 Hz
count over the capture duration, and its average process time is below 16.67 ms.
It still records 59.991577 FPS rather than a strict 60.0, and its p99 wall
interval misses the provisional ≤16.67 ms smoothness target. Treat this as
performance at the display ceiling with unresolved frame-time tails, not a
strict acceptance pass. The user reports the local playtest looked normal.

The scoped report attributes per rendered frame: physics callback 9.705 ms,
frame controller 9.486 ms, slime runtime 7.175 ms, actor ticks 4.345 ms, actor
runtime 3.294 ms, presentation 3.088 ms, scoot/movement 1.741 ms, contact
snapshot 0.974 ms, enemy HUD 0.946 ms, and separation 0.690 ms. These inclusive
scopes overlap and instrumentation affects the total; do not add them or treat
the scoped 59.831855 FPS as the uninstrumented result.

## Editor measurement rule

Use the existing Run 30 report as the baseline for choosing source work. The next capture should be one consolidated, warmed editor run after a meaningful batch of changes, with the editor game focused for the entire window and the same seed, renderer, display settings, and encounter composition. Read its report once; repeat only if the acceptance gate fails or the capture itself is invalid. The source-cost map is useful for deciding what to change, but only a focused editor run can establish that the 60 FPS floor was reached.

## Latest focused capture — 2026-10-13

The unscoped `capture-2026-10-13T09-18-13.json` is a 43.318-second / 2,590-frame
Run 30 of `scenes/debug/boss_room_debug.tscn`. The game window stayed focused;
scopes were disabled. It ran in the editor on Godot 4.7.2, Windows Mobile
renderer, 960×640, VSync enabled, at a 60 Hz display on an Intel i7-5930K.

- Average: 59.790387 FPS; average wall-frame interval 16.7251 ms; average
  process time 18.6545 ms.
- Wall interval p95/p99: 23.872/30.595 ms; worst: 75.974 ms.
- Hitches at or above 16.67 ms: 1,101.

The strict 60 FPS average and provisional p99 ≤16.67 ms checks fail. Average
process time is reported as diagnostic data, not a separate acceptance
threshold. This capture predates the P3 steering-world injection; it does not
measure that change or identify a regression cause.

## Snapshot-pool diagnostic - 2026-10-13

After warming Run 30 for 20 seconds, the unscoped capture
[`run30-warm-pool-2026-10-13.json`](evidence/run30-warm-pool-2026-10-13.json)
ran 44.547 seconds / 2,660 frames at 59.712214 FPS. Average process time was
19.3938 ms; wall p95/p99/worst were 21.514/26.493/199.125 ms. The first sampled
wall interval was 199.125 ms and sampled-process p99 was 142.73 ms, so treat
this as diagnostic evidence of a capture-start hitch rather than acceptance.

The focused scoped capture
[`run30-scoped-pool-2026-10-13.json`](evidence/run30-scoped-pool-2026-10-13.json)
ran 53.181 seconds / 3,186 frames at 59.908614 FPS, with 17.6736 ms average
process time and 28.452 ms wall p99. `slime_contact_snapshot` measured
0.9921 ms per rendered frame versus 0.974 ms in the earlier scoped reference;
that is within measurement noise and does not show a material CPU reduction.
The contact-pair pool removes repeat `StatusContactPair` allocations after
capacity is reached, confirmed by a live runtime instance ID matching the pool.
Keep the strict performance gate open. The next measured areas are
`slime_actor_runtime` (3.317 ms/frame) and `slime_scoot_updates` (1.740
ms/frame); these inclusive scopes overlap the broader actor/runtime scopes.

## Runtime callback-cache follow-up — 2026-10-13

The focused unscoped report
[`run30-unscoped-after-runtime-cache-2026-10-13.json`](evidence/run30-unscoped-after-runtime-cache-2026-10-13.json)
ran for 46.532 seconds / 2,791 frames at 59.980229 FPS. Average wall interval
was 16.6722 ms and average process time was 16.8380 ms; wall p95/p99/worst were
22.709/28.066/42.220 ms. The window stayed focused, but its first sampled
interval was 40.972 ms, so the run is diagnostic and fails the strict 60 FPS
average and provisional p99 ≤16.67 ms limits.

The scoped follow-up
[`run30-scoped-after-callback-cache-2026-10-13.json`](evidence/run30-scoped-after-callback-cache-2026-10-13.json)
ran for 51.027 seconds / 3,043 frames with instrumentation enabled. It
measured `slime_actor_runtime` at 3.312 ms/frame and `slime_scoot_updates` at
1.783 ms/frame, effectively unchanged from 3.317/1.740 in the prior scoped
report. Callback caching therefore has no demonstrated CPU reduction in these
scopes; the full-window measurements vary and do not establish causality.

The captured source had removed a repeated aggro query and cached attack
callbacks plus the actor's visual component. Later changes cache combat/status
component reads and knockback callbacks; those changes have not been captured.
The active editor currently reports an EnemyFactory actor type mismatch, so
wait for a clean factory/runtime load before the next Run 30 measurement. Keep
the performance gate open.

## Callback/component-cache Run 30 follow-up - 2026-10-13

The unscoped MCP capture
[`run30-unscoped-p1p2-followup-2026-10-13.json`](evidence/run30-unscoped-p1p2-followup-2026-10-13.json)
ran 41.970 seconds / 2,381 frames with the window reported focused. It measured
56.730998 FPS, 17.6270 ms average wall interval, 18.2390 ms average process
time, p95/p99 28.180/47.707 ms, and a 142.994 ms worst interval. The strict
60 FPS average and provisional p99 <=16.67 ms target both fail. The captured
window includes a late factory failure and is diagnostic, not acceptance.

At about 34 seconds, `EnemyFactory.configure_actor()` rejected a
`Sprite2D (SlimeActor)` as its typed `EnemyActor` argument. This follows an
earlier clean MCP startup and successful Slime -> Skeleton -> Slime replacement
of roster slot `enemy_slot_0000`. Preserve both observations; use clean
standalone factory/encounter smokes to locate the late failure before the next
Run 30 capture.

## Shared factory path correction - 2026-10-13

The late error occurred in the boss-phase pool path in `RoomController`, which
used a preloaded `EnemyFactory` script while other runtime paths used the
registered class. `RoomController` now calls the registered class as well. The
subsequent focused unscoped capture
[`run30-unscoped-post-factory-fix-2026-10-13.json`](evidence/run30-unscoped-post-factory-fix-2026-10-13.json)
ran 45.128 seconds / 2,700 frames with no factory errors. It measured 59.829817
FPS, 16.7141 ms average wall interval, 17.6077 ms average process time,
p95/p99 22.737/27.775 ms, and a 91.085 ms worst interval. The strict 60 FPS
average and provisional p99 <=16.67 ms target still fail.

The scoped companion
[`run30-scoped-post-factory-fix-2026-10-13.json`](evidence/run30-scoped-post-factory-fix-2026-10-13.json)
measured physics callback at 9.557 ms/frame, frame controller 9.336,
slime runtime 7.097, actor ticks 4.308, actor runtime 3.278, frame presentation
2.991, scoot updates 1.772, contact snapshot 0.980, and enemy overhead HUD
0.918. The actor and scoot scopes are nearly unchanged from the preceding
callback-cache capture. Use movement validation or overhead presentation as
the next measured source candidate; retain full-rate movement, contact, status,
attack, and feedback behavior. The clean runtime is a positive factory check,
but standalone factory/family tests and the curated gate remain outstanding.

## Warm Run 30 frame-phase follow-up - 2026-10-13

After the shared factory-path correction and the capture-only frame-phase scopes,
the warmed, focused, unscoped Run 30 report
[`run30-unscoped-post-status-allocation-skip-2026-10-13.json`](evidence/run30-unscoped-post-status-allocation-skip-2026-10-13.json)
ran 54.354 seconds / 3,261 frames on Godot 4.7.2, Windows Mobile renderer,
960x640, VSync on, 60 Hz, editor/debug build, Intel i7-5930K. The window
remained focused.

- Average: 59.995584 FPS; 16.6679 ms average wall interval; 16.9809 ms average
  process time.
- Wall p50/p95/p99: 16.272/23.081/28.788 ms; worst: 49.507 ms.
- 1,338 frame intervals were at or above 16.67 ms. Warm one-second windows
  averaged 59.994 FPS; the minimum was 59.358 FPS.
- No fresh editor errors occurred in the restarted 16-enemy boss-room runtime.

The strict 60.0 FPS and provisional p99 <=16.67 ms criteria remain unpassed.
Average process time and the report's process-time sample percentile are
diagnostic only. The report samples `Performance.TIME_PROCESS` every 250 ms;
its sampled p99 is not a per-frame p99. Wall-frame percentiles are calculated
from every frame. Godot also documents that performance monitors may lag by up
to one second ([Performance class](https://docs.godotengine.org/en/4.7/classes/class_performance.html)).

The matching scoped phase report
[`run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json`](evidence/run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json)
ran 49.954 seconds / 2,990 frames. Because instrumentation adds work, use it
only for ranking scopes. Per rendered frame it measured physics callback
10.062 ms, frame controller 9.848, enemy runtime 7.788 (slime runtime 7.523),
actor ticks 4.556, actor runtime 3.553, scoot updates 1.922, contact snapshot
1.063, separation 0.727, player contacts 0.542, overhead HUD 0.885, and frame
presentation 3.002. The phase scopes recorded enemy runtime 7.788, feedback
0.855, world interactions 0.741, player core 0.219, player finish 0.064, and
projectiles 0.016 ms. These are inclusive or nested measurements; do not add
them as if independent.

`StatusComponent.has_active_records()` now lets the actor-status runtime skip
`advance()` when a component has no records, avoiding a fresh empty result array
on that path. The paired unscoped capture does not demonstrate a material frame
time or tail reduction. Keep the change classified as allocation removal, not
as proof that the P1 performance gate passed. Earlier callback/component caches
also remain without a demonstrated material reduction in their measured scopes.

## Map-lighting scope follow-up - 2026-10-13

The focused scoped capture
[`run30-scoped-map-lighting-refresh-2026-10-13.json`](evidence/run30-scoped-map-lighting-refresh-2026-10-13.json)
ran 45.813 seconds / 2,729 frames in the focused Godot 4.7.2 editor/debug
`BossRoomDebug` scene. It isolated `frame_map_lighting_refresh` at 0.0232
ms/rendered frame, while the inclusive `frame_presentation` scope measured
2.911 ms and `frame_enemy_runtime` measured 7.581 ms. Map-light refresh is not
a justified optimization target at this cost. The capture has instrumentation
enabled and a 30.01 ms wall p99 / 238.031 ms worst frame, so it is diagnostic
only and does not replace the unscoped performance acceptance capture.

## Unscoped Run 30 follow-up - 2026-10-13

With timing scopes disabled, a focused editor run
[`run30-unscoped-post-map-lighting-scope-2026-10-13.json`](evidence/run30-unscoped-post-map-lighting-scope-2026-10-13.json)
ran 36.176 seconds / 2,132 frames in `BossRoomDebug` on Godot 4.7.2, Windows
Mobile renderer, 960x640, VSync at 60 Hz, editor/debug build. It measured
58.934100 FPS, 16.9681 ms average wall interval, and 17.9562 ms average
process time. Wall p50/p95/p99 were 16.253/25.843/33.462 ms, with 145.460 ms
worst and 884 intervals at or above 16.67 ms. The window was focused and no
runtime errors or warnings were logged. The result fails the strict 60 FPS and
provisional p99 target. It follows the diagnostic-only map-lighting timing and
does not show that map-lighting instrumentation caused the miss.

## Actor-occlusion scope follow-up - 2026-10-13

The next focused scoped report
[`run30-scoped-actor-occlusion-followup-2026-10-13.json`](evidence/run30-scoped-actor-occlusion-followup-2026-10-13.json)
ran 38.418 seconds / 2,249 frames in `BossRoomDebug` with timing scopes
enabled. It attributed 0.1492 ms/rendered frame to actor occlusion, 0.0233 ms
to map lighting, 7.820 ms to enemy runtime, and 2.924 ms to inclusive
presentation. The runtime window was focused and logged no errors or warnings.
Actor occlusion and map lighting are not worthwhile optimization targets at
these costs; the larger enemy-runtime owner remains the strongest measured
candidate. The capture's wall percentiles include scope instrumentation and are
not acceptance data.
