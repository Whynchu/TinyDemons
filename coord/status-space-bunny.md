# space-bunny — status

_Only space-bunny writes this file._ Distinct from the `opencode` session that
holds the `tests/run_all_smoke.ps1` claim; the board carries separate rows so
concurrent opencode sessions do not clobber each other's notes.

**Focus:** Design and document the elemental affinity / transmission feature
**Updated:** 2026-10-03

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
