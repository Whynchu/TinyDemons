# Mixed-Encounter Performance Correction Plan

Status: revised implementation plan; performance acceptance remains open

Updated: 2026-10-10

Owner: feature owners in [ARCHITECTURE.md](ARCHITECTURE.md)

Parent: [Peak Performance Plan](peak-performance-plan.md)

## Goal

Make `scenes/debug/boss_room_debug.tscn` sustain at least 60 FPS when launched in the Godot editor under the full Run 30 mixed encounter. The uncapped 200+ FPS desktop target is additional headroom. Use seed 24681357, infinite player health, the existing enemy roster, and full elemental effects.

The fixed physics schedule stays at 60 Hz. Rendering above 200 FPS does not require physics at 200 Hz. Record build, Godot version, hardware, renderer, resolution, foreground state, VSync, frame cap, and display refresh. With VSync and caps disabled, rendered throughput can exceed display refresh; distinguish that throughput from frames physically displayed.

This update records the source audit and focused editor capture through
2026-10-10. The editor FPS gate remains open; this document is not runtime
acceptance evidence.

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

**Next implementation checkpoint:** complete the source review of full-rate movement work, then take one focused editor acceptance capture. If that gate still fails, use its scopes to select the next owner. The 60 FPS and 200+ FPS gates remain open.
