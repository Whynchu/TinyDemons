# Tiny Demons — Elemental Chroma Implementation Plan

Status: reviewed draft, implementation in progress

Source design: `docs/Tiny Demons — Elemental Chroma System Design.md`

Decision history: `docs/elemental-chroma-handoff.md`

The approved Binding and flame-fusion extension is specified in
[`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md)
and implemented through
[`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md).

This plan separates confirmed design rules from proposals that still require
approval. It maps the first playable Chroma loop onto the current Godot project
without committing the project to unapproved elemental abilities, status
effects, or balance values.

## 1. Confirmed product contract

### 1.1 File identity and run opening

- Creating a new file replaces independent color/stat-archetype selection with
  one starter-flame choice: **Fire**, **Water**, or **Electric**.
- The selected starter flame is persistent for that file.
- The file's selected flame appears in the hub starting room at the beginning
  of future runs.
- Every run begins **Gray at 0 Chroma**, even after the starter flame has been
  selected.
- Interacting with the hub flame attunes the player to that aspect and refills
  Chroma immediately to 100.
- Attuning in the hub may be optional during ordinary runs. Authored tutorial
  or progression sequences may require it.
- Run 1's first dungeon teaches the selected starter aspect.

### 1.2 Flame as the small class package

Flame selection owns all three minor class effects:

1. A small stat adjustment.
2. A small passive modifier.
3. The aspect-specific Triangle ability and its associated benefit.

The five existing `StatsComponent.AllocationProfile` choices must not remain a
second user-facing class-selection axis. Manual stat allocation, persistent
level growth, and equipment continue to provide long-term build expression.
The old enum may temporarily remain as an internal save-migration mechanism.

Exact Fire, Water, and Electric stat/passive/ability packages are **not yet
approved** and must remain data-driven proposals until reviewed.

The active class package follows the current element. A mid-run Swap or Fusion
changes current identity without mutating the persistent bound identity.
Binding preserves the current element for zero-Chroma recovery and profile/hub
identity; it does not create a second combat type or stack class packages.
The exact class-package details remain subject to the separate ability/class
sheet, but the current/bound state split is no longer deferred.

### 1.3 Chroma rules

- Maximum Chroma: 100.
- Full elemental Triangle ability cost: 10 on an accepted activation.
- Neutral Chroma pickups restore exactly 20.
- Chroma is an integer value from 0 to 100; Triangle spending is not restricted
  to the pickup value grid.
- Ten accepted full elemental uses produce 100 → 90 → 80 → 70 → 60 → 50 →
  40 → 30 → 20 → 10 → 0.
- A rejected input must not spend Chroma.
- Normal flame interaction replaces the current aspect and immediately refills
  Chroma to 100.
- Neutral Chroma restoration preserves an existing current aspect.
- Gray cannot gain or store Chroma.
- If Gray touches a neutral Chroma pickup, the pickup is consumed and grants no
  MP, aspect, or other effect.
- Before Binding, reaching zero clears the unbound aspect and resolves Triangle
  to Gray's ability.
- After Binding, reaching zero preserves the stored aspect and resolves
  Triangle to a weakened, non-elemental version of that aspect's ability.

The flame Binding/Fusion extension adds these separate transaction rules:

- Swap at a flame costs 5 Souls and changes current only.
- Fuse at a flame costs 5 Souls, does not require a bound element, and uses
  current plus the contacted flame.
- Fusion results are immediately current but remain unbound.
- Bind/Rebind occurs only at the Cloaked Demon and costs 50 Souls.
- Required elemental doors check current active element, including unbound
  fusion results, and latch open without requiring Binding.

### 1.4 Triangle and Gray

- The Chroma ability uses the existing `magic` input mapped to Triangle/Y.
- Gray has a real ability, not a disabled button.
- Gray's current design direction is a slow, cooldown-based control attack with
  strong stun and knockback, lower direct damage, and no Chroma cost.
- Fire, Water, Electric, and weakened-bound behaviors still require explicit
  design approval.
- Each class will eventually have distinct animations. Runtime state must refer
  to animation identifiers or requests rather than hard-coded sprite logic.

## 2. Runtime state model

Do not use palette strings as gameplay identity. Introduce an aspect identity
type with at least:

```text
NONE / FIRE / WATER / ELECTRIC / GRASS / SHADOW / GROUND / ICE
```

The initial runtime may stage the later IDs behind content unlocks, but the
recipe catalog must use stable IDs from the beginning.

The runtime needs to distinguish these effective forms:

| Effective form | Current element | Bound element | Chroma | Triangle mode |
| --- | --- | ---: | --- | --- |
| Gray | None | None or any | 0 | Gray ability |
| Charged current element | Any released element | None or any | Above 0 | Full current-element ability when affordable |
| Dormant bound element | Bound element or resolved fallback | Same persistent element | 0 | Weakened bound ability |
| Unbound fusion current | Fusion result | None or different element | Above 0 | Full fusion-result ability |

The implementation must not collapse current and bound into a single
`binding_active` Boolean. A bound Water profile may temporarily use an
unbound Grass or Ice fusion.

The final paid cast resolves before the depletion transition. A cast accepted
at 10 Chroma therefore performs the full elemental behavior, spends the final
10, and then transitions to Gray or dormant-bound state. Values below 10 are
not affordable for a full elemental Triangle cast and resolve to Gray unless
the bound-zero rule applies.

## 3. Ownership boundaries

### 3.1 Aspect definition data

Add an aspect definition resource or typed data object containing:

- stable aspect identifier;
- display name;
- presentation palette identifier;
- small stat modifier;
- passive identifier and tuning data;
- full ability identifier;
- weakened-bound ability identifier;
- animation/effect identifiers.

`PaletteLibrary` remains presentation data. It must not become the authority for
attunement, Chroma, Binding, passives, or ability behavior.

### 3.2 `PlayerChromaComponent`

Owns only state and transitions:

- stored aspect;
- current/max Chroma;
- Binding state;
- attunement;
- neutral restoration;
- affordability and accepted-spend rules;
- unbound depletion;
- effective-form/ability-mode resolution;
- state-change signals.

It must not spawn projectiles, damage enemies, update HUD nodes, select sprite
frames, or directly apply shaders.

### 3.3 `PlayerAspectAbilityComponent`

Owns Triangle execution:

- input acceptance conditions delegated from the frame controller;
- per-ability startup, active, recovery, and cooldown state;
- Gray/full-elemental/weakened-bound execution;
- hit queries, projectiles, knockback, stun, and later status hooks;
- animation requests;
- room-transition cleanup;
- reporting accepted activation back to Chroma for payment.

The existing magic implementation in `gameplay.gd` is migration material for
this component, not the permanent home of every aspect ability.

### 3.4 Presentation consumers

- HUD reads Chroma state and displays the MP/Chroma bar.
- Player visual presentation reads aspect and Chroma ratio.
- The existing duplicate desaturation paths are collapsed to one presenter
  path.
- Effects and projectiles read presentation data from the resolved ability and
  aspect definition.

## 4. Verified current code seams

| Concern | Current location |
| --- | --- |
| MP maximum and runtime field | `gameplay_state.gd` (`PLAYER_MAX_MP`, `player_mp`) |
| MP bar update | `gameplay.gd:_update_player_mp_ui` |
| Triangle/Y input | `gameplay.gd:_is_magic_input_pressed` and `gameplay_frame_controller.gd` |
| Current magic cast | `gameplay.gd:_try_cast_magic` |
| Projectile execution | `gameplay.gd:_spawn_magic_projectile`, `_update_magic_projectiles`, `_magic_hit_slime` |
| Run reset | `gameplay.gd:_begin_new_run`, `gameplay_bootstrap.gd` initialization |
| Flame/rest-fire interaction | `gameplay.gd:_fire_target_palette`, `_interact_with_fire`, `_restore_player_mp` |
| Flame room setup | `room_controller.gd:_assign_rest_fire_palette` |
| Desaturation | `gameplay.gd:_update_mp_desaturation` plus `player_equipment_visual_component.gd:set_mp_desaturation` |
| New-file selection | `screen_state_controller.gd:start_selected_archetype` |
| Existing stat profiles | `stats_component.gd:AllocationProfile` |
| Persistent starter identity | `player_profile.gd` currently stores `palette_name` and `allocation_profile` |
| Component construction | `gameplay_bootstrap.gd` |

Line numbers are intentionally omitted because the planned refactor will move
these seams.

## 5. Implementation phases

### Phase 0 — Authoritative contract and compatibility

- Add stable aspect identifiers and aspect-definition data.
- Add a Chroma tuning resource for confirmed values and later ability tuning.
- Treat the Chroma schema as a clean break. Existing pre-Chroma saves do not
  require migration and may be reset or rejected.
- Decide the remaining §8 behavior before coding it.
- Mark legacy eight-aspect and matchup-wheel direction as superseded.

Exit condition: no unresolved rule can change the Phase 1 state model.

### Phase 1 — Pure Chroma state slice

- Add `PlayerChromaComponent` independently of presentation and abilities.
- Implement Gray run start, flame attunement, replacement, restoration,
  accepted spending, unbound depletion, and dormant-bound resolution.
- Add focused tests for the complete state-transition matrix.
- Keep a compatibility bridge so existing MP UI/magic code can read the new
  owner during migration.

Exit condition: state behavior is deterministic and covered without requiring
the main scene.

### Phase 2 — Triangle ability boundary

- Add `PlayerAspectAbilityComponent`.
- Move the current magic lifecycle behind it.
- Implement the approved Gray ability.
- Use placeholders only for approved portions of starter abilities; do not
  invent burn/slow/chain systems as incidental implementation work.
- Spend Chroma only after a cast has passed all acceptance checks.
- Add cooldown and room-transition cleanup tests.

Exit condition: Triangle resolves through aspect/Chroma/Binding state, and
`gameplay.gd` contains orchestration calls rather than aspect behavior blocks.

### Phase 3 — File selection, hub attunement, and feedback

- Replace new-file archetype/color selection with Fire/Water/Electric flame
  selection.
- Persist the selected starter flame.
- Make the selected flame appear in the hub start room on every run.
- Start every run Gray at 0.
- Attuning fills to 100 and applies the flame's complete class package.
- Connect HUD and one visual desaturation presenter to Chroma signals/state.
- Ensure Gray neutral pickups are consumed with no effect.

Exit condition: the full first-milestone loop works in the main scene.

### Phase 4 — Run 1 authored curriculum — starter gate and opening puzzle framework in place

- Require hub attunement in the new-file opening flow.
- Build the selected starter aspect's first-dungeon lesson.
- Route Run 1 through two separated, seed-randomized required milestones: an
  early tinted starter-color puzzle and a later untinted Gray puzzle.
- Keep the puzzle entrance usable while unsolved so the player can retreat.
- Author the exact four-use depletion sequence.
- Suppress enemies and Chroma pickups that could invalidate the lesson.
- Teach Gray fallback and re-attunement/refill.

Exit condition: Fire, Water, and Electric versions of Run 1 are solvable and
communicate the same rules.

### Phase 5 — Elemental room contract and Run 2 — neutral enemy pickups in place; room curriculum pending

- Add room aspect/theme and requirement metadata.
- Add flame placement and neutral Chroma pickup rules. The current runtime has
  neutral enemy drops with automatic proximity collection and room-state
  persistence.
- Add puzzle reset/recovery behavior.
- Build authored Run 2 route templates for flame discovery, swapping, and
  backtracking.
- Validate reachability and gate ordering before accepting a generated layout.

Exit condition: no generated curriculum can place a required flame behind its
own gate or permanently trap the player through Chroma expenditure.

### Phase 6 — Binding

- This phase is superseded by the dedicated
  [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md).
- Implement the approved current/bound state split, 5-Soul Swap, 5-Soul
  Fusion, and 50-Soul Cloaked Demon Binding.
- Allow Fusion without an existing bound element.
- Keep fusion results unbound until a successful Demon Binding.
- Let current unbound elements solve required doors without a Binding fee.
- Preserve stored identity at zero Chroma and implement approved weakened
  bound variants.
- Prevent flame interactions from resetting cooldowns or creating stat/health
  exploits.
- Add save migration and transition tests.

### Phase 7 — Later expansion

- Elemental enemy mechanics.
- Aspect-aware equipment/transmutation hooks.
- Broader constrained procedural curricula.
- Possible late-game Primordial starter-flame swap.

## 6. Dungeon curriculum contract

Run 1 and Run 2 should begin as authored templates with controlled random
variation, not a generic constraint solver.

Each curriculum description should eventually provide:

- unlocked aspects and mechanics;
- intended lessons in order;
- mandatory flame placements;
- mandatory aspect gates;
- allowed enemy/pickup categories;
- required backtracking paths;
- room tint/theme metadata;
- validation rules.

Validation must prove:

- every required flame is reachable before the gate that needs it;
- backtracking remains available;
- mandatory depletion rooms cannot receive random Chroma or enemies;
- spent Chroma cannot make the run permanently unsolvable;
- current unbound fusion can reach and solve its required elemental door;
- required doors never require a return to the Demon solely to pay Binding;
- solved elemental doors latch and cannot re-lock after Chroma/element changes;
- puzzles can reset safely;
- an unexpected requirement creates rerouting rather than a dead run.

## 7. Verification strategy

### Pure state tests

- New run starts Gray at 0.
- Flame attunement establishes the selected aspect and fills to 100.
- Flame replacement changes aspect and fills to 100.
- Neutral restoration adds exactly 20, caps at 100, and preserves an existing
  aspect.
- Gray consumes neutral pickups but remains Gray at 0.
- Rejected activations do not spend Chroma.
- Ten accepted casts produce 100 → 90 → 80 → 70 → 60 → 50 → 40 → 30 →
  20 → 10 → 0.
- The final cast resolves at full strength before depletion.
- Unbound zero becomes Gray.
- Bound zero becomes dormant-bound and resolves the weakened ability.
- Current/bound mismatch resolves deterministically without mutating profile
  identity.
- Flame Swap costs 5 and never changes bound identity.
- Flame Fusion costs 5, works without Binding, and uses current as input.
- Fusion results remain unbound until the Demon commits them.
- Binding costs 50 and is atomic across Souls, current, profile, and hub state.

### Ability integration tests

- Triangle routes to the correct ability mode.
- Cooldowns prevent acceptance and payment.
- Gray ability costs no Chroma.
- Hit, knockback, stun, and status behavior follow approved ability data.
- Projectiles/effects are cleaned up across room transitions.
- Flame swapping does not reset cooldowns.
- FOCUS, combo telemetry, multi-target damage sharing, and transmutation hooks
  behave intentionally for abilities.

### Presentation and curriculum tests

- HUD and saturation read the same Chroma owner.
- Aspect palette and effective form stay synchronized.
- The starter hub flame matches the file selection on every run.
- All three Run 1 curriculum variants are solvable.
- Forced depletion cannot be invalidated by random encounters or pickups.
- Run 2 flame/gate ordering passes deterministic reachability validation.
- A mandatory Ice door is solvable through current unbound fusion without a
  prior permanent Bind.
- A solved elemental door remains open after current/Chroma changes.

Continue running the existing headless suite after every slice:

```powershell
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Development\Tiny-Demons\TinyDemons" --quit-after 30
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
```

## 8. Decisions still required

These remain proposals, not implementation authority:

1. Exact Fire, Water, and Electric Triangle abilities.
2. Exact stat adjustment and passive for each flame.
3. Exact Gray ability damage, startup, recovery, stun, knockback, and cooldown.
4. Exact penalty/effect removal for weakened bound abilities.
5. Binding menu unlock timing and the exact zero-Chroma behavior when current
   and bound elements differ. The economy, location, and persistence contract
   are approved in the Binding/Fusion design.

## 9. First milestone

```text
Create file and choose Fire/Water/Electric
→ begin run Gray at 0
→ selected flame appears in hub
→ attune to 100
→ Triangle spends Chroma
→ saturation and HUD track depletion
→ final full cast reaches 0
→ unbound player becomes Gray
→ Gray Triangle ability remains functional
```

No hybrid system, broad procedural rewrite, or unapproved elemental status
system begins until this loop is playable, readable, and covered by automated
tests.
