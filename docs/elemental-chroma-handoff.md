# Tiny Demons — Elemental Chroma System Handoff

Status: active decision log; Binding/Fusion core implemented

Source design: `docs/Tiny Demons — Elemental Chroma System Design.md`

Binding and flame-fusion authority: [`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md)

Implementation route: [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md)

This document records the decisions made so far, the current integration
surface in the Godot project, and the remaining questions for future
class/package and content work.

## 1. Agreed identity

Tiny Demons naturally begins in a Gray / unaspected state. Elemental color is
the visible expression of Chroma, the energy stored in the current aspect.

The starter aspects are:

- Fire — red/orange visual identity.
- Water — blue visual identity.
- Electric — yellow visual identity.

The player chooses a persistent file starter flame when creating a new file.
That flame appears in the hub starting room on future runs and determines the
player's aspect after attunement, Triangle ability, and a small class identity
package until a later Binding replaces the persistent elemental identity. The
class package should
include all three of the following, while remaining modest enough that the
choice expresses playstyle rather than locking the player's build:

1. A small starting-stat adjustment.
2. A small passive modifier.
3. An aspect-specific Triangle ability bonus or behavior.

Blended aspects are governed by the approved flame-fusion design. Primordial
base-aspect swapping is a possible late-game system, but is explicitly out of
scope for the first implementation.

## 2. Run and Chroma rules

Every new run begins Gray with zero Chroma. The starter flame selected for the
file appears in the hub starting room. Interacting with it attunes the player
and refills Chroma immediately to 100. Hub attunement can be optional during
ordinary runs, while authored tutorial/progression flows may require it. The
first dungeon then teaches the selected starter aspect.

Initial values:

- Maximum Chroma: 100.
- Starter elemental action cost: 5 Souls for a flame Swap.
- Neutral Chroma pickup restoration: 20.
- Chroma is an integer value from 0 to 100; Triangle spending is not tied to
  the 20-point pickup value.
- Ten full elemental uses from 100 to 0.
- Normal flame attunement replaces the current aspect and refills Chroma to
  100.
- Neutral Chroma restoration preserves the current aspect.
- Gray cannot gain or store Chroma. A neutral Chroma pickup touched by Gray is
  consumed but grants no MP, aspect, or other effect.

Before Binding, reaching zero Chroma removes the elemental aspect and changes
the player to Gray. Gray remains fully playable.

After Binding, reaching zero Chroma preserves the elemental ability identity,
but without its elemental aspect. This is a weakened version of the ability,
not the full-strength elemental version. Chroma restoration remains valuable.

## 2A. Approved Binding, flame, and fusion extension

The current and bound elements are separate values:

- **Current element** is the active run-time identity used by Triangle,
  combat presentation, fusion input, and elemental doors.
- **Bound element** is the persistent profile identity written by the Cloaked
  Demon. It controls zero-Chroma persistence, recovery identity, save color,
  and hub-flame presentation.
- A current element may be unbound. It can still be used for combat, doors,
  and valid fusion during the run.

The approved Soul costs are:

- Flame Swap: **5 Souls**.
- Flame Fusion: **5 Souls**.
- Permanent Bind or Rebind at the Cloaked Demon: **50 Souls**.
- Binding the already-bound element: free no-op.

Flames can Swap or Fuse but cannot permanently Bind. Fusion does not require a
bound element; it uses the current element and the contacted flame, produces an
unbound result, and can be chained through valid recipes. The result becomes
persistent only after a confirmed 50-Soul Binding at the Cloaked Demon.

The approved recipes are:

| Input A | Input B | Result |
| --- | --- | --- |
| Fire | Water | Shadow |
| Fire | Electric | Ground |
| Water | Electric | Grass |
| Grass | Water | Ice |

Elemental doors check the current active element, including an unbound fusion
result. Required doors must not require Binding or the 50-Soul fee, and a
solved door remains unlocked after later Chroma or element changes. The full
state, interaction, persistence, and verification contract is in the linked
Binding/Fusion design document.

## 3. Triangle ability rules

The elemental action is the existing Triangle-button mapped ability. It is not
a new input slot.

The ability resolver should select the active Triangle behavior from:

```text
current aspect + Chroma amount + Binding state
```

The intended initial resolution is:

| Player state | Triangle behavior |
| --- | --- |
| Gray | Gray ability |
| Unbound aspect with Chroma | Full elemental ability |
| Unbound aspect at zero Chroma | Gray ability |
| Bound aspect with Chroma | Full elemental ability |
| Bound aspect at zero Chroma | Weakened non-elemental version of that ability |

Each aspect will eventually have distinct animation sets and gameplay
behavior. Animation production is part of the implementation plan, but the
runtime should not hard-code animation names into the Chroma state component.

### Gray ability direction

Gray's ability is intended to be a special emergency/control attack:

- slower attack;
- cooldown-based;
- lower direct damage than elemental abilities;
- high knockback;
- reliable or strong stun;
- no Chroma cost.

Exact values remain to be tuned.

## 4. Current repository integration surface

The project already contains several useful seams:

- `scripts/player_hud.gd` already presents an MP bar, though it is not yet
  connected to gameplay Chroma.
- `scripts/player_equipment_visual_component.gd` already exposes
  `set_mp_desaturation()`.
- `shaders/mp_desaturation.gdshader` provides the visual saturation control.
- `scripts/palette_library.gd` contains reusable color/palette data, including
  red, blue, yellow, gray, and blended colors.
- `scripts/screen_state_controller.gd` currently owns archetype and palette
  selection UI. This is the main menu seam to convert to flame selection.
- `scripts/player_attack_component.gd` owns the existing attack execution
  pipeline and is the likely execution seam for Triangle abilities.
- `scripts/gameplay.gd` orchestrates input, combat, rooms, and progression. It
  should receive routing calls only; Chroma rules and ability behavior should
  live in dedicated components/resources.
- `scripts/gameplay_bootstrap.gd` is the component-construction seam.
- `scripts/room_controller.gd` and `scripts/dungeon_graph.gd` own room flow
  and will need authored elemental progression metadata later.
- `scripts/player_profile.gd` owns persistent profile data and will eventually
  need unlocked aspects/Binding data. Current Chroma itself should remain
  run-local.
- Existing smoke coverage includes palette, fusion, progression, combat, and
  Chroma state/pickup/ability behavior.

## 5. Recommended ownership model

Introduce a dedicated runtime component, tentatively:

`player_chroma_component.gd`

It should own:

- current aspect;
- current and maximum Chroma;
- bound aspect state;
- attunement and restoration rules;
- depletion behavior;
- active Triangle ability resolution;
- signals for aspect, Chroma, and ability-state changes.

Introduce data definitions/resources for:

- aspect identity;
- minor stat adjustment;
- passive modifier;
- Triangle ability definition;
- full, Gray, and weakened-bound behavior;
- presentation colors and animation identifiers.

Introduce a separate `player_aspect_ability_component.gd` for Triangle ability
execution, cooldowns, projectiles/hit behavior, animation requests, and
room-transition cleanup. The Chroma component should own state transitions and
payment rules, not combat execution or presentation.

Keep gameplay identity separate from `PaletteLibrary`. Palette data can be a
presentation dependency of aspect definitions, but should not be the gameplay
source of truth.

## 6. Proposed implementation order

### Phase 0 — Contract and data design

- Finalize aspect names, colors, and class effects.
- Define Chroma and Binding state transitions.
- Define the ability interface and animation contract.
- Decide how the existing stat archetype data is replaced or reduced.

### Phase 1 — Runtime Chroma slice — substantially implemented

- Add canonical aspect/ability data.
- Add the Chroma component.
- Start runs as Gray at zero.
- Add unit/smoke tests for all state transitions.

### Phase 1B — Triangle execution boundary — routing implemented; final abilities TBD

- Add a dedicated aspect-ability component.
- Move the current magic lifecycle behind it.
- Route Triangle through resolved Chroma/aspect state.
- Implement the approved Gray ability and only approved elemental behavior.

### Phase 2 — Flame attunement and feedback — starter flow implemented; tutorial polish pending

- Convert new-file selection to Fire/Water/Electric flame selection and remove
  independent user-facing stat-archetype selection.
- Persist the selected starter flame and place it in the hub on every run.
- Start every run Gray at 0.
- Make flame attunement refill to 100.
- Connect Chroma to the HUD MP bar.
- Connect Chroma ratio to sprite desaturation.
- Add clear attunement/depletion feedback.

### Phase 3 — Tutorial curriculum — starter gate and opening puzzle framework in place

- Add the starter-flame pickup/puzzle flow. Run 1 now places two separated,
  seed-randomized puzzle milestones on the required path: an early starter-color
  puzzle and a later untinted Gray puzzle.
- Keep puzzle-room entrances usable when the puzzle is unsolved, so a player can
  back out and return to the hub rather than becoming trapped.
- Author the exact 100/90/80/70/60/50/40/30/20/10/0 depletion lesson.
- Prevent enemies or pickups from invalidating the forced sequence.
- Verify Gray ability access after depletion.

### Phase 4 — Elemental room framework — neutral enemy pickups implemented; authored room rules pending

- Add room aspect/theme metadata.
- Add elemental requirements and interactions.
- Add flame placement and neutral Chroma pickups.
- Add subtle room tinting.
- Add deterministic Run 2 swapping/backtracking curriculum.

### Phase 5 — Binding and flame fusion — implemented

- Implement the current/bound state split.
- Add 5-Soul Swap and 5-Soul Fusion flame transactions.
- Add the 50-Soul Cloaked Demon Binding menu and profile persistence.
- Add the four approved recipes and unbound fusion chaining.
- Preserve bound aspect identity at zero Chroma.
- Make required elemental doors accept current unbound elements and latch open.
- Add mandatory fusion-element gates to generated Run 6+ layouts, with the
  chained Grass/Ice curriculum beginning on Run 8.
- Implement weakened non-elemental variants only where the ability contract
  approves them.
- Follow [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md)
  for the ordered work and test gates.

### Phase 6 — Later expansion

- Add elemental enemy mechanics.
- Add broader constrained procedural generation.
- Evaluate Primordial base-aspect swapping.

## 7. Decisions still required for future content

### Class effects

- What exact small stat adjustment does each flame provide?
- What exact passive modifier does each flame provide?
- Before Binding, the complete class package follows every mid-run flame swap:
  stat adjustment, passive, ability, and aspect presentation are replaced
  together.
- Binding later changes that replacement rule by preserving identity for
  blending. Its exact class-package behavior remains part of Binding design.
- Existing pre-Chroma saves do not require migration and may be reset or
  rejected.

### Ability contract

- What is the exact Triangle ability behavior for Fire, Water, and Electric?
- Does each ability have a common cooldown, or does each aspect tune its own?
- Does the ability cost Chroma on activation or only when it successfully
  affects a target/environment object?
- Triangle spending is 10 while neutral restoration is 20, so the state is no
  longer quantized to pickup charges. Full elemental affordability is a
  direct `current_chroma >= 10` check.
- How much weaker should the bound-at-zero version be?
- Which animation states are required for Gray, full elemental, and weakened
  bound variants?

### Gray and tutorial

- Gray's ability is usable immediately before the starter flame is found; its
  exact numeric behavior still needs approval.
- What exact stun duration, knockback, damage, startup, and cooldown should it
  use initially?
- The flame is selected once during new-file creation, appears in the hub room
  on every run, and is activated through physical interaction before the
  dungeon. Tutorial/progression flows may require that interaction.
- Does the first tutorial always use the selected starter aspect's puzzle, or
  does it use a neutral shared puzzle structure with different interactions?

### Persistence and progression

- Fire, Water, and Electric are the new-file starter choices. Whether the two
  unselected base aspects require progression unlocks as in-run flames remains
  undecided.
- What exact story/run milestone unlocks the Cloaked Demon Binding menu?
- The selected starter flame is saved as the file default and is not chosen
  anew each run. A possible late-game Primordial swap remains out of scope.
- Existing pre-Chroma saves may die out; no compatibility migration is required.

## 8. Verification requirements

Before the first slice is complete, add tests covering:

- new run starts Gray at zero Chroma;
- flame attunement sets the aspect and refills to 100;
- elemental ability spends exactly 10 Chroma;
- ten uses produce 100 → 90 → 80 → 70 → 60 → 50 → 40 → 30 → 20 → 10 → 0;
- unbound zero Chroma resolves to Gray;
- bound zero Chroma resolves to the weakened elemental ability;
- neutral restoration preserves the current aspect;
- neutral restoration adds exactly 20 and caps at 100;
- Gray consumes a neutral pickup but stays at zero without an aspect;
- flame replacement changes aspect and refills immediately;
- Swap never changes the bound element or profile identity;
- Fusion works without a bound element and produces the approved result;
- Fusion results remain unbound until the Cloaked Demon confirms Binding;
- Binding costs exactly 50 Souls and updates save/hub identity atomically;
- required doors accept unbound current elements and remain solved;
- stat, passive, and ability identity derive from the selected flame;
- HUD and visual saturation reflect the same Chroma value.

Continue using the existing headless checks:

```powershell
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Development\Tiny-Demons\TinyDemons" --quit-after 30
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
```

## 9. Handoff recommendation

The implemented core follows
[`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md),
while the separate ability/class-package sheet for Gray, Fire, Water, and
Electric continues to govern any future class-package details. No new status
system is implied by the Binding/Fusion implementation.

The implemented baseline is:

```text
new-file flame choice → Gray run start → selected hub flame → attunement →
Triangle ability → Chroma depletion → Gray fallback → HUD/desaturation feedback
```

The full smoke runner is the regression gate for further changes; broader
procedural or status-system work remains outside this feature.
