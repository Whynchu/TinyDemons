# Tiny Demons — Peak Performance Plan

Status: active plan

Scope: cold startup, title/menu responsiveness, hub, room runtime, combat,
effects, memory, rendering, and browser/mobile verification

Owner: runtime performance owners, with `GameplayBootstrap` as the lifecycle
composition boundary

Current code: `scripts/performance_capture_service.gd`,
`scripts/gameplay_bootstrap.gd`, `scripts/gameplay_state.gd`,
`scripts/gameplay_frame_controller.gd`, `scripts/occlusion_renderer.gd`,
`scripts/slime_runtime_controller.gd`, `scripts/effects_spawner.gd`, and the
web export settings

Verification: deterministic capture scenarios, focused smoke tests, standalone
web export checks, and Samsung A17 browser measurements

Supersedes: none; this plan specializes the performance track in
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)

Updated: 2026-09-19

## Outcome

Tiny Demons must feel immediate on a low-end Android browser, not merely reach
an acceptable average FPS on a desktop. The title screen and menus are release
gates: if they hitch, heat the device, or take too long to become interactive,
the game has already failed before gameplay begins.

The target is achieved by reducing work performed, especially work performed
before it is needed. A frame-rate cap is not the strategy. The game keeps its
responsive 60 FPS target and earns headroom through lifecycle separation,
bounded caches, fewer allocations, cheaper rendering, and deterministic
verification.

## Current evidence

The debug-only `PerformanceCaptureService` can start and stop through MCP and
returns structured JSON without an in-game overlay. It currently captures
frame time, p99/worst frame, hitch count, physics time, FPS, node/object counts,
draw calls, render objects, video memory, static memory, and scoped subsystem
timings.

The first deterministic active-room capture on Godot 4.7.1 / Windows Mobile
renderer reported:

| Measure | Observed value | Interpretation |
|---|---:|---|
| Average frame | 11.02 ms | Desktop has headroom in this scenario |
| Worst frame | 12.12 ms | No desktop hitch in this sample |
| Slime runtime | 6.51 ms/frame | First confirmed gameplay hotspot |
| Actor occlusion | 0.19 ms/frame | Not the current primary hotspot |
| Draw calls | 63–78 | Not currently excessive on desktop |
| Nodes | 1,662–1,681 | Large for a minimalist title |
| Objects | 10,500–11,200 | Must be reduced or deferred on menu paths |
| Video memory | 102–116 MB | Warmup and cache growth require lifecycle profiling |

The title/menu path is not yet device-safe. The runtime also prepares a large
amount of gameplay state before the player starts a run, including a 13-slot
slime roster and broad visual/cache data. Desktop numbers must not be treated
as evidence that the A17 browser path is acceptable.

The slime palette preparation path has now been removed from that startup cost:
`SlimeVisualComponent` keeps one shared source frame set, while
`ActorPaletteMaterial.for_slime_palette()` maps the green source tones in the
shader for each target palette. Idle, attack, shocked, spawn, boss, and shadow
frames no longer produce per-pixel palette `ImageTexture` variants. The focused
slime, boss-palette, rogue-slime, and player palette-material smoke tests pass;
the live boot capture and screenshot are still pending after the editor reload.

## Provisional release budgets

These are engineering targets until real A17 captures replace them with
device-backed numbers. They are intentionally stricter than the 16.67 ms 60 FPS
deadline so the browser, display compositor, and thermal conditions have room.

| Scenario | Target | Hard failure |
|---|---:|---:|
| Title/menu steady frame p95 | ≤ 8.33 ms | Any repeatable >16.67 ms hitch |
| Title/menu p99 | ≤ 12 ms | Any repeatable >33.3 ms hitch |
| Active room frame p95 | ≤ 12 ms | Repeatable missed 60 FPS |
| Active room p99 | ≤ 16.67 ms | Hitches during ordinary movement |
| Combat/effects p95 | ≤ 14 ms | Combat hitch or input delay |
| Cold launch to interactive title | ≤ 2.0 s | Blank/frozen launch or browser watchdog risk |
| Warm launch to interactive title | ≤ 1.0 s | Menu feels delayed |
| Menu transition | ≤ 100 ms visible stall | Input appears dropped |
| Post-warm memory trend | Flat over 5 minutes | Sustained growth without reclamation |
| Release capture overhead | 0 | Instrumentation ships enabled |

The budgets apply to the actual Web export on the target device. Desktop
captures are regression signals, not substitutes for A17 evidence.

## Non-negotiable principles

1. Keep the 60 FPS interaction target and remove work instead of hiding it with
   a cap.
2. Title, menus, hub, and gameplay have separate lifecycle budgets.
3. Do not instantiate actors, effects, caches, or controllers before their
   owning mode needs them.
4. Preserve the explicit gameplay frame schedule; do not add ad-hoc process
   loops to bypass it.
5. Measure p95/p99 and hitch counts, not only average FPS.
6. Do not trade input latency or visual responsiveness for a better average.
7. Every optimization must have a before/after capture and a focused
   behavior check.
8. Debug telemetry is editor/debug-only and must not become a release overlay
   or a third-party runtime dependency.

## Workstream 1 — Make measurement automatic

### 1.1 Complete the capture service

- Add capture metadata: scenario name, seed, room type, input route, build
  target, renderer, viewport, and warm/cold state.
- Add startup checkpoints: process start, root ready, title visible, menu
  interactive, save menu interactive, run interactive, first room ready.
- Add subsystem scopes for gameplay frame, slime movement, slime collision,
  slime attack, animation, occlusion, effects, projectiles, UI, room entry,
  save work, and audio transitions.
- Add p50/p95/p99 frame and scope values, not only averages.
- Track object/node/texture/video-memory deltas from capture start and after
  warmup; distinguish warmup growth from steady-state growth.
- Add a deterministic scenario command that returns a completed report to MCP.

### 1.2 Define repeatable scenarios

The capture runner must be able to execute these without manual menu work:

1. cold launch → title interactive;
2. title idle for 30 seconds;
3. save-select idle and navigation;
4. hub idle and menu open/close;
5. active room idle;
6. active room movement;
7. ordinary combat with the standard roster;
8. projectile/effect-heavy combat;
9. room transition;
10. five-minute warm-session leak/thermal proxy capture.

Each scenario uses a fixed seed and records its route. The same scenario is
run before and after every performance change.

### 1.3 Add regression artifacts

Store compact JSON summaries in ignored local capture output and retain only
small, intentional baseline summaries in the repository. A performance change
is not accepted from a screenshot or subjective feel alone.

## Workstream 2 — Split lifecycle ownership

This is the highest-priority optimization because the A17 currently struggles
before gameplay.

### 2.1 Title/menu boot boundary

The initial scene should create only:

- display and responsive layout;
- input/device tracking;
- settings/profile access needed by the title;
- title/menu presentation;
- audio unlock and minimal title audio;
- performance capture service in debug builds.

It should defer:

- the slime roster and slime frame dictionaries;
- room generation and walkable geometry;
- combat, targeting, projectile, pickup, and enemy services;
- occlusion image caches;
- effect and damage-number caches;
- gameplay-only shadows, animation pools, and room actors.

### 2.2 Explicit mode transition

Introduce a typed lifecycle boundary owned by the bootstrap/composition layer:

```text
Boot → Title/Menu → Hub → Run preparation → Active room → Settlement/Hub
```

Each transition owns construction and teardown. Avoid putting more conditional
branches into `GameplayState`; the boundary should load or release a focused
runtime context and preserve the existing frame controller contract.

### 2.3 Safe reuse

The goal is not to reload every texture on every menu click. Shared resources
may remain cached when their measured memory cost is acceptable, but live nodes,
per-room actors, image copies, and effect instances must have explicit owners
and teardown rules.

## Workstream 3 — Make menu and hub paths cheap

- Profile title and menu frame-schedule work independently from gameplay.
- Replace repeated prompt/text texture construction with stable cached assets
  keyed by label, device, and color.
- Avoid rebuilding menu layouts, cursors, and footer textures every frame.
- Keep touch hit-testing bounded to visible controls; do not scan unrelated
  gameplay nodes.
- Ensure hidden overlays are disconnected or inert rather than merely
  invisible if they retain expensive updates.
- Verify audio does not repeatedly decode, allocate, or switch tracks during
  menu idle.
- Measure title at native 240×160 and at the actual browser presentation size.

## Workstream 4 — Reduce runtime frame cost

### 4.1 Slime runtime first

The first active capture measured approximately 6.5 ms/frame in the slime
runtime scope. Split and measure it before changing behavior:

- roster iteration and active-slot filtering;
- movement/path/collision checks;
- attack state and contact checks;
- animation frame selection;
- target/aggro and notice updates;
- visual texture assignment.

Then apply the smallest measured fix, likely a combination of active-roster
iteration, cached collision inputs, reduced repeated `Callable`/Variant work,
and event-driven updates for inactive or off-screen slimes. Preserve attack
timing and collision contracts with characterization tests.

### 4.2 Occlusion and actor presentation

Occlusion is not the first desktop hotspot, but it remains a web/mobile risk
because per-pixel image work is CPU-sensitive. Keep the existing web scale
fallback and investigate only after capture evidence shows pressure. Prefer:

- no work for invisible/off-screen actors;
- stable cache keys and bounded image caches;
- invalidation on texture/occluder changes rather than every frame;
- actor-foot/depth decisions before exact pixel work;
- no duplicate image copies for equivalent textures.

### 4.3 Effects and projectiles

- Pool short-lived effect instances and damage numbers where profiling shows
  allocation churn.
- Bound particle counts and texture generation.
- Cache common text/number textures.
- Avoid creating effect resources for events outside the visible room.
- Measure burst scenarios separately from ordinary combat.

### 4.4 Allocation and call-boundary cleanup

In hot paths, prefer typed references and direct methods already required by
the architecture rules. Remove per-frame arrays/dictionaries/lambdas only when
the capture identifies them as material. Do not perform broad mechanical
rewrites or alter gameplay balance under this plan.

## Workstream 5 — Rendering, assets, and browser cost

- Keep Web on Compatibility/WebGL 2 and verify the actual browser export.
- Audit texture dimensions, import formats, filtering, and duplicate texture
  resources; pixel art does not justify duplicated full-size image caches.
- Measure video memory after title, hub, first room, and effect warmup.
- Keep draw-call and render-object counts in the capture report.
- Audit shaders for compatibility and overdraw; retain simple canvas-item
  materials where possible.
- Audit audio payload and decode behavior separately from frame time.
- Verify browser resize/fullscreen behavior does not silently multiply the
  render surface beyond the intended low-resolution viewport.

## Workstream 6 — Memory and thermal stability

- Establish a five-minute warm-session capture after title and after combat.
- Compare object count, node count, static memory, video memory, and cache
  sizes at start, after warmup, and at the end.
- Treat allocator high-water marks separately from live-object growth.
- Add explicit cache size/count reporting for occlusion, effects, palettes,
  animation frames, and projectiles.
- Reuse or clear mode-owned data when leaving a run.
- Investigate any monotonic live-object or video-memory growth before adding
  more content.

## Workstream 7 — Verification and release gates

### Desktop development gate

- deterministic capture scenarios complete;
- no new script diagnostics;
- focused owner smoke tests pass;
- desktop p95/p99 does not regress;
- no behavior or input contract changes;
- capture overhead is disabled in release builds.

### Browser gate

- fresh standalone Web export;
- Chrome/Samsung Internet and Safari smoke checks;
- title/menu scenario remains interactive;
- no repeatable title/menu hitch on the reference low-end device;
- first-run and warm-run captures recorded separately;
- browser console and memory behavior reviewed.

### Samsung A17 gate

The A17 is the acceptance device for this plan, not a final spot-check. Record
model, browser, OS, viewport, power/thermal state, build hash, and scenario
route with every capture. A release candidate cannot claim mobile readiness
from desktop numbers alone.

## Immediate sequence

1. Finish startup checkpoints and the deterministic title/menu capture route.
2. Capture cold title, title idle, save select, and hub before changing gameplay.
3. Remove or defer the largest pre-title allocations and verify title behavior.
4. Re-run title/menu captures and record the delta.
5. Split the slime scope into movement/collision/attack/visual subscopes.
6. Optimize the largest active-room category.
7. Add memory/cache deltas and five-minute warm-session verification.
8. Run the browser/A17 matrix and promote measured budgets into the release
   gate only after device evidence exists.

## Definition of peak efficiency

This plan is complete when:

- the title and every menu are responsive on the A17 browser;
- gameplay maintains the target without a frame cap masking work;
- startup does not construct gameplay-only content prematurely;
- no subsystem repeatedly creates unbounded per-frame or per-room data;
- memory and video memory stabilize after warmup;
- deterministic captures identify regressions without manual graph inspection;
- desktop, Web, and A17 evidence are stored with the same scenario names and
  comparable metrics.
