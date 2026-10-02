# Tiny Demons — Elemental Spell Forms Plan

Status: P1–P7 are implemented in source. All planned delivery types now have
runtime paths. Balance values and visuals remain provisional until a focused
Godot playtest. Spell forms still use the interim code registry, not M1-authored
`.tres` definitions.

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

Current code resolves the bound/current form before Chroma is spent and freezes
the current aspect as the payload for the cast. The form chooses delivery,
damage factor, cost, and cooldown; the payload chooses damage type, status,
palette, and impact particles. A low Chroma bar no longer swaps an elemental
form to the neutral stub: it rejects the cast until the selected form's cost is
available. Paying exactly that cost is allowed and can reduce Chroma to zero.
Spell hits guarantee payload status while melee and the sword beam retain their
chance-based proc. Shadow Hex also applies a separate visible damage mark.

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
and looks the same for every player. It is the spell of a player with no
elemental identity. Low Chroma does not select this form for an elemental
player.

### 1.2 Chroma / binding resolution rules

The neutral stub still requires at least one Chroma and spends none. Elemental
casts require their selected form's full cost; an exact-cost cast is accepted
and can empty the bar. Below cost, the cast is rejected without changing the
selected form or spending Chroma.

Without debug-unlimited Chroma, no paid elemental cast starts at zero. The
neutral stub also requires a positive bar; it never consumes Chroma.

| Binding / identity | Chroma | Form selected | Triangle result | Payload |
| --- | --- | --- | --- | --- |
| Unbound, neutral | ≥ 1 | Stub | Casts for free | Neutral, no status |
| Unbound, neutral | 0 | Stub | Rejected | — |
| Unbound, elemental | ≥ cost | Current element's form | Casts; exact cost may empty the bar | Current element |
| Unbound, elemental | 1–cost−1 | Current element's form | Rejected; no substitute spell and no spend | Current element |
| Bound | ≥ cost | Bound form | Casts; exact cost may empty the bar | Current element, or bound element if current is NONE |
| Bound | 1–cost−1 or 0 | Bound form | Rejected without debug-unlimited Chroma; no substitute spell and no spend | Current element, or bound element if current is NONE |

Binding's payoff is the **form**: a bound demon keeps its own form whenever it
has an elemental identity, and an unbound demon's form follows the element it
currently holds. The form stays selected at low Chroma, but Triangle does
nothing until the full cost is available. The neutral stub is reserved for a
player with no elemental identity.

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
| `PROJECTILE_SPLASH` | Travels, directly hits its first enemy, then splashes nearby targets for reduced damage | On-hit AoE query + radius and secondary-damage ratio |
| `CONE` | Fire's frontal area sweep is sampled at the cast frame; hits all bodies in the arc | Cone/polygon query, arc VFX |
| `INSTANT_TARGET` | Electric only: no travel; resolves against the locked/nearest target at the cast frame | Target resolve + sky/ground VFX |
| `BEAM` | Short-lived tether; ticks damage while connected; feeds the player | Beam geometry + tick + link VFX |
| `RADIAL_SELF` | Point-blank ring at the player; hits all bodies in radius | Radial query + ring VFX |

The existing orb is `PROJECTILE`; the existing sword beam is a separate
weapon path and is untouched by this plan. The proposed
`ElementalAbilityDefinition.delivery` enum
(`elemental-ability-and-status-system.md:124`) is the shared ancestor of this
table; reconcile names when that definition is implemented.

## 4. The spells

Numbers below are **first-pass playtest defaults**. They currently live on the
typed definitions created by `SpellFormCatalog`; move them to M1-discovered
`.tres` definitions when that authoring slice can own this content. These
values have not yet been accepted through runtime playtesting.

### 4.1 Summary

| Element | Form | Delivery | Chroma | Cooldown | Damage factor | Payload status | Role |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| Neutral | Stub | `PROJECTILE` | 0 (needs ≥1) | 2.5 s | 1.10x | none | baseline |
| Fire | Cinder Cone | `CONE` | 15 | 3.0 s | 1.35x | Burn | front crowd burst |
| Water | Tide Burst | `PROJECTILE_SPLASH` | 10 | 2.0 s | 0.85x direct | none | traveling bubble-pop AoE; secondary hits deal 50% of direct spell damage |
| Electric | Skyfall | `INSTANT_TARGET` | 10 | 1.2 s | 1.15x | Stun | priority target, tempo |
| Grass | Leechvine | `BEAM` | 10 | 2.5 s | 0.40x per tick | none | sustain / drain |
| Shadow | Hex | `PROJECTILE` | 12 | 2.5 s | 1.10x | Poison | hex-sigil curse projectile; debuff / amp |
| Ground | Quake | `RADIAL_SELF` | 12 | 2.5 s | 0.75x | none | panic / crowd reset |
| Ice | Frostbite Shard | `PROJECTILE` | 10 | 2.2 s | 1.00x | Slow | control / kiting |

### 4.2 Stub — Neutral (`PROJECTILE`)

Homing or facing-aimed, Neutral damage, and no status. Castable at ≥ 1 Chroma
and costs nothing. This is only selected when the player has no elemental
identity; it does not replace an elemental form when Chroma is low.

### 4.3 Fire — Cinder Cone (`CONE`)

- **Identity:** burst, aggression, expensive commitment.
- **Behavior:** at the cast frame, a horizontal left/right arc (~90°, ~2.5
  tiles) is sampled. Diagonal input chooses its horizontal side; vertical input
  uses the player's remembered facing. **The cone never angles at a target** —
  this is the only form whose aim is discarded, and it is what makes Fire read
  as a lateral breath rather than a homing sweep. Every other form keeps its
  aimed vector. The cast sprite re-faces to the resolved side so the player and
  the plume agree.
  Every enemy body polygon intersecting the arc takes damage once. No travel;
  the player is committed and vulnerable for the cast.
- **Aiming contract:** the rule lives in
  `MagicRuntimeController.apply_horizontal_cone_aim` and is applied from **both**
  cast entry points. A tap-and-release cast starts as a GRAY candidate aimed at
  the closest enemy and only selects its form on release, so applying the rule
  only at candidate start left the cone on the raw closest-enemy vector. This is
  the defect the rule's second call site exists to prevent;
  `tests/cone_aim_contract_smoke.gd` drives both paths through the real entry
  point and fails without it.
- **Cast VFX:** one animated fan maps each palette-recolored Hub flame frame
  across the 90° sector, so the cone reads as one continuous flame. Its visible
  edge flares slightly toward the far tip; this art-only flare does not enlarge
  the damage or puzzle-activation sector. Delayed pixel-ember streams flow
  through it and rise with the same palette fade as the game's Burning effect.
- **Source defaults:** 90° arc, 40px reach, 1.35x damage, 15 Chroma, 3.0s
  cooldown.
- **Payload:** Fire → **Burn** on every target hit.
- **Feel:** the highest burst and the highest cost; rewards facing and timing.

### 4.4 Water — Tide Burst (`PROJECTILE_SPLASH`)

- **Identity:** efficiency, control, knockback, area shaping.
- **Behavior:** a glassy bubble travels toward its target; on impact it pops
  into smaller bubbles while a radial AoE (~1.5 tiles) damages and knocks back
  everything in range.
- **Source defaults:** 24px impact radius, 0.85x direct damage, 10 Chroma, 2.0s
  cooldown; 9px bubble projectile at 54px/s for up to 1.25s, with a 0.16s
  minimum travel before collision. On impact, fourteen 4–6px bubbles burst
  outward and upward. The direct target takes full form damage; enemies caught
  only in the splash take 50% of that damage. `bubblesent.ogg` plays once when
  the Water Triangle bubble launches; `bubbleburst.ogg` plays once when it
  reaches a target and pops, not when the projectile expires without a hit.
- **Payload:** Water → no status (ratified status-free).
- **Feel:** the safe, efficient ranged AoE; repositions crowds.

### 4.5 Electric — Skyfall (`INSTANT_TARGET`)

- **Identity:** stun, chaining, targeting, tempo.
- **Behavior:** no projectile. Instantly resolves against the locked target (or
  nearest) with a bolt from above; applies **Stun**. The cast requires a valid
  target. This has the shortest cooldown in the set.
- **Synergy:** lands on the FOCUS/lock target, so the skill layer and the
  element reinforce each other.
- **Deferred:** chaining to further targets is out of scope here (see §9).
- **Implemented in source (P3):** resolves the locked/nearest target at the cast
  frame and applies the payload status. Its 10 Chroma / 1.2s cooldown and
  1.15x damage are the current source defaults. The strike uses a brief,
  stepped pixel bolt from above, aimed at the rendered sprite's top-center,
  with the existing electric sparks as impact support. Stun locks immediately
  on proc, then repeats on its existing cadence with a sprite-only jolt.

### 4.6 Grass — Leechvine (`BEAM`)

- **Identity:** sustain, drain, regeneration, restraint.
- **Behavior:** a short tether that ticks damage into the target and returns HP
  to the player while connected; only accepts a target within range, then ends
  on target death, range break, or expiry.
- **Source defaults:** 64px range, 1.8s duration, 0.45s tick interval, 0.40x
  damage per tick, and healing equal to 40% of damage dealt; no knockback.
- **Payload:** Grass → no status.
- **Feel:** lower burst, high sustain; the survival form.

### 4.7 Shadow — Hex (`PROJECTILE`)

- **Identity:** deception, curse, phase, lifesteal.
- **Behavior:** a curse projectile that applies **Poison** and marks the target
  (amplified damage taken for a short window).
- **Source defaults:** the mark increases later damage by 25% for 3s; 12 Chroma,
  2.5s cooldown, 1.10x projectile damage, and a 5px pixel-art hex sigil for
  the curse projectile.
- **Payload:** Shadow → Poison.
- **Deferred:** a phase/blink movement component is out of scope for this pass.

### 4.8 Ground — Quake (`RADIAL_SELF`)

- **Identity:** defense, armor, stagger, force.
- **Behavior:** a point-blank ring that staggers and knocks back everything
  around the player. Optional: briefly raise a cover block.
- **Source defaults:** 24px radius, 0.75x damage, 0.70x normal magic knockback,
  12 Chroma, 2.5s cooldown.
- **Payload:** Ground → no status.
- **Feel:** the panic button; turns being surrounded into an advantage.

### 4.9 Ice — Frostbite Shard (`PROJECTILE`)

- **Identity:** slow, freeze, preservation, momentum.
- **Behavior:** a shard that applies **Slow**; repeated application stacks
  toward longer control.
- **Source defaults:** five-pixel diamond projectile at 90px/s, 1.00x damage,
  10 Chroma, 2.2s cooldown.
- **Payload:** Ice → Slow.
- **Deferred:** hard "freeze" (full action lock at max stacks) is an optional
  escalation, not part of the first pass.

## 5. Payload rules

- **Status follows the payload element, not the form.** A Water form channeling
  Fire **Burns**, not Wets. This is what makes the cross-product mean anything.
- Status is resolved by `ElementCatalog.status_effect_for_element`
  (`element_catalog.gd:45`). Fire, Shadow, Electric, and Ice resolve a status;
  Water and Ground are deliberately status-free in the ratified ability/status
  authority. Grass currently has no status definition in the catalog, though
  that authority does not explicitly classify Grass.
- **Magic uses the shared status path.** `magic_hit_slime` resolves through
  `damage_slime_with_number` and `try_apply_status`; the spell supplies the
  guaranteed flag while melee and the sword beam retain their proc chance.
  Every delivery preserves that behavior when its payload element has an
  authored status. Water, Grass, and Ground currently have none.
- **Spells guarantee their payload status.** Melee and the sword beam keep their
  chance-based proc
  (0.2, 0.1 for Stun); the spell path applies its status on every successful,
  non-immune hit, so the element is always perceivable. Implemented by
  threading a guaranteed flag from `magic_hit_slime` through
  `damage_slime_with_number` → `try_apply_status` → `StatusApplicationRequest`.
  Status tick damage still never re-procs.
- Color and particles come from the payload element via
  `ElementCatalog.palette_key` and the status's `particle_style`; the form
  supplies the delivery VFX. Magic impacts use distinct pixel shapes and
  motion: Fire embers rise, Water droplets arc and fall, Electric sparks burst,
  Grass leaves lift, Shadow motes drift, Ground chips fall, and Ice crystals
  burst outward.
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
projectile_shape   ORB | SHARD | DROPLET | HEX | BUBBLE
projectile_size / projectile_speed / projectile_lifetime / minimum travel time
delivery_radius / splash secondary damage ratio / delivery_angle_degrees / delivery_range / delivery_duration
tick_interval / lifesteal_ratio / knockback_multiplier
mark_duration / mark_damage_multiplier
```

These are the typed fields used by the current source registry. Authored VFX and
audio keys such as `impact_style`, `cast_sfx`, and `hit_sfx` remain future M1
definition fields; runtime presentation currently uses the existing effect and
sound owners.

Registry target: `resources/definitions/spell_forms.tres` (or one `.tres` per
form), discovered through the M1 catalog/manifest pipeline the same way enemy
definitions are. Current source uses the typed `SpellFormCatalog` code registry;
do not edit duplicate tuning constants elsewhere.

**Resolution (single decision point):**

```text
identity = bound_aspect if bound else current_aspect
form     = form_for(identity) if identity exists else neutral_stub
payload  = current_aspect, or bound_aspect when current_aspect is NONE
cast     = identity exists ? chroma >= form.cost : chroma > 0
# An unaffordable elemental form is rejected; it never changes to the stub.
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
| Projectile records / AoE | `magic_projectile_controller.gd` (carry the selected typed form; delivery reads its radius and projectile values) |
| Payload data | `element_catalog.gd` / `element_catalog.tres` (element, status, palette) |
| Form data | `SpellFormDefinition` + interim `SpellFormCatalog`; move to M1 discovery/validation when definitions become authored resources |

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
   delivery; proves the no-projectile branch. **Implemented in source**
   (provisional bolt VFX).
4. **P4 — Water Tide Burst** (`PROJECTILE_SPLASH`). Proves on-hit AoE on the
   projectile record. **Implemented in source**; radius and radial knockback
   read the typed form definition.
5. **P5 — Fire Cinder Cone** (`CONE`). Proves the no-projectile area query and
   per-form VFX. **Implemented in source**; actor polygons are checked against a
   fan sector at the cast frame.
6. **P6 — Ground Quake + Ice Shard + Grass Leechvine + Shadow Hex.**
   **Implemented in source** with radial, shard, tether, and curse-mark behavior.
7. **P7 — Balance and readability pass.** First-pass costs, cooldowns, damage
   factors, and pixel effects are implemented and indexed. **Source pass
   complete;** 240×160 crowd readability and balance ratification still require
   a runtime playtest.

### Source hook audit — 2026-10-01

The input/cast path resolves the selected form and payload before Chroma is
spent, then dispatches through the cast-frame timeline by delivery type. The
shared hit resolver carries elemental damage, guaranteed payload statuses,
knockback, Shadow's mark, and Grass lifesteal. Target-only Skyfall and Leechvine
also resolve a valid target when a cast began in pointer-aim mode. Form-cost
selection respects debug-unlimited Chroma; zero Chroma still rejects casting.

Puzzle torches and the Orb are valid targets, so all deliveries now route them
as object interactions: projectiles and target-only deliveries activate direct
hits, while splash, cone, and radial deliveries query their area. Object hits
change puzzle color and do not enter enemy damage/status handling. This uses
existing puzzle behavior and does not add elemental reactions.

## 8. Verification

- One characterization test per delivery type: cone hits N in the arc and none
  behind; splash hits the impact radius; instant resolves with no travel and
  applies its status; beam drains and ends on break; ring hits all around.
- Selection test: elemental form identity stays stable at zero, below cost,
  exactly at cost, and above cost; below cost rejects without spending or
  falling back, and exactly cost can cast down to zero.
- Water splash test: the traveling bubble collides after its minimum travel
  time, the directly hit enemy receives full form damage, nearby enemies
  receive 50% of the direct spell damage, and the impact emits a bubble burst.
- Target-only forms resolve a valid target from pointer-aim casts; Grass also
  rejects targets outside its range without spending Chroma.
- Puzzle-object routing: direct projectile, instant, and tether hits activate
  the object; splash, cone, and radial areas activate objects in their geometry
  without attempting enemy damage.
- Status-on-magic test: each payload element applies its status on every hit
  (guaranteed); Water, Grass, and Ground apply nothing; DoT ticks do not
  re-proc.
- Guardrail: a grep of the resolver finds no `if element ==`; only `delivery`
  and data lookups. New definition surface stays typed (composition score holds).
- In-editor MCP playtest per form. Do not run the smoke suite from an MCP
  session (per `AGENTS.md`).

Current source pass: form-specific delivery remains distinct. Fire maps the
Hub's animated flame frames into one continuous fan and sends rising pixel
embers through it using the Burning effect's fade. Water travels as a
highlighted bubble, plays its launch cue, then pops into smaller bubbles with
an impact cue while preserving its reduced secondary splash. Electric resolves
instantly under a short pixel bolt aimed at the target sprite's top-center;
Stun starts with an immediate lock and gives enemies a sprite-only jolt during
lock windows. Payload impact particles remain element-specific. These effects
have not yet received a rendered playtest; confirm 240×160 readability when a
Godot runtime session is available.

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

- **O** Ratify or tune the per-form costs, cooldowns, and damage factors in §4.1
  after playtesting; the listed values are provisional source defaults.
- **O** Confirm Grass remains status-free or define an ailment for it. The
  current catalog has no Grass status; the status authority names Fire, Shadow,
  Electric, and Ice as status-bearing, and Water/Ground as status-free.
- **Resolved in source:** when a bound player has `current_aspect == NONE`, use
  the bound element for both the selected form and payload.
- **Resolved in source:** each guaranteed successful spell hit adds one status
  stack, up to that status definition's cap.
- **O** Form VFX budget at 240×160 — verify all seven deliveries stay readable
  under a full crowd and HUD.

## 11. References

- [`game-design-document.md`](game-design-document.md) §5 (element system),
  §5.2 (element identities), Pillars 1 and 4.
- [`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
  — shared status pipeline, `ElementalAbilityDefinition`, no-per-element-branch
  rule, status scope (Fire Burn / Shadow Poison / Electric stun / Ice slow;
  Water and Ground status-free; Grass currently has no catalog status).
- [`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md)
  — status runtime and presentation.
- [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md)
  — element identities and interaction principles.
- [`authoring-system-plan.md`](authoring-system-plan.md) — definition/registry/
  validator pipeline the `SpellFormDefinition` must follow.
