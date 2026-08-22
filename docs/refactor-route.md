# Refactor Route — Typed, Feature-Oriented Consolidation

Status: accepted execution plan

Plan date: 2026-08-22

Branch: `refactor/2026-08-18`

Companion: [`AUDIT.md`](AUDIT.md) records the current baseline, findings, and
phase status. This document defines how the refactor is executed.

---

## 1. Outcome

Make Tiny Demons easy to find, change, test, and hand off without changing its
gameplay merely for architectural neatness.

The refactor succeeds when:

- a feature has an obvious owner;
- state is stored by that owner rather than mirrored through `gameplay_state.gd`;
- cross-system calls use typed references, narrow interfaces, or signals;
- the central frame schedule remains explicit and deterministic;
- designers change balance through typed tuning resources;
- a fresh clone contains every required shipping asset and boots successfully;
- each migrated subsystem has characterization and integration coverage; and
- new feature work no longer expands `gameplay.gd` by default.

Line count is diagnostic evidence, not the objective. Moving coupled code into a
different large file is not success.

---

## 2. Audiences

1. **Agents** need one map that identifies ownership, tests, and safe extension
   points without reading the entire coordinator.
2. **Coders** need jump-to-definition, rename safety, typed APIs, and explicit
   update order.
3. **Designers** need stable inspector-facing tuning resources and should not need
   to edit orchestration code for balance changes.

---

## 3. Current structural baseline

Measured 2026-08-22:

| Surface | Current observation |
| --- | --- |
| `gameplay.gd` | 2,926 physical lines, 413 functions, 304 one-line functions |
| `gameplay_state.gd` | 206 fields plus 50 constants; coordinator and state bag are fused by inheritance |
| `gameplay_frame_controller.gd` | 78 `root.call` and 75 `root.get` sites |
| `screen_state_controller.gd` | 1,225 lines; menu screens and hub/persistence UI share one owner |
| `player_equipment_visual_component.gd` | 801 lines; presentation, occlusion, and death concerns are mixed |
| Tests | 12 smoke scripts plus a short headless boot; visual-transform, audio, and coordinator glue coverage remain weak |

The most expensive architectural problems are:

1. feature behavior is partitioned across lifecycle phases rather than grouped by
   ownership;
2. `gameplay_state.gd` is a shared state bag written from many scripts;
3. `root.call/get/set` hides dependencies and makes renames fail at runtime;
4. hub/progression and Chroma/projectiles remain large coordinator-owned blocks;
5. input polling has multiple competing idioms; and
6. actor rendering, collision geometry, effect overlays, and encounter scaling
   calculate related transforms in different places.

The last item is not theoretical: recent boss hitbox and flash regressions repeatedly
produced the same enlarged, down-right displacement. Transform ownership is therefore
an early refactor slice, not deferred polish.

---

## 4. Architectural decisions

### 4.1 Refactor vertically by subsystem

Do not first convert every coordinator string call and then move every feature. That
would touch the same seams twice and create a large, hard-to-review intermediate
state.

Each subsystem follows the same migration protocol:

1. characterize current behavior with tests and a short manual checklist;
2. name the owner and list the state it owns;
3. introduce the smallest typed API needed by its consumers;
4. move state and behavior together;
5. wire the owner into the central schedule;
6. remove obsolete wrappers and string calls for that subsystem;
7. run automated checks and the subsystem playtest; and
8. checkpoint before beginning the next slice.

### 4.2 Keep one explicit frame schedule

Default to a central scheduler with named phases such as input, simulation, contact
resolution, presentation, and UI. Controllers expose typed `tick_*()` methods.

Controllers should not independently acquire `_process()` merely to avoid wiring.
Autonomous processing is acceptable only when ordering is genuinely irrelevant and
the reason is documented.

### 4.3 Prefer direct typed calls and signals

Use:

- direct methods on typed component/controller references for commands and queries;
- signals for domain events consumed by presentation, audio, or other observers;
- narrow context objects only for state that is truly shared; and
- `Callable` injection for small algorithmic boundaries, as used successfully by
  `occlusion_renderer.gd`.

`Callable(root, "_method")` remains stringly typed and is not a rename-safe target
architecture. Callable injection is a tool, not the universal seam.

### 4.4 Separate domain logic from screens

Progression, grading, settlement, XP, and rewards are game-domain logic. Hub screens
may invoke and present those systems but do not own them.

The intended boundary is:

- `progression_controller.gd`: XP, level growth, grading inputs, and progression
  decisions;
- `run_settlement.gd` or a thin settlement controller: run outcome and reward
  application; and
- `hub_controller.gd`: hub workflow, shop/fusion/salvage/stat-allocation UI
  coordination.

### 4.5 Route input by context

Introduce an `InputRouter` or equivalent typed input service with explicit gameplay,
dialogue, hub, and menu contexts. `PlayerController` consumes gameplay actions; it
does not become the owner of title or menu input.

### 4.6 One transform source for actor geometry

Create a typed actor/slime geometry owner that can answer:

- foot position;
- rendered sprite bounds;
- world-space body polygon;
- encounter scale and visual offset;
- contact radius and directional body reach; and
- the transform used by hit flashes and related overlays.

Melee, projectiles, enemy attacks, targeting, flashes, and debug visualization must
consume this same source. No consumer should independently reconstruct the scaled
sprite offset.

### 4.7 Keep sound triggers near gameplay meaning

`SoundManager` owns loading, channels, playback, and policy. Gameplay systems may
request sounds directly through a typed service or emit domain signals. Scattered
sound triggers are not themselves a defect when they sit beside the action that
gives them meaning.

---

## 5. Execution plan

### Phase A0 — Safety and characterization

Purpose: establish a recoverable, reproducible baseline before structural edits.

1. Checkpoint all working gameplay and required assets.
2. Verify that a fresh clone contains everything needed to boot. Committed code must
   not depend on untracked `assets/baked/`, shaders, or audio.
3. Expand `.gitignore` for editor state, virtual environments, package caches,
   generated analysis, and superseded output directories.
4. Inventory generated assets. For mobile shipping, prefer committed deterministic
   baked outputs accompanied by their generator, source inputs, and manifest. A
   runtime recolor path may remain a fallback.
5. Quarantine reference-derived audio from shipping paths. Compare hashes and record
   provenance; equal file size is not evidence of identity. Replace anything without
   defensible ownership before release.
6. Record the complete smoke baseline and a short frame-time sample.
7. Add characterization coverage before extraction for:
   - boss body polygon versus rendered sprite bounds;
   - hit-flash overlay versus actor render transform;
   - Chroma pickup, attunement, cast, projectile, and Gray behavior;
   - room milestone ordering; and
   - `SoundManager.play()` with a known test stream.

**Exit gate:** the tree is recoverable, a fresh clone boots, required assets are
tracked, and the baseline tests are recorded.

### Phase A1 — Navigation and ownership map

Purpose: prevent new work from reinforcing the old boundaries.

1. Add root `AGENTS.md` with canonical reading order, verification commands,
   ownership rules, and a “where does feature X go?” table.
2. Refresh `README.md`, `AUDIT.md`, `ARCHITECTURE.md`, and
   `GAMEPLAY_TUNING.md` so they agree on the branch, current feature focus, and
   extension rules.
3. Consolidate Chroma documentation into one design document and one implementation
   plan.
4. Move SFX research documents beneath `docs/sfx/` and separate reference material
   from shipping assets.
5. Fix broken filename/link normalization and prune superseded generated reports.

**Exit gate:** a new contributor can identify the owner and test surface for a
feature from the documentation map without opening `gameplay.gd`.

### Slice B1 — Actor geometry and combat presentation

Purpose: stabilize the transform boundary before further combat work.

1. Add the geometry owner described in §4.6.
2. Move slime body polygon conversion, body reach, contact radius, and rendered-bound
   calculations into it.
3. Make melee, projectiles, enemy attack contact, targeting, and slime separation use
   that API.
4. Move hit-flash overlay positioning to the same transform source.
5. Add an opt-in debug draw for rendered bounds, foot, and combat polygon.
6. Add tests for normal and boss-scale actors, including nonuniform animation scale.

**Exit gate:** normal and boss hitboxes coincide with their rendered bodies; effects
remain aligned during movement and squash/stretch; no geometry consumer duplicates
the offset formula.

### Slice B2 — Contextual input

Purpose: make action ownership and screen transitions searchable.

1. Introduce typed input snapshots and explicit input contexts.
2. Route gameplay input to `PlayerController` and UI input to the active screen/hub
   controller.
3. Preserve controller-axis behavior and edge detection in one polling layer.
4. Remove direct action polling from migrated UI and HUD code.
5. Add context-transition tests so one press cannot leak between gameplay, dialogue,
   pause, and hub screens.

**Exit gate:** each action is polled in one place and routed to one active context.

### Slice B3 — Elemental Chroma and projectiles

Purpose: give the game’s core identity a durable owner before expanding it.

1. Expand `PlayerChromaComponent` to own Chroma amount, aspect state, consumption,
   attunement, Gray transitions, and cast eligibility.
2. Add `MagicProjectileController` for projectile lifecycle, targeting, impact, and
   ENTRY ORB interaction.
3. Move trails and impacts into `EffectsSpawner` behind typed requests.
4. Give Chroma pickups a focused owner rather than coordinator-held arrays/timers.
5. Emit typed events for palette/aspect changes so player visuals, HUD, audio, and
   puzzles react without reading private Chroma state.
6. Remove migrated Chroma fields, wrappers, and `root.call/get/set` sites.

**Exit gate:** a Chroma feature changes its component/controller and tests; the
coordinator only schedules or routes high-level events.

### Slice B4 — Progression, settlement, and hub

Purpose: separate durable game rules from hub presentation.

1. Extract progression and settlement behavior behind typed domain APIs.
2. Extract hub workflow and persistence-facing UI from
   `screen_state_controller.gd` and `gameplay.gd`.
3. Keep profile serialization in `PlayerProfile` and file operations in
   `ProfileSaveService`.
4. Route shop, fusion, salvage, stat allocation, and run settlement through explicit
   commands/results rather than coordinator state mutation.
5. Add tests for settlement idempotence, reward application, and hub screen flows.

**Exit gate:** progression can be tested without constructing hub UI, and hub UI does
not implement progression formulas.

Status: complete on 2026-08-22. `ProgressionController` and the settlement guard
are the domain seams; hub pending edits use `HubProgressionDraft`.

### Slice B5 — Combat, rooms, and frame seams

Purpose: remove remaining broad string dispatch without destabilizing update order.

1. Migrate combat and room scheduling one phase at a time from
   `GameplayFrameController` into typed controller references.
2. Make update order explicit in code and documentation.
3. Replace coordinator callbacks with typed APIs or narrow algorithm injection.
4. Delete forwarding functions only after their final consumer has migrated.
5. Add ordering assertions for input, simulation, contact resolution, damage,
   presentation, and transitions.

**Exit gate:** renaming a migrated API causes a parse/type error; no migrated frame
phase depends on `root.call/get/set`.

Status: complete on 2026-08-22 for the schedule seam. `PHASE_ORDER` names the
central runtime order and characterization asserts it without distributing `_process()`.

### Slice B6 — Presentation delegates and shared state

Purpose: finish ownership consolidation without creating replacement god objects.

1. Split menu screens from hub/persistence UI.
2. Split equipment presentation from occlusion/death orchestration.
3. Move remaining single-owner fields out of `gameplay_state.gd` as each owner is
   established.
4. Introduce narrow run/room context objects only where multiple owners genuinely
   require the same state.
5. Remove dead signals, delegates, caches, and compatibility paths proven unused.

**Exit gate:** scripts have coherent responsibilities, cross-owner state mutation is
absent, and the shared state surface contains only documented shared values.

Status: complete on 2026-08-22 for the bounded shared-state slice. Hub draft state
has a typed owner; larger presentation delegates remain a Phase C follow-up when
they can be split without duplicating UI ownership.

### Phase C — Closeout

1. Run the complete automated suite and all subsystem playtest checklists.
2. Measure frame time against the Phase A0 baseline.
3. Verify a fresh clone/import/boot on the supported Godot version.
4. Re-run structural metrics and record the delta in `AUDIT.md`.
5. Resolve or explicitly schedule every remaining asset, documentation, and legal
   finding.

**Exit gate:** the success definition in §1 is met without gameplay or frame-time
regression.

---

## 6. Per-slice quality gate

Every slice must include:

- an ownership/state table;
- tests that characterize behavior before movement;
- typed APIs for new seams;
- removal of the old seam within that slice;
- full smoke-suite result;
- focused manual playtest notes;
- a recoverable checkpoint; and
- an update to `AUDIT.md` phase status and metrics.

Do not begin the next slice with a known parser error, broken fresh-clone dependency,
or unexplained gameplay regression.

---

## 7. Metrics

Track trends after every slice:

- `gameplay.gd` physical lines and function count;
- `gameplay_state.gd` field count, grouped by owner;
- `root.call/get/set` count per migrated subsystem;
- largest script size, with responsibility notes;
- automated tests passed/failed;
- focused manual checklist result;
- average and worst observed frame time; and
- untracked files required by runtime resources.

Targets such as a 1,200–1,500-line coordinator or sub-500-line components are useful
warning thresholds, not acceptance criteria. A cohesive file may exceed them; an
incoherent 300-line file still fails the ownership goal.

---

## 8. Explicit non-goals

- Redesigning combat balance during structural migration.
- Rewriting working systems solely to use a fashionable pattern.
- Distributing `_process()` across controllers to hide orchestration.
- Building a generic event bus or service locator.
- Replacing typed ownership with another global state object.
- Preserving obsolete save migration when the project has explicitly chosen not to
  support those saves.

Any intentional behavior change discovered during a slice is documented and landed
separately from the structural move whenever practical.
