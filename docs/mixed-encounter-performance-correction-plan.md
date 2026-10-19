# Mixed-Encounter Performance Correction Plan

Status: source work implemented; current-source editor Run 30 diagnostics miss the 60 FPS and provisional wall-p99 targets, with a large throughput outlier still unexplained

Updated: 2026-10-13

Owner: feature owners in [ARCHITECTURE.md](ARCHITECTURE.md)

Parent: [Peak Performance Plan](peak-performance-plan.md)

## Goal

Make `scenes/debug/boss_room_debug.tscn` sustain at least 60 FPS when launched in the Godot editor under the full Run 30 mixed encounter. The uncapped 200+ FPS desktop target is additional headroom. Use seed 24681357, infinite player health, the existing enemy roster, and full elemental effects.

The fixed physics schedule stays at 60 Hz. Rendering above 200 FPS does not require physics at 200 Hz. Record build, Godot version, hardware, renderer, resolution, foreground state, VSync, frame cap, and display refresh. With VSync and caps disabled, rendered throughput can exceed display refresh; distinguish that throughput from frames physically displayed.

The original source audit and editor captures through 2026-10-10 are retained
as historical context. The 2026-10-13 editor captures and current acceptance
status are recorded in the final section below.

## Quality contract and prerequisite correction

The alternating-tick enemy pass was an experimental throughput tradeoff and is not an accepted optimization. The current `move_slimes` source runs authoritative enemy updates on every scheduled physics tick. Keep movement integration, attacks and hit windows, statuses, healer behavior, contact resolution, and projectile hits on that schedule.

Do not obtain the target by reducing enemy counts, removing effects, changing balance, lowering collision precision, or delaying visible damage/status feedback. Cache expensive decisions only when their inputs are unchanged or invalidate them when relevant state changes. Movement must still integrate every physics tick.

Audit existing shortcuts as part of this work:

- Enemy movement currently runs for each eligible actor every physics tick; do not reintroduce a movement budget that skips actors.
- The separation budget of 28 counts candidate attempts before confirmed overlap and can defer later pairs in a crowded pass. Preserve current collision semantics while reviewing this cap.
- Skeleton target caching must invalidate promptly on relevant target or geometry changes.
- Checking only actor vertices and center does not prove containment in a concave floor or a floor with holes. Retain sufficient floor coverage.
- Preserve swept movement accuracy, boss clearance, contact ordering, and status transmission.

## What the existing full-rate editor capture establishes

An editor-connected full-rate Run 30 window recorded 275 frames across 41.584 seconds: 6.613 FPS, 151.215 ms mean wall interval, p95 190.115 ms, p99 220.865 ms, and 2,153 scheduled physics callbacks (**7.829 per rendered frame**). It used Godot 4.7.2, Windows, Mobile renderer, 960×640, editor/debug build, and a 60 Hz display with VSync enabled. The game window had lost focus by the end, so this is diagnostic evidence, not acceptance.

| Scope | Cost per rendered frame | Calls in capture |
| --- | ---: | ---: |
| Scheduled physics callback | 137.346 ms | 2,153 |
| `frame_controller` (inclusive) | 135.388 ms | — |
| `slime_runtime` (inclusive) | 110.983 ms | — |
| Actor ticks | 66.202 ms | 2,021 |
| Actor runtime | 50.006 ms | 28,734 |
| Scoot/movement | 32.282 ms | 15,024 |
| Contact snapshot | 15.262 ms | 2,021 |
| Enemy separation | 15.418 ms | 2,021 |
| Player contacts | 6.714 ms | — |
| Status visuals | 9.968 ms | 28,734 |
| Actor status ticks | 10.311 ms | 28,734 |
| Enemy overhead HUD | 1.613 ms | — |
| Actor occlusion | 0.210 ms | — |

**Scopes overlap; do not sum them.** Their ranking points to enemy actor work, movement, contact resolution, and status presentation as the first CPU targets. The frame reported roughly 143–178 draw calls and 700–918 render objects, but no GPU frame time; rendering cost is not ruled out. The source-backed system map and practices are in [performance-cost-guide.md](performance-cost-guide.md).

Earlier 6.18 FPS and 6.56 FPS windows are separate runs, not controlled before/after data. The previous 21.14 FPS capture used the experimental alternating-tick pass and is not the current full-rate baseline.

## Step 1 — Use the existing trace to start source work

Owners: `scripts/runtime/controllers/slime_runtime_controller.gd`, `scripts/actors/actor_collision_system.gd`, and their geometry owners.

The existing trace is sufficient to choose the first source pass: make the measured full-rate actor, movement, and contact work cheaper. Do not schedule a separate attribution session or add one-off MCP probes for each visual feature.

Known gaps are already recorded: healer target selection, `EnemyTargetArc` geometry/redraw, projectiles, pickups/interactions, and GPU execution have no exclusive timing in this capture. Keep that uncertainty explicit. If those costs are still plausible after the measured CPU pass, add only a few coarse aggregate scopes to the existing report and collect them as part of the single editor acceptance run. Avoid per-helper timing events and separate test launches.

**Output:** a source change aimed at the largest measured cost, with the next capture reserved for the full editor acceptance gate. Read the report once; repeat only if the capture is invalid or the acceptance gate fails.

## Step 2 — Reduce measured enemy movement and contact work

Owners: `slime_runtime_controller.gd`, `slime_geometry_queries.gd`, `actor_collision_system.gd`, `slime_brain.gd`, and `actor_geometry.gd`.

Several likely one-time optimizations are already present in source: slime actors hold typed component references, callbacks are hoisted outside the actor loop, static obstacle references are cached for the physics frame, and a uniform slime grid serves steering and crowd separation. Do not spend another pass re-implementing those changes.

The measured work that remains is movement, contact snapshots, and separation:

- `try_move_actor_axes` advances through small movement substeps and validates floor/static/motion contacts. Reuse local polygon/transform data within a movement operation when the actor geometry revision is unchanged; invalidate on movement, scale/facing/guide changes, teleport, or room changes.
- `resolve_motion_contacts` considers the player, slimes, and chest candidate pool. Use a conservative broadphase before the exact contact test, while preserving swept movement and actor-size bounds. The large scene-node count is not the size of this candidate pool.
- Contact snapshots allocate pair/eligibility data. Reuse temporary buffers only where no consumer retains them; keep stable pair ordering and complete status-contact coverage.
- The slime grid is built for different positions before and after actor movement. Preserve that phase distinction unless an incremental update can be shown equivalent.
- The 28-attempt separation cap can defer later crowded pairs. Do not simply raise the cap or remove it; reduce duplicate candidate work and preserve fairness/behavior.
- Cache a steering/target decision by its relevant target and geometry revisions, but keep movement integration, attacks, animation, and status simulation on every scheduled tick.

Do not skip position validation on teleports, stale room data, geometry changes, or blocked-move recovery. Preserve the shared actor geometry source for combat, rendering, targeting, and shadows.

**Acceptance:** cheaper full-rate movement/contact work with unchanged movement distance, blocked-move behavior, contact ordering, boss clearance, and status transmission.

## Step 3 — Keep pure presentation out of catch-up work

Owners: `gameplay_frame_controller.gd`, `actor_status_runtime_controller.gd`, `actor_presentation_runtime_controller.gd`, and the corresponding HUD/effect owners.

The frame controller already has an explicit `present` phase; prior work moved repeated HUD, shadow, and health presentation out of catch-up physics callbacks. Keep that separation. Enemy overhead HUD measured 1.613 ms/render in the latest trace, so it is not the first optimization target.

The 9.968 ms/render `enemy_status_visuals` scope is more promising, but `tick_actor_statuses` advances authoritative status pulses and then advances the aura visuals. Split only the pure visual refresh/emission from status simulation, and only where the same emission cadence, appearance, random behavior, and feedback are preserved. Do not move the whole status tick into render presentation.

- Rebuild status/aura textures and geometry only when the status, actor frame, or source geometry changes.
- Apply stable UI text/bar content only when displayed values change; retain smooth interpolation and immediate damage/heal feedback.
- Keep shadow/depth transforms in the existing presentation owner and update them when actor presentation state changes.

**Critical ownership traps:**

- `slime_health_presenter.gd` also inhibits regeneration while aggroed. Move that rule to its authoritative health/combat owner before separating display work.
- Status advancement applies damage/stun pulses. Keep it in simulation.
- Feedback callbacks and projectile updates can change gameplay. Do not move them merely because their names sound visual.
- Effect timing and RNG consumption must preserve event counts and ordering. Do not silently merge multiple physics emissions into one.

**Acceptance:** no duplicate pure presentation during catch-up; unchanged health, hit, cast, status pulse, particle cadence, and feedback timing.

## Step 4 — Reduce contact work without missing contacts

Owner: `scripts/actors/actor_collision_system.gd`.

- Use conservative, actor-size-aware broadphase bounds, including enlarged bosses.
- Generate each eligible pair once in stable order. Reuse per-phase eligibility and geometry with correct invalidation after separation.
- Reuse temporary buffers only when consumers do not retain them. Contact snapshots currently allocate dictionaries, arrays, and pair objects.
- Cache invariant floor/static query setup around swept movement and boss escape probes.
- Correct budget starvation through cheaper complete processing. Do not truncate authoritative contacts to make the benchmark pass.
- Preserve exact narrowphase, swept movement resolution, blocked-move fallback, and status propagation.

**Acceptance:** unchanged contacts in crowded boss overlaps, walls, doorways, concave floors, and narrow corridors; fewer redundant queries and allocations.

## Step 5 — Address effects and rendering when attribution supports it

Owners: `scripts/runtime/services/effects_spawner.gd`, `scripts/runtime/world/occlusion_renderer.gd`, and presentation owners.

Occlusion already guards unchanged base textures and caches generated textures. Measure cold-generation misses and cache growth before changing it. Prewarm finite authored frames only if cold generation causes measured spikes.

Measure effect update cost and allocation/lifetime counts. Pool high-churn objects only where allocation is material and reset semantics are clear. Keep emission count, lifetime, appearance, palette, transparency, front/rear layering, lighting, and depth behavior.

If unexplained render cost remains after CPU reduction, take one targeted renderer/GPU trace. Distinguish submission, overdraw, uploads, synchronization, and GPU execution before selecting a remedy. Use a longer run only if counters indicate continuing growth or a leak.

## First coordinated source batch — editor gate failed

The first implementation pass keeps the full-rate simulation and removes repeated
work along the measured movement path:

- Slime floor validation now transforms collision-guide vertices directly into
  walkability checks instead of allocating a world-space polygon for every
  movement substep. It still checks every vertex, every edge midpoint, and the
  center.
- Post-contact floor/static validation runs only if contact resolution moved
  the actor. The attempted destination is still checked before contacts, and a
  contact push still gets checked before it is committed.
- Contact capture reuses persistent scratch dictionaries between calls.
- Status timers, damage/stun pulses, particle intervals, and RNG consumption
  remain on the physics schedule. Aura tint/outline refresh now uses the existing
  once-per-render presentation phase.
- A Ready healer combines its eligibility, alert, ally, and target checks into
  one pool scan. The target priority and casting gates remain the same.
- The healer arc caches its sampled path until its pixel endpoints change;
  animated sparks/glimmers draw in a small separate layer.

These are source-level optimizations, not measured FPS gains. Keep the target
open until an editor capture passes the Run 30 gate. Its focused follow-up
capture recorded 230 frames over 40.685 seconds: 5.653 FPS, 176.891 ms mean
wall interval, p95 239.543 ms, and p99 263.796 ms. Status-visual cost fell from
9.968 to 5.991 ms/render, but slime runtime rose to 118.987; contact snapshot
rose to 17.965 and separation to 18.212 ms/render. This batch failed the gate
and did not improve whole-scene performance.

## Contact correction — measured improvement, editor gate still fails

Thorn, Hexley, and Pip reviewed the measured trace and source path. The first
version clamped actor-size-aware queries to 64 px; exact contacts use summed
actor radii or collision-rectangle overlap, so an enlarged boss could be missed.
The correction now searches the full actor-size envelope, invalidates its
snapshot cache on grid build/invalidation, and rebuilds grid cells before any
additional separation pass. The exact narrowphase and 28-attempt budget remain
unchanged. Source review proved the envelope bounds both narrowphase shapes;
MCP script diagnostics and `git diff --check` pass.

The focused editor capture after this correction recorded 278 frames over
37.460 seconds: 7.421 FPS, 134.748 ms mean wall interval, p95 170.905 ms, and
p99 190.330 ms, with focus held. Contact snapshot fell from 17.965 to 12.627
ms/render and separation from 18.212 to 9.276; total FPS improved from 5.653 to
7.421. This is a real measured contact-path improvement, but the 60 FPS editor
gate remains far away.

## First movement source correction — headless diagnostic, editor gate open

The fixed-seed headless profile exposed `slime_scoot_updates` inside the larger
`slime_runtime` and `frame_controller` scopes. The first source correction keeps
the full-rate schedule and all floor collision samples, reads the slime guide
transform once per validation, and calls `WalkableArea.is_slime_walkable`
directly for the same points. `SlimeActor.tick_runtime` already computes aggro
to choose its movement branch, so that value now flows through an optional
scoot callback argument instead of being queried again. Existing direct callers
keep the two-argument callback path.

The initial reports recorded 439 µs per scoot update, 470 µs per actor runtime
call, and 11.171 ms per `move_slimes` call after the source correction, against
538 µs, 570 µs, and 13.225 ms in the earlier report. A later process audit
found an orphaned Run 30 headless worker consuming CPU during all four runs;
those comparisons are contaminated and do not establish causal savings. The
raw reports remain listed in [performance-cost-guide.md](performance-cost-guide.md)
for traceability.

The headless run loads and exercises the edited path but does not check rendered
FPS, visuals, or the 60 Hz editor gate. Keep movement integration, floor/static
collision, enemy spacing, attack/cast windows, and status/healing clocks on the
current full-rate schedule. Do not add healer, arc, outline, or effect work
without evidence from a later capture. Next acceptance step: one warmed,
focused Run 30 editor capture when the editor is available.

## Typed spawn dispatch correction — headless diagnostic, editor gate open

The measured `slime_spawn_tick` scope still spent about 1 ms per movement
callback resolving `Spawn` nodes and dispatching component methods. The spawn
component now has a typed class; `SlimeActor` caches its reference and the
runtime uses direct typed calls for active state, ticking, cancellation, and
spawn-lock checks. Skeleton notice presentation also uses the cached `Brain`
reference. The authored frame sequence, hidden-actor pause, collision re-entry,
and full-rate simulation remain unchanged.

The editor's generated global script-class cache did not contain the new
`SlimeSpawnComponent` type. The actor and controller now use a local preloaded
script constant as the type hint, keeping the direct calls and removing the
cache dependency. This correction does not change runtime behavior; the headless
timings above were not rerun for it.

After an immediate pre-change measurement of 1.156 ms per callback, three
headless reports measured 0.872, 0.873, and 0.838 ms. Whole-run throughput
varied from 25.34 to 42.52 FPS, and a process audit found old reports overlapped
an orphaned headless worker while a separate Godot editor remained open. Treat
the per-call reduction as directional; only the focused editor capture can
establish the Run 30 performance gate. A proposed active-only spawn list was
reverted after its repeated headless costs did not show a stable reduction.

## Verification and stopping rules

Before structural changes, characterize the affected behavior: attack/hit frames, cooldowns, healer cast/cancel/heal timing, aggro regeneration suppression, status pulse/transmission timing, movement distance, boss/player contacts, and blocked movement. Include visual checks for layered effects and shadows.

For this performance issue, acceptance is the in-editor Run 30 capture. Avoid repeated MCP start/stop calls and individual subsystem playtests. Keep the existing counters, make a meaningful coordinated source pass, then perform one warmed editor acceptance capture with the game window focused throughout.

Implementation sequence:

1. Keep full-rate movement/combat/status behavior and use the existing traces to select measured work.
2. Record each coordinated source batch separately from its editor result; the first batch reached 5.653 FPS, and the contact correction reached 7.421 FPS.
3. A movement source pass is recorded above; compare the next focused editor result with the 7.421 FPS contact-correction capture, and do not add healer, arc, outline, or effect work without attribution.
4. Run MCP script diagnostics and a source-level review of movement/floor/contact invariants.
5. Run one warmed, 30-second in-editor full-encounter acceptance capture with focus held. If it fails, use that report to choose the next measured owner; do not launch further subsystem probes or standalone runs before the editor gate.

Provisional headroom budgets:

| Target | Scheduled simulation p95 per physics tick | Presentation/submission budget | End-to-end requirement |
| --- | ---: | ---: | --- |
| 60 FPS | ≤5 ms | ≤2 ms | Warm one-second windows ≥60 FPS; p99 wall interval ≤16.67 ms |
| 200+ FPS release | ≤3 ms | ≤1.5 ms | Uncapped warm throughput ≥200 FPS; p99 wall interval ≤5 ms |

These CPU budgets guide work; they cannot prove GPU or end-to-end success. Report every remaining hitch and worst frame. A percentile or average alone cannot demonstrate a literal minimum FPS, and recurring intervals above 33 ms fail the smoothness goal.

Retain changes supported by material savings (roughly 0.5 ms per physics tick, meaningful frame savings, or demonstrated allocation/spike removal) and passed quality checks. Avoid speculative broad refactors.

## Historical evidence and current status

An earlier 23.78-second capture reported 156 frames (6.56 FPS), with scheduled gameplay averaging 19.22 ms per callback. Another full-rate trace recorded 26.04 ms scheduled gameplay and 19.49 ms enemy runtime per callback. Different windows and instrumentation prevent treating these as controlled comparisons.

The 21.14 FPS trace followed the experimental alternating-tick pass and is not an accepted cadence. The 6.613 FPS trace is an earlier diagnostic window whose game window lost focus before capture ended. The later focused 5.653 FPS editor capture is also a failed acceptance result, not a passing gate.

## 2026-10-13 editor Run 30 follow-up

The focused unscoped capture `capture-2026-10-13T08-02-40.json` ran for 78.361
seconds / 4,701 frames with the window focused throughout. It used Godot 4.7.2,
Windows Mobile renderer, 960×640, VSync enabled, and a 60 Hz display. Results:

- Average: 59.991577 FPS; 16.6690 ms average wall interval; 16.4663 ms average
  process time.
- Wall interval p95: 22.647 ms; p99: 28.56 ms; worst: 44.42 ms.
- The average is less than one display frame short of 60 FPS over the capture
  window, but the strict 60.0 comparison remains below target and p99 exceeds
  the provisional ≤16.67 ms budget. Do not mark the performance gate passed.
- The user reports normal local gameplay. This is consistent with the average
  at the 60 Hz ceiling but does not erase the measured tail intervals.

The scoped capture `capture-2026-10-13T08-00-42.json` ran for 82.548 seconds /
4,939 frames at 59.831855 FPS, with 16.957 ms average process time and wall
p95/p99/worst of 23.537/29.486/122.55 ms. Its scopes include instrumentation;
use it to rank source costs, not as the unscoped acceptance result. Top scopes
per rendered frame were physics callback 9.705 ms, frame controller 9.486 ms,
slime runtime 7.175 ms, actor ticks 4.345 ms, actor runtime 3.294 ms, and
presentation 3.088 ms. Full details are in
[`performance-cost-guide.md`](performance-cost-guide.md).

**Next:** use the unscoped capture to choose a measured owner, make a targeted
source pass against the p99 miss, and repeat the focused editor Run 30. The
200+ FPS uncapped headroom target remains separate.

## Latest focused capture — 2026-10-13

The unscoped capture `capture-2026-10-13T09-18-13.json` used the fixed-seed
`scenes/debug/boss_room_debug.tscn` Run 30, with the window focused throughout.
It ran for 43.318 seconds / 2,590 frames on Godot 4.7.2, Windows Mobile
renderer, 960×640, VSync enabled, 60 Hz display, and the Intel i7-5930K.

- Average: 59.790387 FPS; 16.7251 ms average wall-frame interval; 18.6545 ms
  average process time.
- Wall interval p95/p99: 23.872/30.595 ms; worst: 75.974 ms.
- Hitches at or above 16.67 ms: 1,101.
- Scopes were disabled; this is the unscoped acceptance surface.

The strict 60.0 FPS average and provisional p99 ≤16.67 ms thresholds fail.
Average process time is reported as diagnostic data, not a separate acceptance
threshold.
Compared with the earlier 08:02:40 unscoped capture (59.991577 FPS, p99
28.56 ms, worst 44.42 ms), this run is slower and has a worse tail. It does
not establish a regression cause; the two windows are not controlled for
encounter age and workload. Keep the performance gate open and use this report
to select the next measured source pass.

## Contact snapshot allocation and runtime follow-up - 2026-10-13

The `ActorCollisionSystem.capture_status_contact_pairs()` path now reuses one
typed snapshot array and a pool of `StatusContactPair` objects. The synchronous
consumer does not retain contacts, so each capture clears the previous snapshot
and reconfigures the pair objects it needs. A new assertion in the existing
`status_transmission_smoke.gd` checks pair identity reuse, re-entry, and stale
snapshot clearing. A live MCP probe also observed the current snapshot pair ID
equal to its pooled object ID. The smoke has not yet been run because the shared
editor is active.

The post-pool scoped Run 30 report
[`run30-scoped-pool-2026-10-13.json`](evidence/run30-scoped-pool-2026-10-13.json)
measured `slime_contact_snapshot` at 0.9921 ms/frame, versus 0.974 ms/frame in
the earlier scoped reference. This does not show a material CPU reduction; the
pool's demonstrated benefit is removing repeat pair allocations. The paired
unscoped capture
[`run30-warm-pool-2026-10-13.json`](evidence/run30-warm-pool-2026-10-13.json)
has a 199.125 ms first sampled wall interval after the capture-start call and is
diagnostic only. Its 59.712214 FPS average and 26.493 ms p99 do not close the
strict gate.

After those captures, `EnemyActor.tick_runtime()` was simplified to consult its
own `is_defeated()` state instead of receiving a Slime-specific death callback.
That update and a repeated aggro-query removal were followed by a focused
unscoped capture at 59.980229 FPS, with 16.8380 ms average process time,
28.066 ms wall p99, and 42.220 ms worst. The first sampled interval was
40.972 ms, so the capture is diagnostic and the strict gate remains open.
The scoped follow-up measured `slime_actor_runtime` at 3.312 ms/frame and
`slime_scoot_updates` at 1.783 ms/frame versus 3.317/1.740 previously; this is
within measurement noise and shows no material scope reduction. Full evidence
and limits are in [performance-cost-guide.md](performance-cost-guide.md).

The measured source batch also cached attack callbacks and the actor visual
component. A later unmeasured batch caches combat/status references and
knockback callbacks while preserving the current tick cadence. The active
editor now reports a `SlimeActor`/`EnemyActor` type mismatch during factory
assembly. Revalidate that factory path before treating a new performance run as
valid, then continue with the measured actor-runtime target; do not mark the
performance gate passed from the current captures.

## Callback/component-cache follow-up - 2026-10-13

After the attack, component, and knockback callback caches were in place, a
focused unscoped MCP Run 30 capture
[`run30-unscoped-p1p2-followup-2026-10-13.json`](evidence/run30-unscoped-p1p2-followup-2026-10-13.json)
ran 41.970 seconds / 2,381 frames on Godot 4.7.2, Windows Mobile renderer,
960x640, VSync enabled, 60 Hz, with the window reported focused. It measured
56.730998 FPS, 17.6270 ms average wall interval, 18.2390 ms average process
time, wall p95/p99 28.180/47.707 ms, and a 142.994 ms worst interval. The strict
60 FPS average and provisional p99 <=16.67 ms targets fail.

About 34 seconds into the run, `EnemyFactory.configure_actor()` emitted a real
runtime type error: the first argument was `Sprite2D (SlimeActor)` and Godot
rejected it as the expected `EnemyActor` type. This invalidates the run as clean
acceptance evidence. An earlier fresh MCP probe had assembled 16 actors and
successfully replaced `enemy_slot_0000` Slime -> Skeleton -> Slime, so the
failure appears later in the encounter path; its cause is not established. Run
the focused factory and encounter smokes in a clean standalone session before
changing the factory boundary or trusting another performance result.

## Shared factory path correction and current profile - 2026-10-13

The late error path was the boss-phase pool in `RoomController`, which invoked
`ENEMY_FACTORY_SCRIPT` from a local preload while the rest of runtime used the
registered `EnemyFactory` class. The preload was removed and the pool now uses
the registered class too. In the same editor, the boss room then ran past the
previous failure point and through a further 45-second capture without factory
errors. A clean standalone factory/encounter run remains required before
accepting P2.

The focused unscoped capture
[`run30-unscoped-post-factory-fix-2026-10-13.json`](evidence/run30-unscoped-post-factory-fix-2026-10-13.json)
ran 45.128 seconds / 2,700 frames at 59.829817 FPS. Average wall interval was
16.7141 ms, average process time 17.6077 ms, p95/p99 22.737/27.775 ms, and worst
91.085 ms. The window was focused, scopes were disabled, and the runtime error
log was clear. The 60 FPS average and provisional p99 <=16.67 ms target still
fail; this is clean diagnostic evidence, not acceptance.

The companion scoped capture
[`run30-scoped-post-factory-fix-2026-10-13.json`](evidence/run30-scoped-post-factory-fix-2026-10-13.json)
ran 42.994 seconds / 2,579 frames at 59.985114 FPS, with 16.5353 ms average
process time and wall p95/p99/worst of 22.658/28.716/43.450 ms. Top scopes per
rendered frame were physics callback 9.557 ms, frame controller 9.336 ms,
slime runtime 7.097 ms, actor ticks 4.308 ms, actor runtime 3.278 ms, frame
presentation 2.991 ms, scoot updates 1.772 ms, contact snapshot 0.980 ms, and
enemy overhead HUD 0.918 ms. Compared with prior scope runs, cached callbacks
and components have not demonstrated a material reduction in the main enemy
scopes. Continue with a targeted actor-movement or overhead-HUD source pass and
measure it separately; do not change tick cadence or feedback timing.

## Warm Run 30 phase follow-up - 2026-10-13

The latest warmed, focused, unscoped editor capture is
[`run30-unscoped-post-status-allocation-skip-2026-10-13.json`](evidence/run30-unscoped-post-status-allocation-skip-2026-10-13.json):
54.354 seconds / 3,261 frames, 59.995584 FPS, 16.6679 ms average wall
interval, p95/p99 23.081/28.788 ms, 49.507 ms worst, and 1,338 intervals at
or above 16.67 ms. Warm one-second windows averaged 59.994 FPS with a 59.358
minimum. Godot 4.7.2 editor/debug build, Windows Mobile renderer, focused
960x640 window, VSync at 60 Hz. No new factory or runtime errors were logged.
The average is at the display ceiling but remains slightly below 60.0; the
provisional p99 <=16.67 ms threshold remains clearly open.

The paired scoped report
[`run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json`](evidence/run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json)
measured enemy runtime at 7.788 ms/rendered frame (slime runtime 7.523), actor
ticks at 4.556, actor runtime at 3.553, scoot at 1.922, contact snapshot at
1.063, separation at 0.727, player contacts at 0.542, overhead HUD at 0.885,
and frame presentation at 3.002. The added capture-only phases measured
feedback at 0.855, world interactions at 0.741, player core at 0.219, player
finish at 0.064, and projectiles at 0.016 ms. Scopes overlap; use them to rank
work, not as a wall-time acceptance result.

The empty-status result-allocation guard avoids allocating an empty array in
`StatusComponent.advance()` when there are no active records. The paired
unscoped result does not show material wall-time or p99 improvement, so it is
not credited toward the strict performance target. No gameplay cadence, actor
count, collision exactness, or balance changed.

## Map-lighting scope follow-up - 2026-10-13

To check whether the inclusive presentation scope had a meaningful map-lighting
cost, a capture-only timing was added around
`MapLightingController.refresh_for_actor()` and measured in the same focused
`BossRoomDebug` run:
[`run30-scoped-map-lighting-refresh-2026-10-13.json`](evidence/run30-scoped-map-lighting-refresh-2026-10-13.json).
Across 45.813 seconds / 2,729 frames it measured map-light refresh at 0.0232
ms/rendered frame, versus 2.911 ms for inclusive frame presentation and 7.581
ms for enemy runtime. This does not justify changing map-lighting behavior.
Because scope instrumentation was enabled, its 59.568 FPS average, 30.01 ms
wall p99, and 238.031 ms worst interval are diagnostic and do not change the
unscoped acceptance result. No new performance optimization is supported by
this follow-up.

## Focused Run 30 recheck - 2026-10-13

After the focused P2 smoke batch passed, the unscoped editor capture
[`run30-unscoped-recheck-2026-10-13.json`](evidence/run30-unscoped-recheck-2026-10-13.json)
ran 79.362 seconds / 4,757 frames on Godot 4.7.2, Windows Mobile renderer,
960x640, VSync on, 60 Hz, editor/debug build, Intel i7-5930K. The game window
remained focused and the 16-enemy boss-room debug scene had `boot_active=false`.
The MCP runtime reported no errors before it was stopped.

- Average: 59.940526 FPS; 16.6832 ms average wall interval; 16.981 ms average
  process time.
- Wall p50/p95/p99: 16.317/22.536/28.602 ms; worst: 82.975 ms.
- 1,957 intervals were at or above 16.67 ms. The report's process-time p99 is
  sampled every 250 ms and is diagnostic only.

This recheck confirms the strict 60.0 FPS average and provisional <=16.67 ms
wall-p99 targets remain unpassed. It does not identify a new source-level
optimization; keep performance open and retain the earlier scoped capture for
source ranking. The user reports a normal local playtest, which supports
functional behavior but does not satisfy these numerical thresholds. The
affected focused smokes now pass; Web authored-content/autoload runtime proof
and the curated 45-path gate remain open while the MCP editor is active.

## Unscoped Run 30 after diagnostic-only map-lighting timing - 2026-10-13

The current focused unscoped report
[`run30-unscoped-post-map-lighting-scope-2026-10-13.json`](evidence/run30-unscoped-post-map-lighting-scope-2026-10-13.json)
ran 36.176 seconds / 2,132 frames on Godot 4.7.2, Windows Mobile renderer,
960x640, VSync at 60 Hz, editor/debug build. The window remained focused in
`BossRoomDebug`; no runtime errors or warnings were logged. It recorded
58.934100 FPS, 16.9681 ms average wall interval, 17.9562 ms average process
time, p95/p99 25.843/33.462 ms, 145.460 ms worst, and 884 intervals at or
above 16.67 ms. Scopes were disabled. This follow-up fails the strict 60 FPS
average and provisional p99 criteria. It confirms the map-lighting timing has
no active overhead in an unscoped capture; it does not identify a new
source-level optimization. The user reports normal local gameplay, which is
functional evidence but does not satisfy these numerical thresholds.

## Actor-occlusion source check - 2026-10-13

The capture-only scope around `GameplayState._update_actor_occlusion()` was
measured in
[`run30-scoped-actor-occlusion-followup-2026-10-13.json`](evidence/run30-scoped-actor-occlusion-followup-2026-10-13.json).
Across 38.418 seconds / 2,249 focused frames, actor occlusion averaged 0.1492
ms/rendered frame, map lighting 0.0233 ms, enemy runtime 7.820 ms, and
inclusive presentation 2.924 ms. No runtime errors or warnings were logged.
The two presentation subsystems are too small to justify source changes. The
instrumented capture is diagnostic only; it leaves the strict unscoped gate
open.

## Steering invariant hoist follow-up - 2026-10-13

At the time of this follow-up, the measured `slime_scoot_updates` path
recalculated steering values that are constant across one candidate-direction
search. That version calculated the orbit vector/weight, orbit factor, and
attack-cone cosine/denominator once before the candidate loop. It preserved
candidate order, scoring, and physics-tick cadence, and passed MCP script
diagnostics at that checkpoint.

The focused unscoped report
[`run30-unscoped-after-steering-invariants-2026-10-13.json`](evidence/run30-unscoped-after-steering-invariants-2026-10-13.json)
ran 48.982 seconds / 2,921 frames with scopes disabled. It recorded 59.634151
FPS, 16.7689 ms average wall interval, 19.7388 ms average process time,
p50/p95/p99 of 16.342/23.490/28.532 ms, 216 ms worst, and 1,224 intervals
at or above 16.67 ms. The focused window stayed foregrounded. Its first
one-second throughput window was 44.970 FPS and the lowest later window was
57.464 FPS. The strict 60 FPS average and provisional p99 criteria remain
unpassed.

The paired scoped report
[`run30-scoped-after-steering-invariants-2026-10-13.json`](evidence/run30-scoped-after-steering-invariants-2026-10-13.json)
ran 41.972 seconds / 2,497 frames and measured enemy runtime at 7.713
ms/rendered frame, actor ticks at 4.551, actor runtime at 3.501, scoot updates
at 1.837, contact snapshots at 1.056, and enemy separation at 0.591. Scoot
updates measured 1.837 versus 1.912 in the prior scoped report, a small
difference that is not controlled evidence of a causal reduction. Use these
overlapping scopes only for source ranking; the unscoped acceptance gate
remains open.

These captures predate a later shared-worktree rewrite of `slime_brain.gd` as
the shared `EnemyBrain` host. In the current source, the orbit vector, orbit
factor, and cone cosine are again computed inside the candidate loop. The
reports above are historical and do not validate or measure the current
source. A fresh filesystem scan and current BossRoomDebug launch now resolve
the shared `EnemyBrain` host, and focused checks pass for all current
`EnemyBrain` reference files. Repeat the focused performance capture after the
family behavior components and steering changes are characterized; the older
reports do not establish current performance acceptance.

## Current-source Run 30 diagnostics - 2026-10-13

After the shared `EnemyBrain` rewrite, `BossRoomDebug` launched successfully
and reported `boot_active=false`, debug run 30, and 16 `enemies` group members.
The first unscoped capture
[`run30-unscoped-current-source-after-brain-rewrite-2026-10-13.json`](evidence/run30-unscoped-current-source-after-brain-rewrite-2026-10-13.json)
ran 54.526 seconds / 3,208 frames at 58.834317 FPS, with 16.9969 ms average
wall interval, p50/p95/p99 16.256/25.851/35.903 ms, and 158.361 ms worst.
Boot completion was not explicitly queried before this capture; treat it as
diagnostic evidence.

The follow-up unscoped capture
[`run30-unscoped-current-source-after-boot-confirmed-2026-10-13.json`](evidence/run30-unscoped-current-source-after-boot-confirmed-2026-10-13.json)
began after observing `boot_active=false`, debug run 30, and 16 enemy members.
It ran 50.221 seconds / 2,552 frames at 50.815396 FPS, 19.6791 ms average
wall interval, p50/p95/p99 16.745/34.198/77.267 ms, and 184.238 ms worst;
1,308 intervals were at or above 16.67 ms. The first two one-second windows
were 59.117 and 30.828 FPS, and the slowest subsequent window was 5.886 FPS.
The capture service recorded focus only when stopping. No warnings/errors were
reported in the game log. The average and p99 thresholds remain unpassed; do
not select another source optimization until a foreground-only capture explains
the extreme one-second dip. The MCP runtime was still available at the last
diagnostic check, so standalone verification remains deferred.
