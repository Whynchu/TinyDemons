# Runtime Performance Cost Map and Practices

Status: current implementation cost guide

Scope: source-backed map of the gameplay, presentation, effects, and rendering work visible in the Run 30 editor benchmark

Owner: runtime performance owners with each subsystem's feature owner

Current code: `gameplay_frame_controller.gd`, `gameplay_state.gd`, `slime_runtime_controller.gd`, `slime_geometry_queries.gd`, `slime_actor.gd`, `slime_brain.gd`, `walkable_area.gd`, `actor_collision_system.gd`, `slime_support_component.gd`, `enemy_target_arc.gd`, `actor_status_runtime_controller.gd`, `effects_spawner.gd`, `pickup_runtime_controller.gd`, and `occlusion_renderer.gd`

Verification: source trace plus the existing editor-connected Run 30 capture recorded below; no new playtest was run for this guide

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

Earlier Run 30 windows in the incident record report different frame rates. Compare runs only when the same code, encounter age, editor focus, renderer, display settings, and workload window are held constant.

## Cost map across the visible game

| Surface | Evidence | Source path and current interpretation | Cost-conscious approach that preserves gameplay |
| --- | --- | --- | --- |
| Frame schedule and catch-up | **Measured:** 7.829 physics callbacks/render; `frame_controller` is 135.388 ms/render inclusive. | [`gameplay_frame_controller.gd`](../scripts/runtime/controllers/gameplay_frame_controller.gd) owns the explicit phase order. The scheduler is spending most of the frame draining fixed-rate work. | Keep the 60 Hz authoritative schedule. Reduce repeated work inside phases and keep pure presentation out of catch-up callbacks. Do not lower tick rate to hide the backlog. |
| Enemy actor simulation | **Measured:** latest slime runtime 94.001 ms/render and actor passes 56.133; earlier windows were 110.983/66.202 and 118.987/66.349. | [`slime_runtime_controller.gd`](../scripts/runtime/controllers/slime_runtime_controller.gd)::`move_slimes` runs actor AI, statuses, movement, contacts, separation, and player contacts. | Cache stable component/callback/geometry data; update intent when relevant state changes; continue movement, attack windows, collision, and status simulation at their authored ticks. |
| Movement and collision | **Measured:** latest scoot 26.562 ms/render, snapshots 12.627, separation 9.276; player contacts 7.503. Earlier windows measured scoot 32.282/31.243, snapshots 15.262/17.965, and separation 15.418/18.212. | [`slime_brain.gd`](../scripts/components/slime_brain.gd)::`tick_scoot`, [`slime_runtime_controller.gd`](../scripts/runtime/controllers/slime_runtime_controller.gd)::`try_move_actor_axes`, and [`actor_collision_system.gd`](../scripts/actors/actor_collision_system.gd) perform repeated movement validation and exact contact work. The candidate list is the player, slimes, and chest; the scene's thousands of nodes are not all collision candidates. | Use conservative broadphase buckets before exact tests; reuse local shapes and static-obstacle data with explicit invalidation; retain swept movement and exact narrowphase for candidates that can touch. |
| AI steering and navigation | **Source-based suspect:** decision work is not separated in the capture. | [`slime_brain.gd`](../scripts/components/slime_brain.gd)::`context_steering_direction` scores candidate directions and samples actor geometry when a new direction is needed. Target/route searches also exist in enemy behavior. | Recompute paths and steering when a target, relevant geometry revision, or intent changes. Keep movement integration and immediate attack reactions on the physics tick. Avoid a path query every frame for an unchanged target. |
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

## Editor measurement rule

Use the existing Run 30 report as the baseline for choosing source work. The next capture should be one consolidated, warmed editor run after a meaningful batch of changes, with the editor game focused for the entire window and the same seed, renderer, display settings, and encounter composition. Read its report once; repeat only if the acceptance gate fails or the capture itself is invalid. The source-cost map is useful for deciding what to change, but only a focused editor run can establish that the 60 FPS floor was reached.
