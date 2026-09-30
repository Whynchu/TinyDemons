# Tiny Demons — Elemental Spell Forms Plan

Status: active plan; P1 (guaranteed spell proc) and P2 (form/payload seam) are
implemented in source, with every form still on the projectile delivery;
per-element deliveries (P3+) are not.

Scope: the player's Triangle spell. One **form** per element plus a neutral
stub. Binding selects the form; the current element selects the payload
(damage type, status, color, particles). This document defines every spell we
intend to build, the selection rules, the delivery model, and the build
sequence. It does not cover the shared status pipeline (owned by
[`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md))
or environmental reactions (a separate, deferred system).

Owner: `PlayerAspectAbilityComponent` (acceptance, cost, cooldown),
`MagicRuntimeController` + `MagicRuntimeContext` (cast timeline and delivery),
`PlayerChromaComponent` (binding, current aspect, ability mode), `ElementCatalog`
(payload: element, status, palette), and the authoring pipeline for the
`SpellFormDefinition` registry.

Current code: all eight elements fire one uniform homing orb; the element only
changes the palette, the matchup, and the resulting status proc
(`magic_runtime_controller.gd:220`, `:473`, `:649`). **Elemental magic already
rolls the payload status**: `magic_hit_slime` resolves through the shared
`damage_slime_with_number`, which calls `try_apply_status` on any non-immune
elemental hit (`magic_runtime_controller.gd:668`;
`combat_runtime_controller.gd:113-116`). P1 has since made **spells guarantee**
that status (melee keeps its roll). What remains missing is *behavior* — the
delivery is identical for every element, and cost/cooldown are uniform
(`player_chroma_component.gd:112`, `player_aspect_ability_component.gd:34`).

Verification: focused magic smokes (`imbue_spell_scene_smoke`,
`chroma_projectile_scene_smoke`) plus in-editor MCP playtest per form. The
resolver must branch on **delivery**, never on element id.

Supersedes: none. It operationalizes the player-ability portion of
[`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
and the element identities in
[`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md).
It preserves the Chroma/Binding contract in
[`game-design-document.md`](game-design-document.md) §5 and the no-per-element-
branch rule in the ability/status authority.

## 1. The idea

Today "element" is a paint job on one spell. The fix is not eight bespoke
functions; it is to split the spell into two orthogonal axes:

- **Form** — *how* the spell is delivered (cone, splash orb, instant strike,
  beam, shockwave). This is the element's **class identity**.
- **Payload** — *what* the spell deals (damage type, status, color, particles).
  This is the **run's element**.

**Binding selects the form. The current element selects the payload. Unbound
players collapse the two (form follows the current element).**

The payoff: a Water-bound demon who takes a Fire flame casts the *Water form*
(splash orb) carrying a *Fire payload* — a burning splash. Binding stops being a
50-Soul tax and becomes the thing that lets your technique stay constant while
your element changes. Seven forms × seven payloads is a large spell space from a
small authored set — "massively tiny" delivered rather than described.

### 1.1 The neutral stub

The neutral stub is **exactly today's Triangle orb**. It is not discarded; it
becomes the identity-less baseline. It deals Neutral damage, applies no status,
and looks the same for every player. It is the fallback for an unbound player
with no affordable element, and the spell of a neutral player.

### 1.2 Chroma / binding resolution rules

No free cast at zero. The stub already requires at least one Chroma and spends
none (`player_aspect_ability_component.gd:47`; GRAY never spends in
`try_activate`). That gate is preserved.

**Nothing casts at zero Chroma, bound or unbound.** There is no zero-Chroma
spell of any kind.

| Binding | Chroma | Mode | Form | Payload |
| --- | --- | --- | --- | --- |
| Unbound, neutral | ≥ 1 | GRAY | Stub | Neutral, no status |
| Unbound, neutral | 0 | — | no cast | — |
| Unbound, elemental | ≥ cost | ELEMENTAL | Current element's form | Current element |
| Unbound, elemental | 1–cost−1 | GRAY | Stub | Neutral, no status |
| Unbound, elemental | 0 | — | no cast | — |
| Bound | ≥ cost | ELEMENTAL | Bound form | Current element |
| Bound | 1–cost−1 | GRAY | Stub | Neutral, no status |
| Bound | 0 | — | no cast | — |

Binding's payoff is the **form**, not a zero-Chroma cushion: a bound demon uses
its own form whenever it can cast at all, and an unbound demon's form follows the
element it currently holds. Below the elemental cost, everyone falls back to the
neutral stub; at zero, no one casts.

`BOUND_WEAKENED` is no longer a cast state. It remains only as a presentation
state (the bound element desaturates at zero Chroma) and never produces a spell.
`magic_attack_element`'s `BOUND_WEAKENED → NEUTRAL` branch (`magic_runtime_controller.gd:649`)
is therefore inert for casting and needs no change.

## 2. Design rationale

- **Serves Pillar 1** ("your demon is an element") and **Pillar 4** ("small
  rules, deep combinations") from [`game-design-document.md`](game-design-document.md).
- **Gives Binding a mechanical payoff** — the missing half of the element
  fantasy.
- **Reuses shipped systems**: the 5-frame cast timeline, the projectile
  controller, the status pipeline, `EffectsSpawner` particles, and the Chroma
  resource. No new verbs and no new resource.
- **One input, one resource, eight (×7) outcomes** — density without surface
  growth.

## 3. The delivery model

A form's behavior is its **delivery type**. The resolver interprets deliveries
generically; the element only supplies payload and numbers. This is the
reconciliation with the "no per-element behavior branch" rule: the resolver may
switch on `delivery`, but never on element id.

| Delivery | Behavior | Generic pieces it needs |
| --- | --- | --- |
| `PROJECTILE` | Travels; optional homing; single-target on contact | Existing projectile record |
| `PROJECTILE_SPLASH` | As `PROJECTILE`, plus a radial AoE on impact | On-hit AoE query + radius on the record |
| `CONE` | Instant frontal sector sampled at the cast frame; hits all bodies in the arc | Cone/polygon query, arc VFX |
| `INSTANT_TARGET` | No travel; resolves against the locked/nearest target at the cast frame | Target resolve + sky/ground VFX |
| `BEAM` | Short-lived tether; ticks damage while connected; feeds the player | Beam geometry + tick + link VFX |
| `RADIAL_SELF` | Point-blank ring at the player; hits all bodies in radius | Radial query + ring VFX |

The existing orb is `PROJECTILE`; the existing sword beam is a separate
weapon path and is untouched by this plan. The proposed
`ElementalAbilityDefinition.delivery` enum
(`elemental-ability-and-status-system.md:124`) is the shared ancestor of this
table; reconcile names when that definition is implemented.

## 4. The spells

Numbers below are **initial playtest defaults**, to live in
`resources/tuning/*.tres` and be indexed in `GAMEPLAY_TUNING.md` — never
hardcoded.

### 4.1 Summary

| Element | Form | Delivery | Chroma | Cooldown | Payload status | Role |
| --- | --- | --- | ---: | ---: | --- | --- |
| Neutral | Stub | `PROJECTILE` | 0 (needs ≥1) | 2.5 s | none | baseline |
| Fire | Cinder Cone | `CONE` | 15 | 3.0 s | Burn | front crowd burst |
| Water | Tide Burst | `PROJECTILE_SPLASH` | 10 | 2.0 s | none | ranged AoE control |
| Electric | Skyfall | `INSTANT_TARGET` | 10 | 1.2 s | Stun | priority target, tempo |
| Grass | Leechvine | `BEAM` | 10 | 2.5 s | none | sustain / drain |
| Shadow | Hex | `PROJECTILE` | 12 | 2.5 s | Poison | debuff / amp |
| Ground | Quake | `RADIAL_SELF` | 12 | 2.5 s | none | panic / crowd reset |
| Ice | Frostbite Shard | `PROJECTILE` | 10 | 2.2 s | Slow | control / kiting |

### 4.2 Stub — Neutral (`PROJECTILE`)

Today's Triangle orb, unchanged. Homing or facing-aimed, modest damage, no
status, Neutral damage, grey. Castable at ≥ 1 Chroma and costs nothing. This is
the canonical form the other seven are measured against.

### 4.3 Fire — Cinder Cone (`CONE`)

- **Identity:** burst, aggression, expensive commitment.
- **Behavior:** at the cast frame, a frontal arc (~90°, ~2.5 tiles) is sampled.
  Every enemy body polygon intersecting the arc takes damage once. No travel;
  the player is committed and vulnerable for the cast.
- **Payload:** Fire → **Burn** on every target hit.
- **Feel:** the highest burst and the highest cost; rewards facing and timing.

### 4.4 Water — Tide Burst (`PROJECTILE_SPLASH`)

- **Identity:** efficiency, control, knockback, area shaping.
- **Behavior:** travels like the orb; on impact, a radial AoE (~1.5 tiles)
  damages and knocks back everything in range.
- **Payload:** Water → no status (ratified status-free).
- **Feel:** the safe, efficient ranged AoE; repositions crowds.

### 4.5 Electric — Skyfall (`INSTANT_TARGET`)

- **Identity:** stun, chaining, targeting, tempo.
- **Behavior:** no projectile. Instantly resolves against the locked target (or
  nearest) with a bolt from above; applies **Stun**. The shortest cooldown in
  the set.
- **Synergy:** lands on the FOCUS/lock target, so the skill layer and the
  element reinforce each other.
- **Deferred:** chaining to further targets is out of scope here (see §9).

### 4.6 Grass — Leechvine (`BEAM`)

- **Identity:** sustain, drain, regeneration, restraint.
- **Behavior:** a short tether that ticks damage into the target and returns HP
  to the player while connected; ends on target death, range break, or expiry.
- **Payload:** Grass → no status.
- **Feel:** lower burst, high sustain; the survival form.

### 4.7 Shadow — Hex (`PROJECTILE`)

- **Identity:** deception, curse, phase, lifesteal.
- **Behavior:** a curse projectile that applies **Poison** and marks the target
  (amplified damage taken for a short window).
- **Payload:** Shadow → Poison.
- **Deferred:** a phase/blink movement component is out of scope for this pass.

### 4.8 Ground — Quake (`RADIAL_SELF`)

- **Identity:** defense, armor, stagger, force.
- **Behavior:** a point-blank ring that staggers and knocks back everything
  around the player. Optional: briefly raise a cover block.
- **Payload:** Ground → no status.
- **Feel:** the panic button; turns being surrounded into an advantage.

### 4.9 Ice — Frostbite Shard (`PROJECTILE`)

- **Identity:** slow, freeze, preservation, momentum.
- **Behavior:** a shard that applies **Slow**; repeated application stacks
  toward longer control.
- **Payload:** Ice → Slow.
- **Deferred:** hard "freeze" (full action lock at max stacks) is an optional
  escalation, not part of the first pass.

## 5. Payload rules

- **Status follows the payload element, not the form.** A Water form channeling
  Fire **Burns**, not Wets. This is what makes the cross-product mean anything.
- Status is resolved by `ElementCatalog.status_effect_for_element`
  (`element_catalog.gd:45`). Fire, Shadow, Electric, and Ice resolve a status;
  **Water and Ground are deliberately status-free** and return null — consistent
  with the ratified set in the ability/status authority and its non-goals.
- **Magic already reaches the status path.** `magic_hit_slime` resolves through
  `damage_slime_with_number`, which proc-gates status on any non-immune
  elemental hit (`combat_runtime_controller.gd:113-116`). No wiring is needed for
  the single-target orb; the work is to keep that path intact as multi-hit
  deliveries land, so cone, splash, ring, and beam apply the status per target
  they hit.
- **Spells guarantee their payload status.** Melee keeps its chance-based proc
  (0.2, 0.1 for Stun); the spell path applies its status on every successful,
  non-immune hit, so the element is always perceivable. Implemented by
  threading a guaranteed flag from `magic_hit_slime` through
  `damage_slime_with_number` → `try_apply_status` → `StatusApplicationRequest`.
  Status tick damage still never re-procs.
- Color and particles come from the payload element via
  `ElementCatalog.palette_key` and the status's `particle_style`; the form
  supplies the delivery VFX.
- **Reactions are not in this plan.** Water↔Fire extinguish, Wet-conduct, etc.
  belong to the deferred environmental/object system
  (`elemental-ability-and-status-system.md:74`), not the spell path.

## 6. Data model and architecture

**`SpellFormDefinition` (new, typed Resource)** — one per form (8 total):

```text
id                 stable StringName (stub, fire, water, ...)
native_element     Element id (the form's home; also its default binding)
delivery           PROJECTILE | PROJECTILE_SPLASH | CONE | INSTANT_TARGET | BEAM | RADIAL_SELF
chroma_cost        int
cooldown           float (seconds)
damage_multiplier  float (replaces the GRAY/ELEMENTAL constants)
delivery_params    speed, lifetime, size, arc_angle, radius, beam_length, tick_interval
impact_style       presentation preset key
cast_sfx / hit_sfx audio keys
```

Registry: `resources/definitions/spell_forms.tres` (or one `.tres` per form),
discovered through the M1 catalog/manifest pipeline the same way enemy
definitions are. Until M1 closes, register through the existing
`ElementCatalogData`-style single registry to avoid a parallel table.

**Resolution (single decision point):**

```text
cast    = chroma >= cost                         # else stub (>=1) or no cast (0)
form    = bound ? form_for(bound_aspect) : form_for(current_aspect)  # stub when no element
payload = element_for(current_aspect)
deliver(form.delivery, payload)
```

`deliver` is the only switch, and it switches on `delivery` — never element.

**Owning files:**

| Concern | Owner |
| --- | --- |
| Acceptance, cost, cooldown | `player_aspect_ability_component.gd` (extend to read form cost/cooldown; pass element or a resolver) |
| Binding / current | `player_chroma_component.gd` (`ability_mode`, `current_aspect`) |
| Cast timeline + delivery | `magic_runtime_controller.gd` (`execute_current_aspect_ability`, `_spawn_pending_magic_projectile`) |
| Context plumbing | `magic_runtime_context.gd` (form/payload fields + callables) |
| Projectile records / AoE | `magic_projectile_controller.gd` (add an optional on-hit radius to the record) |
| Payload data | `element_catalog.gd` / `element_catalog.tres` (element, status, palette) |
| Form data | new `SpellFormDefinition` + registry + validator |

## 7. Build phases

Sequenced so the balance change (status on magic) and the structural change
(the form/payload seam) stay separate.

1. **P1 — Guarantee the spell proc.** Thread a guaranteed flag so spells apply
   their payload status on every hit; melee keeps the chance-based proc. The
   shared path already reaches status (`combat_runtime_controller.gd:113-116`),
   so this is a small, additive change, not new wiring. *This is the identity
   mechanism.* **Implemented in source.**
2. **P2 — Form/payload seam, behavior-neutral.** Introduce `SpellFormDefinition`
   with all eight forms mapped to the existing `PROJECTILE`, and make the
   resolver select form by binding and payload by current element. All eight
   still fire the orb; existing smokes must still pass. **Implemented in source**
   (`spell_form_definition.gd`, `spell_form_catalog.gd`); the registry
   instantiates the forms in code as an interim until M1 carries them as `.tres`.
3. **P3 — Electric Skyfall** (`INSTANT_TARGET`). Smallest genuinely new
   delivery; proves the no-projectile branch.
4. **P4 — Water Tide Burst** (`PROJECTILE_SPLASH`). Proves on-hit AoE on the
   projectile record.
5. **P5 — Fire Cinder Cone** (`CONE`). Proves the no-projectile area query and
   per-form VFX.
6. **P6 — Ground Quake + Ice Shard + Grass Leechvine + Shadow Hex.** Remaining
   deliveries; each is now mechanical.
7. **P7 — Balance and readability pass.** Tune costs, cooldowns, and form VFX;
   verify each form reads at 240×160 with a full crowd and HUD.

## 8. Verification

- One characterization test per delivery type: cone hits N in the arc and none
  behind; splash hits the impact radius; instant resolves with no travel and
  applies its status; beam drains and ends on break; ring hits all around.
- Selection test: bound vs unbound × chroma bands (0 / 1–cost−1 / ≥cost) picks
  the form and payload in §1.2.
- Status-on-magic test: each payload element applies its status on every hit
  (guaranteed); Water and Ground apply nothing; DoT ticks do not re-proc.
- Guardrail: a grep of the resolver finds no `if element ==`; only `delivery`
  and data lookups. New definition surface stays typed (composition score holds).
- In-editor MCP playtest per form. Do not run the smoke suite from an MCP
  session (per `AGENTS.md`).

## 9. Non-goals and deferred

- **Environmental reactions** (Water extinguishes Fire, Wet conducts Electric) —
  separate authored-object system, not this path.
- **Chaining** for Electric beyond the single target — deferred.
- **Phase/blink** for Shadow, **cover wall** for Ground, **hard freeze** for Ice
  — optional escalations.
- **A generalized enemy-side ability resolver** — enemy support abilities are
  owned by `SlimeSupportComponent` and the shared ability/status authority.
- **No new `GameplayState` fields**, no `_process()`, no per-element branches.

## 10. Open decisions

- **O** Exact per-form cost/cooldown numbers (defaults in §4.1 are proposals).
- **O** Bound player with `current_aspect == NONE`: confirm the payload defaults
  to the bound element (recommended) rather than Neutral.
- **O** Whether the guaranteed spell proc should apply full stacks every hit, or
  one stack per hit up to the cap (current status stacking already caps).
- **O** Form VFX budget at 240×160 — verify the six deliveries stay readable
  under a full crowd.

## 11. References

- [`game-design-document.md`](game-design-document.md) §5 (element system),
  §5.2 (element identities), Pillars 1 and 4.
- [`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
  — shared status pipeline, `ElementalAbilityDefinition`, no-per-element-branch
  rule, status scope (Fire Burn / Shadow Poison / Electric stun / Ice slow;
  Water and Ground status-free).
- [`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md)
  — status runtime and presentation.
- [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md)
  — element identities and interaction principles.
- [`authoring-system-plan.md`](authoring-system-plan.md) — definition/registry/
  validator pipeline the `SpellFormDefinition` must follow.
