# Tiny Demons — Elemental Ability and Status System Design

Status: design authority; the bounded status implementation lives in
[`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md).

Scope: long-term elemental ability + status + presentation direction for the
player and combat enemies. The current implementation covers five element-owned
statuses plus the auxiliary Freeze mixture, Water conductivity, innate enemy
affinity, contact transmission, and themed enemy rosters; a generalized ability
resolver and new delivery types remain future work.

Owner: element registry (`element_catalog.gd`), the combat damage boundaries
(`combat_runtime_controller.gd`, `slime_actor.gd`), presentation
(`effects_spawner.gd` and the actor/equipment visual owners), and the M1
authoring pipeline (`authoring-system-plan.md`).

Current code: `ElementCatalogData.status_effects` in
`resources/definitions/element_catalog.tres` references the five typed
`StatusEffectDefinition` resources; `StatusComponent` owns actor-local status
state; `CombatRuntimeController` applies eligible procs and consumes typed tick
results; the frame and actor runtimes schedule those ticks. `HudController`
draws status badges, while `ElementAuraComponent` owns status outlines and the
cached imbue outline/flash overlays delegated by
`PlayerEquipmentVisualComponent`. It schedules edge particles through
`EffectsSpawner`; each typed status resource selects its particle style and
interval. The full acceptance and unresolved rendering report are tracked in
[`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md).

Verification: see the bounded implementation plan for current acceptance and
focused checks. Adding an element effect must not add a per-element behavior
branch.

Supersedes: none. It operationalizes the ratified ailment set in
`design-interview-record-2026-09-18.md` and the element identities in
`combat-and-dungeon-design-principles.md`, under the component contract in
`component-composition-design.md`. It does not change the Chroma/Binding plans.

> **Advisor review (2026-09-28).** Thorn traced the source and corrected several
> claims in the first draft of this document (aura bias, one-vs-two damage
> boundaries, `GameplayState` status state, reset/tick ownership). Pip bounded
> the sequence; Hexley shaped the player-facing scope. The corrections are
> folded into the text and recorded in §12.

## 1. Purpose

Tiny Demons already has stable element identity and a working damage pipeline,
but an element currently changes only its damage multiplier and its tinted
damage number. This document defines how an element gains **behavior** —
accessibility, status effects, auras, and eventually environmental interactions —
through **one pipeline** whose stages are parameterized by data, not by
per-element code.

The long-term design goal is compositional:

```text
one element atom  ->  one ability definition  ->  one resolver
        ->  one status model  ->  one presentation pipeline
        ->  attachable to player and combat actors
```

An "elemental ability" is not a bespoke function. It is authored data interpreted
by shared runtime pieces for the player and combat actors.

## 2. Non-goals

Carried forward from the ratified design contract, not re-opened here:

- **No universal elemental-reaction simulator.** Prefer one clear rule that
  combines with existing rules (`combat-and-dungeon-design-principles.md:53`).
- **Not every element carries a status.** The current set is **Fire Burn** and
  **Shadow Poison** (DoT), **Electric Shocked** (periodic stun), **Ice Chill**
  (movement/attack slow), and **Water Wet** (Electric conductivity and Burn
  removal). Ground remains status-free.
- **One authored status mixture is implemented:** Wet + Chill on one actor
  consumes both and produces Freeze. Other status pairs may coexist; this is
  not a generalized elemental-reaction system.
- **Environmental reactions (Water puts out Fire) are a separate system.** They
  belong to authored objects and interaction rules, not the combat damage path
  (`combat-and-dungeon-design-principles.md:245-257`). This document only defines
  the hooks that system will later consume.
- **No per-actor special-case branches.** A status must not test "is this a
  slime" to decide behavior.
- **Do not grow the verification surface.** New coverage refines existing suites
  (`verification-surface-audit.md:152`).

## 3. The three layers

The system is deliberately split so each layer can be authored, tested, and
replaced independently.

### 3.1 Layer 1 — Element registry (exists, extend)

`ElementCatalog` is the single gameplay identity authority
(`element_catalog.gd`). Current data: stable ids, display names, palette keys,
the matchup table, and the bounded implementation's `status_effects` resource
list. The longer-term design adds an **effect presentation profile** per
element:

```text
element id
  palette_key        # → PaletteLibrary tones (presentation)
  aura_style         # outline | silhouette | both | none
  particle_id        # effect texture / particle preset reference
  status_mark_id     # small glyph over the afflicted actor
  audio_clip_id
```

The `Element` enum, matchup policy, and proc math stay in code; only
presentation and content references are authored. This extension must happen
**inside** the slice-2 element-identity consolidation
(`authoring-system-plan.md:1086`), or it becomes the "fifth parallel table".

### 3.2 Layer 2 — Ability and status definitions (new, typed Resources)

Two definitions, both intended to be discovered by the M1 catalog/manifest
pipeline the same way `EnemyDefinition` variants are. **M1 acceptance is a
prerequisite, not a given** (`AUDIT.md` §15 item 3; `authoring-system-plan.md:1189`);
until it closes, register these through the `ElementCatalogData`-style single
registry to avoid a parallel table (§9).

**`ElementalAbilityDefinition` (proposed, not implemented)** — what an ability
does when it lands:

```text
id                 stable StringName
element            Element id
damage_contract    physical | magic | imbued_weapon | elemental_slime
base / scaling     numbers (reuse CombatDamageRequest fields)
delivery           projectile | melee_arc | aura_cone | self_buff
cooldown           per-ability duration (not a class const)
status_payload     status id + proc params (or empty)
presentation       projectile/impact profile refs
```

**`StatusEffectDefinition` (implemented bounded schema)** — what a status does
while active:

```text
id                 stable StringName
element            Element id
family             damage_over_time | movement_slow | periodic_stun |
                   damage_amplification | ambient_modifier
proc_chance        flat chance per eligible hit
tick_interval      seconds (damage-over-time only)
magnitude_per_stack damage per tick or movement/attack slow
duration           seconds
maximum_stacks     stack cap
stun_interval      seconds (periodic stun only)
stun_lock_duration seconds (periodic stun only)
badge_glyph        pixel-text mark displayed in the status badge
particle_style     ember | poison_mote | electric_spark | frost_crystal | bubble
particle_interval  seconds between edge-particle emissions
transmissible      whether actor contact can apply this status
ambient fields     conducted element/damage/cadence and extinguished status ids
```

The current resource does not define exclusivity groups or aura profiles.
Enemy-specific immunity is authored as status IDs on `EnemyDefinition`. The
generalized ability definition and richer presentation profiles remain future
work.

`StatusEffectDefinition` is also what an enemy applies to the player, and what
the player applies to an enemy. One definition, one consumer contract.

### 3.3 Layer 3 — Runtime components (new, blind)

| Component | Responsibility | Attach to |
|---|---|---|
| `StatusComponent` | Owns active status records, advances duration/tick/cadence, and emits `status_changed` | player and combat actors |
| `StatusTransmissionController` | Receives an immutable pre-separation contact snapshot, transfers eligible statuses both ways, and owns unordered pair cooldowns | scheduled by `SlimeRuntimeController` |
| `ElementAuraComponent` | Uses configured actor/status/overlay-parent references; draws status outlines, schedules status particles, and owns imbue outline/flash overlays | player and combat actors |
| `EffectsSpawner` | Emits cached edge particles using the style selected on the status definition | status presentation |
| `ElementalAbilityResolver` (future) | Takes ability and caster/target refs, executes delivery, and calls the status path | player or enemy controller |
| `StatusApplication` helper | Selects the element's status data, checks the typed request/proc gate, and ignores status ticks as sources | enemy-bound and player-bound damage paths |

The implemented components follow the component contract
(`component-composition-design.md:42-68`): no parent/node discovery or root
reach-ins, typed references configured by the owning bootstrap/factory, internal
state, and signals up / commands down. `ElementAuraComponent` receives its
actor sprite, overlay parent, and `StatusComponent` through `configure`; colors
and alpha are supplied by the caller. Per-element presentation profiles remain
future work.

## 4. The effect pipeline (one path, element-parameterized)

The long-term presentation pipeline is parameterized by the element. The
bounded implementation uses catalog-backed status rules, one element-colored
outline for the strongest active status, HUD badges, status-selected edge
particles, and the existing damage-number path for DoT ticks. It does not yet
implement silhouette fills or bespoke impact bursts; those remain later
presentation work.

| Stage | What it does | Current owner / state |
|---|---|---|
| 1. Palette resolve | element → palette key → `PaletteLibrary` tones | `element_catalog.gd`; profile expansion remains planned |
| 2. Outline | 1px alpha-dilated outline colored by the element | `ElementAuraComponent`; status and imbue consumer |
| 3. Silhouette fill | solid element-tinted copy of the sprite | not implemented for statuses |
| 4. Edge particles | particle spawn positions from current actor-frame edge pixels | `EffectsSpawner`; `particle_style` selects ember, mote, spark, or frost motion/art |
| 5. Palette swap | GPU recolor of source tones (from/to color pairs) | `shaders/palette_swap.gdshader` |
| 6. Impact burst | on-hit element burst | `EffectsSpawner`; existing hit feedback |
| 7. Status mark | small glyph over the afflicted actor | `HudController` pixel badges |
| 8. Audio | element → clip id | `SoundManager`; status-specific cues are not added |

No element gets a status-specific combat branch.

**Generalization rule.** This is a **reuse extraction, not a composition
cleanup**: `player_equipment_visual_component.gd` already has zero root accesses
(A1 migrated it to `PlayerEquipmentVisualContext`; see
`component-composition-design.md:386-397`). `PlayerEquipmentVisualComponent`
delegates outline/flash creation to `ElementAuraComponent`; the imbue timer
authority stays in `MagicRuntimeController`. The shared sibling overlay copies
the sprite's global transform and uses the sprite-frame region, avoiding a
second inherited scale/offset. Source-level horizontal flip, nearest filtering,
z-order, and fade values are preserved. Pixel parity and visual acceptance
still need a before/after native-resolution check.

## 5. Status model

### 5.1 Families

| Family | Behavior | Examples |
|---|---|---|
| `dot` | Recurring `HealthComponent.apply_damage` on a tick interval | Burn, Poison, lifedrain |
| `control` | Alters the actor's per-frame behavior | Chill (movement/attack tempo), Shocked (skip action) |
| `reaction` | Reserved for the future environmental/object system | Water extinguishes Fire |

A status record retains its definition, remaining duration, stacks, source
element, and tick/cadence timer. DoT kills reuse the existing `_kill_slime` path
(`slime_actor.gd:211`) so drops, XP, and clear detection are unchanged. **DoT
ticks use a dedicated tick-damage method, not `damage_actor`** — `damage_actor`
is also the proc/kill/hitstop path and would otherwise re-proc and flash on
every tick (§5.4).

### 5.2 Control reuses existing timers where they exist

- **Stun** maps onto `SlimeCombatComponent.hitstun_timer`
  (`slime_combat_component.gd:19`), already honored by `SlimeActor.tick_runtime`
  (`slime_actor.gd:129-131`). But hitstun is currently a ~1/30 s *hit reaction*,
  not a stun (`GAMEPLAY_TUNING.md:57`); a real stun is a separate magnitude, and
  it must respect the existing boss stun-resistance flag
  (`slime_combat_component.gd:35`).
- **Chill** scales movement through the existing enemy brain and player motor,
  and slows attack cadence/animation through the existing enemy and player
  attack timers. No new movement or attack system.

### 5.3 Stacking and exclusivity

- The five element-owned statuses may coexist except for the registered
  WATER + ICE mixture: Wet and Chill are consumed to create Freeze. No other
  exclusivity groups are authored. Any future mixture must specify consumption
  and reset behavior explicitly.
- Stacking rules (owner-directed, addendum B4/B5): repeated procs **stack
  intensity up to a per-status cap** while active, and re-proc after expiry is
  **immediate** with no immunity window. Both are tuning values, not code
  branches.

### 5.4 The proc gate (two boundaries, one helper)

There are **two** damage boundaries, not one (corrected from the first draft):

- **Damage to enemies** converges on `SlimeActor.damage_actor`
  (`slime_actor.gd:181`) via `CombatRuntimeController.damage_slime_with_number`
  (`combat_runtime_controller.gd:91`) for both melee
  (`player_attack_component.gd:363`) and magic
  (`magic_runtime_controller.gd:668`).
- **Damage to the player does not pass through that path.** Enemy melee calls
  `HealthComponent.apply_damage` directly in `SlimeActor.apply_attack_hit`
  (`slime_actor.gd:289`); the boss slam calls it in
  `CombatRuntimeController.apply_boss_jump_slam` (`combat_runtime_controller.gd:579`).

The boundary carries **no `DamageResult`**, only `(amount, was_critical,
attack_element, immune, show_damage_number)`; melee rewrites `amount` before
dispatch (`player_attack_component.gd:362`). The helper therefore takes the
minimal available signature:

```text
StatusApplication.on_damage(target, element, immune, source):
    if source == STATUS: return          # DoT bypass: no re-proc, no hitstop
    if immune or element == NEUTRAL: return
    status = ability.status_payload
    if status is empty or not rng_roll(status.proc): return
    if target.StatusComponent.resists(status, element): return
    target.StatusComponent.apply(status, element)
```

Two call sites: the enemy-bound path (`slime_actor.gd:181`) and the player-bound
paths (`slime_actor.gd:289` / `combat_runtime_controller.gd:579`). `source ==
STATUS` is mandatory — it is a correctness requirement, not a style choice.

The player's own statuses live on an attached `StatusComponent`, **never** as
new `GameplayState` fields (§10).

## 6. Ownership and change map

| Concern | Owner | Change |
|---|---|---|
| Element identity + effect profile | `element_catalog.gd` / `element_catalog.tres` | extend data inside slice-2 consolidation; keep enum + math |
| Ability/status data | new `*Definition` + registry | M1 pipeline once accepted, else single registry |
| Status state + tick | new `StatusComponent` | attach in `SlimeActor.ensure_components` (`slime_actor.gd:56-65`) and as a child of the player actor — **not** `GameplayState` |
| Aura presentation | new `ElementAuraComponent` | reuse-extract from equipment visual; keep timer authority in `MagicRuntimeController`; equipment visual is first consumer |
| Proc gate | `combat_runtime_controller.gd` / `slime_actor.gd` | two call sites + DoT bypass flag |
| Frame tick | `slime_actor.gd:tick_components` (enemy) and beside `aspect_ability.tick` (`gameplay_frame_controller.gd:636`) | no `_process()`; enemy DoT must tick in `tick_components`, not `tick_runtime` (which early-returns on hitstun) |
| Room reset | `SlimeActor.reset_runtime_state` (`slime_actor.gd:343`) + a player clear on room entry / new run | pooled slime slots must be cleared; `MagicRuntimeController.reset_for_room` no-ops by default and is **not** a status reset |
| Enemy ability delivery | `SlimeSupportComponent` pattern | new `behavior_id` reusing the cast template |
| Player ability delivery | `PlayerAspectAbilityComponent` | element-aware resolver |

## 7. Strap-ability proof (the acceptance bar)

The system is "clean" only when this holds:

1. **Data-driven second effect.** Add another `StatusEffectDefinition` and
   element profile entry without a new per-element combat branch. Actor wiring
   is required only when adding a new combat actor family.
2. **Combatant coverage.** The player and the existing slime/skeleton combat
   actors use the shared status mechanism.
3. **One aura implementation.** The player weapon imbue and the enemy status
   aura both use `ElementAuraComponent`; the old player-specific outline code is
   gone and the imbue render is pixel-identical.
4. **No per-element branch.** A grep of the effect pipeline finds no
   `if element == FIRE` behavior; only data lookup.

## 8. First vertical slice and current follow-up

The source slice is implemented locally. The remaining sequence is verification
and acceptance, not implementation of the four initial status families.

1. **Color readability check.** Use the actual status marks and palette in a
   native-res 240×160 combat scene with 8–9 actors and the full HUD. Check that
   a new player can find the afflicted combatant and distinguish its ailment.
2. **Focused runtime coverage.** Run the registered status component, combat,
   and player-death visibility checks when a supervised Godot verification slot
   is available; then run the relevant catalog/definition validators.
3. **Visual and web acceptance.** Confirm status readability, imbue pixel
   parity, cloak/death disappearance, and the transient magenta report in a
   color playtest. The magenta report has no capture or confirmed cause yet.
4. **Data-driven proof** — confirm another status resolves from catalog data
   without a per-element combat behavior branch.
5. **Deferred:** drain-caster enemy (fifth enemy concept, conflicts with the
   capped four-role roster; also coordinate with codex's active claim on
   `slime_support_component.gd`), player special-move ability (until the
   three-role loadout exists), environmental reactions (separate system).

## 9. Open decisions (must be closed before their slice)

Owner-directed intent and the recommended resolution for each item are tracked in
[`elemental-ability-and-status-system-addendum.md`](elemental-ability-and-status-system-addendum.md).

The status-specific decisions are closed in the addendum and implementation
plan. Initial magnitudes and chances remain tuning defaults for playtesting.
Gear-based status resistance and a generalized ability resolver are out of this
pass. M1 remains open, so the current bootstrap uses `ElementCatalogData` and
must migrate only when the M1 acceptance bar closes.

## 10. Risks and guardrails

- **`GameplayState` is frozen.** The regression gate fails above 286 fields, and
  the line cap has one line of headroom (`tools/composition-baseline.json`).
  Player status must be an attached `StatusComponent`, never new fields.
- **Composition guardrail.** New components must be blind (zero
  `root.call/get/set`) and configured (`@export`), or the editor-composition
  score falls below baseline (`validate_composition.ps1`). The one hard part is
  the edge-bleed stage, which needs a typed `EffectsSpawner` + rng + pixel-texture
  seam rather than a root handle.
- **Hitstop/DoT recursion.** `damage_actor` sets hitstop, hitstun, flash, and
  triggers the kill path (`slime_actor.gd:202-211`). DoT ticks must bypass it
  (§5.4).
- **Readability first.** Status marks use the authored game palette and must
  remain identifiable at 240×160 in a real combat scene.
- **Presentation ownership.** `ElementAuraComponent` owns status outlines and
  the extracted imbue overlays in this pass. Reconcile the older J6 claim in
  `juice-roadmap.md:208` so a second aura implementation is not introduced.
- **Performance.** Per-actor status presentation runs on the scheduled frame
  path. Edge particles are capped by `EffectsSpawner`; profile simultaneous
  statuses on the Samsung A17. Sprite images and outline textures are cached.
- **Determinism.** Proc rolls use the existing run `rng`, never `randf()`.
- **Presentation identity.** Do not use palette strings as gameplay identity
  (`element_catalog.gd:5`); key off the element id and authored profile.
- **Tuning lives in resources.** Proc chances, tick intervals, magnitudes, and
  cooldowns belong in `resources/tuning/*.tres` and must be indexed in
  `GAMEPLAY_TUNING.md` — no status power hardcoded.
- **Verification surface.** Fold coverage into existing suites; at most one new
  owner test for the `StatusComponent` boundary, registered in `tests/manifest.csv`.
- **Balance isolation.** Status magnitudes are balance changes; keep them out of
  structural refactor patches (`AGENTS.md`, `AUDIT.md` §14).

## 11. Verification requirements

- `StatusComponent`: apply, refresh, stack cap, coexistence, tick damage,
  expiry, room reset, and no re-proc on a DoT tick.
- Proc gate: ineffective and authored-immune hits never proc; both damage
  boundaries are covered; fixed-seed results are deterministic.
- `ElementAuraComponent`: attaches to an arbitrary `Sprite2D`, matches layer
  `z_index`/offset, frees cleanly, reuses cached textures.
- Imbue parity: moving the outline pipeline does not change the current weapon
  imbue render (before/after native-res probe).
- Data-driven proof: an additional status definition and registry entry require
  no per-element combat branch.
- Combatant proof: the player and slime/skeleton actor paths share the status
  mechanism; props are excluded.

## 12. Advisor review record (2026-09-28)

Corrections applied to this document after a Thorn/Pip/Hexley pass:

- **Aura framing corrected.** `player_equipment_visual_component.gd` has zero
  root accesses today (A1 done, `component-composition-design.md:386-397`); the
  extraction is reuse, not composition cleanup. Timer authority stays in
  `MagicRuntimeController`.
- **Status particle direction set by owner.** Burn reuses imbue's upward ember
  trail; Poison, Electric Shocked, and Ice Chill use authored mote, spark, and frost
  styles. Each status resource owns its style and emission interval.
- **One boundary → two.** Enemy→player damage bypasses `damage_actor`; the gate
  needs a second call site.
- **Signature corrected.** The boundary carries `(element, immune)`, not a
  `DamageResult`.
- **DoT recursion flagged.** `source == STATUS` bypass is mandatory.
- **Player state moved to a component.** `GameplayState` fields are frozen.
- **Reset owner corrected.** `MagicRuntimeController.reset_for_room` no-ops by
  default; pooled slimes clear in `reset_runtime_state`.
- **Tick seam corrected.** Enemy DoT in `tick_components`; player beside
  `aspect_ability.tick`.
- **Palette shader corrected** to `shaders/palette_swap.gdshader`.
- **Scope set by owner.** Fire Burn, Shadow Poison, Electric Shocked, Ice Chill;
  Water Wet; Ground none; drain caster and player special deferred (addendum).
- **Readability probe added** as the gating prerequisite.

Sequence and balance guardrails follow Pip's bounded plan; the M1 dependency and
verification-surface freeze remain in force.
