# Tiny Demons — Codebase Audit

Status: current

Audit date: 2026-08-18

Branch: `agent/script-consolidation`

> This is the living current-state / desired-state document for the codebase.
> Feature-level docs (gear balance, rogue slime, speed stat) live beside their
> implementation; this file records where the codebase *is*, where it should
> *end up*, and the plan to close that gap.

## Verification commands

Every change should be checked headless before commit:

```powershell
# Main scene boots (30 frames, no errors)
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Development\Tiny-Demons\TinyDemons" --quit-after 30

# Full smoke suite (7 tests + main scene)
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
```

All 7 smoke tests (`run_grade`, `progression`, `item_economy`,
`rogue_slime`, `speed_scale`, `fusion_tooltip`, `palette`) plus the headless
main-scene check pass at the current working tree.

---

## 1. Current state

### 1.1 Repo layout

The workspace root is `C:\Development\Tiny-Demons\` and is **not** a git repo:

```text
C:\Development\Tiny-Demons\                 <- workspace root (NOT git)
├── Godot_v4.7.1-stable_win64.exe\          <- a FOLDER holding the real binaries
│   ├── Godot_v4.7.1-stable_win64.exe
│   └── Godot_v4.7.1-stable_win64_console.exe
├── Screenshot 2026-08-09 230211.png        <- loose file
├── previous session.txt
└── TinyDemons\                             <- git repo root == Godot project root
    ├── project.godot                       <- open this in Godot
    ├── assets\  scenes\  scripts\  shaders\  tests\    <- the Godot project
    ├── Artwork\  Mockups\  screenshots\  docs\          <- .gdignore'd (not imported)
    └── (Artwork also copied into assets\artwork\ as project sprites)
```

Flattened 2026-08-18: `project.godot` sits at the git root. `Artwork/`,
`Mockups/`, `screenshots/`, and `docs/` carry `.gdignore` markers so Godot
does not import the loose source art or README images. Friction points that
remain (all workspace-level, not repo-level):

- Artwork exists both as source (`Artwork/`) and as project copies
  (`assets/artwork/`); 3 files have drifted and 7 project sprites have no
  source export (see §3.4).
- The Godot executable folder is named like a `.exe`, which confused earlier
  audits into reporting Godot as "undiscoverable".

### 1.2 Script inventory (59 scripts, ~11,800 lines)

Largest scripts by line count (2026-08-18):

| Script | Lines | Role |
| --- | ---: | --- |
| `gameplay.gd` | 2,051 | Phase coordinator, still owns hub/progression/combat flow |
| `screen_state_controller.gd` | 1,132 | Screens: title, hub, archetype, game-over, fusion UI |
| `player_equipment_visual_component.gd` | 757 | Player layered visuals, palette, occlusion, death |
| `room_controller.gd` | 512 | Room/dungeon graph, geometry, sockets, states |
| `hud_controller.gd` | 408 | Health bars, target, overhead bars, aggro markers |
| `effects_spawner.gd` | 386 | Damage numbers, particles, dust, floating text |
| `player_profile.gd` | 382 | Save schema v6, items, stats, fusion, salvage |
| `gameplay_state.gd` | 371 | Shared state blob + constants (291 vars, 1 @export) |
| `occlusion_renderer.gd` | 331 | Occlusion cache/images, actor visuals |
| `npc_controller.gd` | 314 | Cloaked demon frames, patrol, dialogue |

Remaining 49 scripts average ~105 lines. A full script-by-script role map is
in the Appendix below.

### 1.3 `gameplay.gd` measurement (grown again)

| Metric | Baseline (5,419) | Prior audit (1,973) | Now |
| --- | ---: | ---: | ---: |
| Physical lines | 5,419 | 1,973 | **2,051** |
| Functions | 291 | 345 | **352** |
| Constants | 113 | 1 | 1 |
| Root `@export` | - | 0 | 0 |
| `@onready` refs | 22 | 0 | 0 |

The coordinator **grew ~80 lines / ~7 functions** since the last audit. Most
new lines are feature wiring added by the uncommitted WIP (fusion UI, speed
stat, rogue-slime integration, hub additions), but the trend matters: the
"reduce coordinator" effort (M9) and the "add features" effort (combat
overhaul, ambush, speed) are in direct tension. New feature work tends to land
in `gameplay.gd` because it is the path of least resistance.

Current role split inside `gameplay.gd`:

- **Progression/hub flow** (~35%): hub UI, fusion, salvage, stat allocation,
  run settlement, save/load, title/archetype/game-over screens.
- **Combat orchestration** (~30%): attacks, damage, slime variants/ambush,
  health, XP/level, floating numbers.
- **World/room flow** (~25%): sockets, geometry, transitions, NPC/chest/rest
  fire, large-room camera, occlusion orchestration.
- **Movement/collision** (~10%): sweep, contacts, walkability, slime scoot.

The rest of the codebase holds the actual implementations behind clean
component APIs; `gameplay.gd` mostly *delegates* through one-line wrappers,
which is the intended M7-M9 shape. The two regressions to watch are
`screen_state_controller.gd` (1,132 lines) and
`player_equipment_visual_component.gd` (757 lines), which absorbed the work
that left `gameplay.gd` — a classic "coordinator shrank, its delegates grew"
move. The cleanup effort is now finding its next home.

### 1.4 Stability & tests

- **Green:** all 7 smoke tests + headless main-scene run pass
  (`tests/run_all_smoke.ps1`).
- **Safety net works:** the earlier stale-test bugs (`damage_bonus`,
  `gear_health`) were fixed; a watchdog prevents hangs.
- **Fusion tooltip regression:** `fusion_tooltip_smoke.gd` guards the
  GEAR→FUSE / SHOP→FUSE transitions so a stale page's detail text cannot leak
  into the FUSE menu (fix committed `e7ba379`).
- **Palette regression:** `palette_smoke.gd` asserts every consumer
  (sprite recolor, slime mapping, archetype highlights) matches the canonical
  table in `scripts/palette_library.gd` (single source, commit pending).
- **Schema:** save schema is now v6 (`player_profile.gd`), with default
  migration for older fields (`data.get(...)` fallbacks).
- **Editor cache:** new classes (`SlimeAmbushComponent`) require a project
  reload in the editor before they resolve.

### 1.5 Editor-exposed tuning

Five typed tuning resources are fully `@export`-driven, so every value appears
in the Godot inspector:

| Resource | Fields | Covers |
| --- | ---: | --- |
| `player_tuning.gd` | 36 | Speed, frames, rolls, attacks, regen, death |
| `slime_tuning.gd` | 41 | Aggro, steering, attack, regen, ambush, boss multipliers |
| `combat_tuning.gd` | 11 | Health/damage formulas, crit, defense scale |
| `effects_tuning.gd` | 9 | Particles, damage numbers, resolution |
| `progression_tuning.gd` | 5 | XP curve, level-up point bands |

`gameplay_state.gd` exposes one `@export` debug flag
(`debug_start_in_boss_room`). Scene-level stats (slime archetypes) are
configured on each `StatsComponent` node in `main.tscn`.

Missing hooks: the many magic numbers still in `gameplay.gd`/`gameplay_state.gd`
(chest distances, collision sizes, frame constants, dialogue timings) are not
exported; the tuning index doc (below) lists where each knob lives today.

---

## 2. Desired state

### 2.1 Coordinator stays small while features keep landing

Targets (from `script-consolidation-plan.md` M9/M10, re-affirmed):

- `gameplay.gd` settles in the **1,200-1,500 line** band (it will never be a
  300-line pure orchestrator while hub/settlement flow lives there) and stops
  *growing*: new feature wiring must land in a component or controller.
- `screen_state_controller.gd` splits along its two real boundaries:
  **hub/persistence UI** (stats, gear, fusion, salvage) vs **menu screens**
  (title, archetype, loading, game-over). Each target under ~700 lines.
- `player_equipment_visual_component.gd` splits presentation (palette, layers,
  frames) from occlusion/death orchestration. Target under ~500 lines.
- New tunables are added to the typed tuning resources, **not** as constants.

### 2.2 Docs become one coherent tree

Desired layout:

```text
docs/                          <- ONE docs folder at git root
├── AUDIT.md                   <- this file
├── ARCHITECTURE.md             <- component map + extension guide
├── GAMEPLAY_TUNING.md         <- every tuning knob and where to change it
├── script-consolidation-plan.md
├── gameplay-smoke-checklist.md
└── combat-economy-overhaul.md
```

Feature design docs (meta progression, dialogue shop, rogue slime, speed
stat) are consolidated here at `docs/` alongside the audit/plan/checklist
docs — one entry point for the whole repo. No new feature design doc should
be created outside `docs/`.

### 2.3 Workflow friction removed

- **Tests are the gate.** `tests/run_all_smoke.ps1` is the canonical
  pre-commit check; documented in README so agents and humans run it
  identically.
- **Editor reload note** added to feature docs (class cache) so playtesters
  do not hit stale-script errors.
- **Repo root is flattened** (project.godot at git root) — done 2026-08-18;
  loose art folders carry `.gdignore` markers so Godot does not import them.

---

## 3. Findings

### 3.1 Stability

- Green tests, no red at HEAD anymore.
- WIP is large (34 modified files, +1,058/-293) and uncommitted: gear
  overhaul, fusion redesign, rogue slime, speed stat. It boots and passes
  smoke, but no checkpoint exists yet — a bad middle state is one merge away.
- `profile_save_service.gd` and `player_profile.gd` both persist; confirm the
  split is intentional (service vs model) — potential duplication.

### 3.2 Performance

Static analysis (three systems per frame) found these hotspots; the game is
not CPU-bound at 240x160, but the first three are real per-frame GPU-upload /
allocation churn:

| # | Location | What happens per frame | Severity |
| --- | --- | --- | --- |
| 1 | `player_equipment_visual_component.gd:133-161` | Equipment occlusion rebuilds a fresh 72x72 `Image` + `ImageTexture` (GPU upload) every frame when gear overlaps an occluder; the signature cache (`_occlusion_signature` :177) and `occlusion_mask_refresh_timer` (:111) exist but never gate it | **high** |
| 2 | `slime_brain.gd:27-39` via `slime_actor.gd:76` | Every aggroed slime re-scans all buddies (O(n) node lookups + `get_meta` + sqrt each) every frame -> O(n²)/frame, plus a walkability query | **high** |
| 3 | `hud_controller.gd:42` + `effects_spawner.gd:159-179` | Target name texture rebuilt from scratch each frame (and twice — also `interaction_component.gd:37`), though the name rarely changes | **high** |
| 4 | `actor_collision_system.gd:34-54` + `gameplay.gd:1407-1408` | `resolve_slime_contacts` O(n²) pairs, each re-resolving `CollisionGuide` + `get_meta`; overlap runs up to 4 full polygon walkability validations | med |
| 5 | `gameplay.gd:1817-1825` + `walkable_area.gd:110-113,170-181` | Each moving slime re-validates standability per axis (~11 `is_slime_walkable` samples, each O(outline edges)) | med |
| 6 | `gameplay.gd:1632-1633` etc. | `_enemy_max_health` recomputed ~3x/slime/frame; each allocates a new `CombatStatSnapshot` | med |
| 7 | `gameplay.gd:1419-1439` | `_prepare_slime_frame_cache` re-resolves component refs by string name each frame | med |
| 8 | `walkable_area.gd:141-153,156-167` | Nearest/random walkable-point scans all points; random variant makes 24 sample calls per repath | med |
| 9 | `occlusion_renderer.gd:302-331` | Player/target per-pixel occlusion re-allocates a 72x72 image + `texture.set_image` GPU upload per frame while occluded | med |

Top 3 to fix first: gate equipment occlusion rebuild on the signature and
reuse one `ImageTexture` (#1); recompute aggro target at repath cadence
instead of every frame (#2); cache the target-name texture by (text, color)
like the existing `number_texture` cache (#3).

No measured frame-time regression in smoke; the manual `M0` checklist
(in `script-consolidation-plan.md`) includes a no-regression item that has
not been run recently.

### 3.3 Duplication / oddities

Near-duplicate functions (verified):

- `_equip_profile_item` / `_unequip_profile_slot` (`gameplay.gd:31-46`, `48-63`)
  — byte-identical except the one profile call (11 copied lines).
- `_build_player_sprite_shadow` / `_build_cloaked_demon_sprite_shadow`
  (`gameplay.gd:1949-1950`) — identical 1-liners.
- `_pixel_text_texture` / `_pixel_number_texture` (`gameplay.gd:1744,1746`)
  — byte-identical.
- `shadow_controller.gd:20-28` vs `:31-38` — duplicate shadow-sync bodies.
- 7 health/XP-number spawner wrappers (`gameplay.gd:1634-1742`) differing only
  in origin/color; slime numbers float up while player numbers float **down**
  (sign bug, same knob).
- Two rarity ladders that will drift: `item_catalog.gd:_roll_rarity` vs
  `gameplay.gd:_roll_run_loot_rarity` — same structure, different constants.
- `player_profile.gd:143` `fusion_cost()` is dead and its formula is
  re-implemented inline in `fusion_batch_cost` (:149-162).
- Palette data was triplicated with **divergent values** across 6 files
  (shadow/normal/accent listed inline in `sprite_frame_library.gd`,
  `player_equipment_visual_component.gd`, `hud_controller.gd`,
  `gameplay.gd`, `screen_state_controller.gd`, `slime_visual_component.gd`).
  **Resolved:** single-sourced into `scripts/palette_library.gd`; consumers
  now call `PaletteLibrary.shadow/normal/accent/pair/triple`. The one real
  divergence found was the slime purple accent (`200,184,210`) vs the
  archetype-highlight purple (`118,78,142`); both are preserved as separate
  roles (`ACCENT` vs `ARCHETYPE_HIGHLIGHTS`) so visuals are unchanged.

Duplicated state mirrors (coordinator holds a copy of component state):

- `player_health` (`gameplay_state.gd:156`) vs `HealthComponent.current_health`
  — 6+ write sites; a change must remember to update both or they drift.
- `gold` / `player_level` / `player_xp` (`gameplay_state.gd:157-158,286`) vs
  `PlayerProfile` — 6 write sites for `gold` alone.
- `current_target` vs `HudController.current_target`; `player_attack_hit_targets`
  vs `PlayerAttackComponent.hit_targets` (written in both places).
- `player_anim_*` mirrors (`gameplay_state.gd:120-122`) — the component fields
  are written from the root every frame and never read (dead mirror).

Dead / nearly-dead code (verified by call-count across all 59 scripts):

- `gameplay.gd`: `_allocate_player_stat` (:209), `_style_archetype_button`
  (:697), `_apply_saved_player_palette` (:929), `_restart_game` (:941 — the
  game-over button actually wires to `_return_to_hub`), `_is_enemy_control_locked`
  (:1833).
- Unused consts in `gameplay_state.gd`: `PLAYER_FRAME_SIZE`, `ROLL_DUST_FRAME_SIZE`,
  `INTERACT_PROMPT_BOB_TIME`, `NPC_DIALOGUE_TIME`, `ACTOR_CONTACT_RADIUS`,
  `SLIME_WEIGHT`, `PLAYER_WEIGHT`.
- ~25 delegate funcs (e.g. `chest_controller.claim_reward`,
  `effects_spawner.request_effect`, `npc_controller.request_dialogue`,
  `rest_fire_controller.request_rest` + dead `rest_requested` signal,
  `shadow_controller.register_shadow` + whole `shadow_sprites` member,
  `screen_state_controller._item_comparison_text`, `slime_visual_component.recolor_attack_frames`).
- `PlayerAnimationComponent`: `animation_changed` signal, `play()`, `reset()`
  never connected/called — the animation state machine runs off root fields.
- Unused `@export`: `enemy_tactics_component.gd:6` `attack_priority`.
- `player_profile.gd` (382) and `profile_save_service.gd` (120) overlap on
  persistence responsibilities.
- `gameplay_state.gd` is a 291-var shared blob; most of it is single-owner
  state that has a better home (hub UI refs → `screen_state_controller`,
  player runtime mirrors → player components).

### 3.4 Scenes, shaders & project config

- **Input map added (resolved).** `project.godot` now has an `[input]` section
  covering every previous hardcoded bind (move, attack, roll, target, guard,
  interact, cancel, pause) plus controller shoulder/trigger fallbacks; the
  README Controls section matches the real bindings. Remappable in-editor.
- **Actors are hand-authored inline** in `main.tscn` — zero instanced slimes.
  `scenes/slime.tscn` is a dead legacy template nothing instantiates; the plan
  claims a reusable slime scene exists (`script-consolidation-plan.md:349`).
- Slime archetypes in `main.tscn`: blue=FAVOR_DEF(3), green=FAVOR_VIT(1),
  red=FAVOR_STR(2); identical collision/attack-guide values duplicated ×3.
- **Shaders (resolved):** `target_outline.gdshader` and the orphaned
  `occluded_dither.gdshader.uid` were unreferenced and are deleted. The real
  occlusion shader is an inline string in
  `player_equipment_visual_component.gd`.
- `project.godot`: `3d/physics_engine="Jolt Physics"` is cargo-cult (2D game);
  `[dotnet] assembly_name` is vestigial (no C#). Harmless.
- **.gitignore too thin**: misses `.godot-user/` (already accumulating at the
  git root), Web/export artifacts (`*.pck`, `web/`, `*.zip`), platform junk.
- **Artwork duplication:** 74 shared filenames across `Artwork/` and
  `assets/artwork/`, 71 byte-identical; 3 have drifted; 7 project sprites have
  no source export. Every art edit risks two-tree churn.

### 3.5 Workflow friction

- One logical change touches 2+ files every time: adding a screen state
  touches 5 files (`gameplay_state` + `gameplay` + `gameplay_frame_controller`
  + `screen_state_controller` + `gameplay_bootstrap`); changing a palette now
  touches 1 file (`scripts/palette_library.gd`).
- `gameplay.gd` has 133 one-line functions (38%), 97 semicolon-chained lines,
  and only 49 blank lines across 2,051 lines — merge/agent diff friction.
- Three different "just-pressed" input idioms coexist (attack/roll state vars,
  pause local, interact member). Partially resolved by the `[input]` map; the
  remaining state-var idioms are a P1/P3-style cleanup.
- Test runner is documented in the README; nothing runs the smoke tests from
  the editor workflow.
- Godot binary folder name ("..._win64.exe\") caused the earlier
  "undiscoverable" misreport; worth a README note or rename (workspace-level).
- No CI; the runner is manual (`pwsh -File ...`). Fine for now.

---

## 4. Proposed refactor plan (priority order)

### P0 — Commit the WIP checkpoint (do first, unchanged behavior) ✅ DONE

Committed as `af3e1d2` ("Feature overhaul: gear value, fusion redesign, rogue
slime, speed stat + repo audit") on 2026-08-18. The repo now has a clean
checkpoint before refactor work.

### P0.5 — Flatten the repo ✅ DONE

Flattened 2026-08-18: `project.godot` moved to the git root; feature design
docs consolidated into `docs/`; `Artwork/`, `Mockups/`, `screenshots/`,
`docs/` carry `.gdignore` markers; `.gitignore` expanded
(`.godot-user/`, export artifacts, platform junk). Path references in the
README, test runner, and this doc updated.

### P1 — Delegate-new-feature gate (stop the coordinator growth)

- Document (in `script-consolidation-plan.md` M9) that new feature wiring goes
  in a component or controller; `gameplay.gd` only gains orchestrator calls.
- Move hub/settlement flow out of `gameplay.gd` into a
  `hub_controller`/`progression_controller` slice — this is the single largest
  region and the one that keeps growing (fusion, stats, salvage).

### P2 — Performance quick wins ✅ DONE

- Gate equipment-occlusion rebuild on `_occlusion_signature`; reuse one
  `ImageTexture` (`player_equipment_visual_component.gd`) — per-layer texture
  cache keyed by signature, invalidated on palette/death. Commit `3b5810e`.
- Recompute aggro target at repath cadence, not every frame (`slime_brain.gd`,
  `slime_actor.gd` tickers).
- Cache target-name texture by (text, color) like `number_texture`
  (`effects_spawner.gd:name_texture`).
- Share `_enemy_max_health` via the existing frame cache
  (`gameplay.gd:1632-1633`) — **deferred**: low impact, requires live-combat
  playtest to verify safely.

### P3 — Deduplicate, dead-code, and tidy ✅ DONE (playtest-gated items deferred)

- Merge `_equip_profile_item`/`_unequip_profile_slot`; delete the byte-identical
  `_pixel_text_texture`/`_pixel_number_texture`, the shadow builder/updater
  pairs, and collapse the 7 health-number wrappers. Commit `3b5810e`.
- Delete the verified dead code: 5 `gameplay.gd` funcs, 7 unused consts, ~25
  delegate funcs, the dead `PlayerAnimationComponent` API, the unused
  `attack_priority` export, dead `fusion_cost`, dead `MP_HIGHLIGHT` const.
  Commit `3b5810e` (23 files, net −185 lines).
- **Deferred (needs playtest)**: unify the two rarity ladders; make the
  coordinator read-only for `player_health`, `gold/level/xp`,
  `current_target`, `player_attack_hit_targets` (13 write sites across
  death/heal/equip/level flows — no smoke coverage); reconcile
  `player_profile` vs `profile_save_service` persistence split; thin
  `gameplay_state.gd` single-owner state. Each changes behavior that headless
  smoke can't validate.
- **Single-sourced the palette data (done, commit pending)**: canonical table
  moved to `scripts/palette_library.gd`; all 6 divergent consumer sites now
  call it. Guarded by `palette_smoke.gd`.

### P4 — Scenes, config, and tooling closeout ✅ DONE

- Added a real `[input]` map (`project.godot`) with every previous bind;
  migrated `player_controller.gd` + coordinator input helpers to named actions
  (remappable in-editor, DPAD/stick/trigger fallbacks preserved). README
  Controls section updated to the actual bindings.
- Deleted the dead `scenes/slime.tscn` template and the unreferenced
  `occluded_dither.gdshader.uid` / `target_outline.gdshader[.uid]`.
- Stripped `Jolt`/`[dotnet]` from project.godot (no C# or 3D physics).
- `.gitignore` expanded in the flatten commit (`dba8b4c`).
- Wrote `docs/ARCHITECTURE.md` (component map + extension guide, M10 item).
- README: test runner + input reality documented (Godot binary folder note
  remains a workspace-level item).
- **Deferred**: `Artwork/` vs `assets/artwork/` duplication reconciliation
  (3 drifted, 7 orphaned sprites) — needs a human decision on single-source
  vs. documented sync step.

---

## Appendix — scripts by responsibility

- **Player**: `player_controller`, `actor_motor`, `player_roll_component`,
  `player_attack_component`, `player_guard_component`,
  `player_animation_component`, `player_equipment_visual_component`,
  `player_hud`.
- **Enemies**: `slime_actor`, `slime_brain`, `slime_combat_component`,
  `slime_animation_component`, `slime_visual_component`,
  `slime_health_presenter`, `slime_ambush_component`,
  `enemy_tactics_component`.
- **World**: `room_controller`, `dungeon_graph`, `dungeon_socket`,
  `isometric_room_layer`, `walkable_area`, `actor_collision_system`,
  `depth_sorter`, `shadow_controller`, `occlusion_renderer`.
- **Interaction**: `interaction_component`, `chest_controller`,
  `npc_controller`, `rest_fire_controller`, `attack_hitbox_guide`.
- **Meta/progression**: `player_profile`, `profile_save_service`,
  `run_state`, `run_grade`, `run_settlement`, `item_catalog`,
  `item_instance`, `equipment_component`, `equipment_transmutation_component`,
  `stats_component`, `combat_stat_snapshot`, `combat_calculator`.
- **Presentation**: `hud_controller`, `effects_spawner`,
  `screen_state_controller`, `sprite_frame_library`.
- **Infra**: `gameplay` (coordinator), `gameplay_state` (state),
  `gameplay_bootstrap`, `gameplay_frame_controller`,
  `editor_collision_guide`, `editor_polygon_guide`, `ui_layout_guide`.
