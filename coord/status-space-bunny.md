# space-bunny — status

_Only space-bunny writes this file._ Distinct from the `opencode` session that
holds the `tests/run_all_smoke.ps1` claim; the board carries separate rows so
concurrent opencode sessions do not clobber each other's notes.

**Focus:** Full composition plan (audit → `docs/composition-plan-2026.md`)
**Updated:** 2026-10-04

## 2026-10-04 — Stage 1 role map authored

Documentation only. Created `docs/script-role-map-2026.md` (535 lines) — the
proposed `scripts/` reorganization, ready for review before any move.

**All 235 tracked `scripts/*.gd` assigned to exactly one of eight folders:**

| Folder | Files |
|---|---:|
| runtime | 63 |
| content | 49 |
| algorithms | 27 |
| components | 26 |
| ui | 21 |
| editor | 19 |
| autoload | 16 |
| actors | 14 |

Validated: 0 duplicate assignments, 0 unassigned files, 0 names not on disk.
235 `.gd.uid` sidecars pair 1:1 with scripts, no orphans either direction.
Every file has an individual written reason, not a per-folder template.

**29 assignments are genuinely contestable** and grouped into six decision sets:
screen-vs-world space (5 files), pure algorithm vs service (6), authored data vs
mutable runtime state (6), editor tooling vs the layer it previews (8),
component vs actor entity (2), cross-cutting render service (3).

**Two findings that change the plan:**

1. **There are no game autoloads.** `project.godot` declares exactly one, and it
   belongs to the MCP toolkit addon. The 16 `autoload/` files are architectural
   globals created by `GameplayBootstrap` and stored on `GameplayState`. The
   folder should probably be `services/`. Raised as open question 1.
2. **Stage 0 of the composition plan is already implemented, uncommitted, by
   someone else.** `tools/validate_composition.ps1` and its baseline are
   modified in the working tree. The validator now reports reach-through,
   untyped-root-argument counts, context-twin counts, string call forms, a
   per-file top-seams table, and a forward-target table with stage and
   met/open status. It already recurses, so the migration will not blind it,
   and it already carries an `unclassified_scripts` target of 0 at stage 1 —
   exactly this task's acceptance bar. `-SelfTest` passes.

**Correction to my earlier reporting.** I told the owner the scorecard was
"saturated and blind". That was wrong: my first validator run was truncated to
the last 40 lines and I missed the new metrics. The validator is materially
more capable than I described, and most of Stage 0 is done. Logged to the
journal. I did not edit `composition-plan-2026.md` — that reconciliation is
outside this task's scope and the validator work is not mine.

## Blockers

The 29 unresolved assignments need owner decisions before the migration.
Nothing was moved, so nothing is at risk; the map is a proposal.

## Handoff / next

Owner review of `docs/script-role-map-2026.md`, then the single coordinated
migration. Separately, `composition-plan-2026.md` Stage 0 needs a
reconciliation pass against the validator that now exists.

## Current work

Stage 1 preparation. Documentation only; no runtime files touched.

Documentation only. No runtime, validator, or test file was touched.
Wrote `docs/composition-plan-2026.md` (688 lines) from an independent measured
audit, and registered it in `docs/DOCUMENTATION_MAP.md` (list item 16 + a
FAQ row).

**Measured findings that changed the plan's priorities:**

- `tools/validate_composition.ps1` passes both modes at 100% because every
  current value already sits *under* a target pinned to the legacy giants. It is
  a saturated regression floor and cannot see coupling, direction, or
  complexity. `GameplayState` fields are at 286/286 — zero headroom.
- **Three different coupling measures rank the files completely differently**,
  and the validator only tracks one:
  - dynamic dispatch (`root.get/set/call`) = 2,202 repo-wide
  - total reach-through (any `root.*`) = 4,434
  - **untyped `root:` parameters = 560 across 28 files (vs 91 typed)**
- The largest file is the *cleanest* per line on the validator's metric:
  `screen_state_controller.gd` is 4.6 dynamic seams/100 lines, the lowest of
  any large file. The densest are small files a size-sorted review never shows:
  `chest_controller.gd` 41.5, `actor_motor.gd` 31.5,
  `targeting_runtime_controller.gd` 31.1.
- Reach-through is only damning on an *untyped* root. `gameplay_frame_controller`
  has 455 reach sites but declares `root: GameplayState` in all 17 of its
  root-taking functions — those are correct static reads. The validator cannot
  tell the two apart.
- `magic_runtime_controller.gd` = 1,704 lines with **zero** dynamic seams via a
  typed `MagicRuntimeContext`. The working template is already in the tree.
- `gameplay_bootstrap.gd` is 44 hand-written `_add_runtime_node` calls, 31
  `root.call` dispatches, 34 `_phase()` labels, and a duplicated UI-build
  sequence. Not "assembled in the only configurable way."
- 18 documented composition rules have **no** automated check.
- `scripts/` is 235 files in one flat directory, zero subdirectories.

**Corrections made during authoring** (subagent figures verified, two wrong):
slime split boundary is **1201** (`collect_walkable_tiles`), not 1199; bootstrap
`_phase` count is **34**, not 33. Also discarded a mixed-metric density table I
had drafted and recomputed both measures consistently. Verified all 14
`room_controller.gd` `_context` twin pairs exist.

**Also authored (plan, not code):** reconciliation with luna's independent
audit of the same tree. Agreed with all six of her steps; the differences are
that Stage 0 (guardrail re-base) must precede decomposition, and that her
line-sorted priority list is the wrong axis.

## Blockers

Unchanged from the previous focus: the recorded session restriction on
launching a Godot process still applies, so nothing here is runtime-verified.
The plan's own §Prerequisites names three more: three red gate rows
(`hub_binding_smoke`, `equipment_menu_scene_smoke`, `imbue_spell_scene_smoke`),
`GameplayState` 286/286 field headroom, and defining the `_process()` check's
exemption list before writing it.

## Handoff / next

Owner review of `docs/composition-plan-2026.md`. Stage 0 (validator re-base and
new checks) is the proposed first code slice and should be a single claimed
block — it blocks every later stage, and Stage 1's path rewrite is
merge-conflict-heavy.

## Current work

Plan authoring only. No runtime code has been touched.

The feature has two halves that were originally one request:

1. Give the weapon imbue the elemental look it currently lacks — the fire/ice/
   electric/shadow particle styles that today only appear on status victims —
   plus a new bubble treatment for Water. The existing imbue outline and flash
   on the weapon sprite are correct and stay untouched.
2. A status/affinity system: a real fifth status (`wet`), enemies that carry an
   innate status derived from their element with presentation-only suppression,
   bidirectional element-agnostic contact transmission, and room generation
   constrained to synergistic elemental mixes.

Deliverable is `docs/elemental-affinity-and-transmission-plan.md`.

## Owner decisions (ratified 2026-10-03)

- One shared aura owner (`ElementAuraComponent`); no second aura implementation.
- Imbue element look emits from the **weapon** sprite silhouette, not the body.
  "the imbue wraps around the sprite of the WEAPON. always has, always should."
- Fire/Ice/Electric/Shadow reuse the existing `ember` / `frost_crystal` /
  `electric_spark` / `poison_mote` styles. Water gets bubbles. Grass, Ground and
  Normal get nothing for now and must fall back cleanly.
- `wet` is a real status with two halves: conducts electricity (damage and stun
  cadence) and extinguishes player-applied burn.
- Innate status never affects its own owner. Suppression is presentation-only
  **and** stops transmission.
- Transmission is bidirectional and element-agnostic: the debuff comes from
  whoever is carrying it. Bounded by a per-pair cooldown only.
- Enemy avoidance AI is deferred; the substitute is generation-side placement.

## Findings that corrected earlier assumptions

- **The bubble sounds are already wired.** `water_bubble_sent` /
  `water_bubble_burst` (`scripts/sound_clip_catalog.gd:28-29`,
  `scripts/sound_mix_profile.gd:124-125`, warm-loaded
  `scripts/sound_manager.gd:108`, played `scripts/magic_runtime_controller.gd:1110,1411`).
  They are not free for `wet` to claim.
- **A bubble visual already exists.** `_magic_bubble_texture`
  (`scripts/magic_runtime_controller.gd:1296`), `spawn_magic_bubble_pop` (`:803`),
  burst (`:828-831`), projectile wobble
  (`scripts/magic_projectile_controller.gd:136-143`), and
  `SpellFormDefinition.ProjectileShape.BUBBLE`. `wet` should reuse this visual
  idiom instead of authoring a new one.
- **Room enemy selection is not where I first looked.** The weighted pool is
  built in `scripts/room_controller.gd:194-295` with the single weighted pick in
  `scripts/encounter_definition.gd:66-75`; `room_enemy_spawn_services.gd` has no
  selection logic.
- **`element_catalog.gd:741-758` is about vault gate requirements**, not enemy
  element composition.
- **`strongest_active_definition()` breaks stack ties by Dictionary iteration
  order** (`scripts/status_component.gd:131-144`). Once innate and applied
  records coexist this becomes routine and the aura colour will flicker. Must be
  fixed rather than inherited.
- `scripts/gameplay_state.gd` is 1718 lines against a 1719 max and 286 fields
  against a 286 max. Zero headroom.

## Blockers / coordination

- **Overlap with codex.** Codex's active focus is "targeted status-aura alignment
  and Electric Shocked feedback" and it has been editing Ice/Water spell visuals
  in the spawner and magic runtime continuously through 2026-10-03. It has no
  `BOARD.md` row. The plan's presentation slices must not start until that pass
  lands or is coordinated; the plan documents this as a gate.
- `tests/run_all_smoke.ps1` is claimed by opencode and must not be edited.
- The live MCP editor holds the project directory, so
  `tools/validate_definitions.ps1` and `tools/report_catalogs.ps1` (which run
  `Godot --headless --import` against it) are deferred to a supervised standalone
  step.

## Handoff / next

1. Owner review of `docs/elemental-affinity-and-transmission-plan.md`.
2. On approval, claim the S1 path set and start with the mechanical
   `StatusRecord` conversion plus the two broken-test fixes
   (`tests/imbue_spell_scene_smoke.gd:191,203` removed-property assertions plus
   the missing `quit()` that makes it hang; `tests/status_component_smoke.gd:12`
   stale `&"slow"` id), then the stale `verified` label at
   `tests/manifest.csv:24`.
