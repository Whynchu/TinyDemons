# Freeze — Water + Ice Mixture Status Design

Status: implemented in source; runtime acceptance pending
Scope: a single authored element-pair reaction producing a new `freeze` status
Current owners: `status_effect_definition.gd` (status data contract),
`element_catalog_data.gd` (status registry), `status_application.gd` (application),
`status_component.gd` (runtime records and multipliers),
`effects_spawner.gd` / `element_aura_component.gd` (presentation)
New owners introduced by this design: `status_mixture_definition.gd` (the pair
table), `status_mixture_controller.gd` (the lookup that fires it)

## Goal

Water and Ice applied to the same actor combine into **FREEZE**: a short, total
freezing that locks the target in place and multiplies the damage it takes for
as long as it lasts.

This is a single hard-coded pair on purpose. It is the first mixture, not the
first of a reaction system — see [Scope boundary](#scope-boundary).

## Motivation

Two of the eight elements are water-bearing and the game has no way to express
them interacting. Ice currently arrives only as `chill`, a plain movement slow
owned by the Ice element (`status_chill.tres`), and Water arrives as `wet`, an
ambient modifier that conducts Electric and extinguishes burn
(`status_wet.tres`, consumed at `status_component.gd:293-305` and `:59-60`).
Neither knows the other exists. A player who soaks an enemy and then freezes it
is doing something the game currently cannot see, and the Ice element is
systematically weak in the mid-game for it — a slow is worth much less than a
burst window against a boss.

Freeze also gives the defensive Water play a payoff. Soaking yourself before a
boss slam is currently pure defense; the same read against an Ice element is
currently a dead end.

## Design

### The mixture

| Field | Value |
| --- | --- |
| Ingredients (unordered) | `WATER` + `ICE` |
| Product | `freeze` |
| Proc | guaranteed when both ingredients are present on the same actor |
| Consumed | both ingredient statuses (`wet`, `chill`) are removed and replaced by `freeze` |
| Duration | 3.0 s, refreshed (not stacked) on re-application |
| Effect | movement locked, incoming damage +25% |

The reaction is symmetric and order-independent: `wet` then `chill` and
`chill` then `wet` both freeze.

Consuming the ingredients is what keeps the reaction from looping and what
makes it a real decision rather than a stacking bonus. Re-freezing costs two
casts.

### Why a new status family is required

Before this implementation, `StatusEffectDefinition.Family` was a closed five-value enum
(`status_effect_definition.gd:5-11`) with no vulnerability member, and
`StatusComponent.incoming_damage_multiplier_for` (`:286-295`) only ever computes
`1.0 + bonus` — it is amplification-only by construction. `DAMAGE_AMPLIFICATION`
is wired to the same read, so it cannot be reused with inverted semantics without
making the field a lie.

Add one family:

```
Family.DAMAGE_VULNERABILITY
```

with `vulnerability_per_stack` (default 0.25) and its `validate()` branch
alongside the `AMBIENT_MODIFIER` one at `:69-83`, plus the
`@export_enum` string at `:19`. `StatusComponent` then folds it into a second
multiplicative read at `incoming_damage_multiplier_for`, keeping
`damage_taken_multiplier` untouched so DoT ticks are unaffected by design.

### `freeze` is a status condition, not an element

This is settled, not a proposal. `freeze` is not cast, never appears in the
matchup table, has no palette, and no player choice ever produces it directly.
It is a condition that arises on an actor when two other conditions are present.

It does, however, need an element field for presentation, and cannot own one:
`chill` already holds index 7, and `element_catalog_data.gd:33-35` rejects two
statuses on one element. Resolution: **`freeze` is an auxiliary status carrying
element `ICE` purely as a tint key.**

### Frozen definition

`FREEZE` is a **status condition on an actor**, never a ninth element. It has
no cast, no matchup row, no palette, and no player choice that produces it
directly — it arises when `wet` and `chill` are present on the same actor at the
same time.

It replaces those two conditions: both ingredients are removed when `freeze`
is applied. The target is no longer wet and no longer chilled; it is frozen,
until `freeze` expires. The ingredients are the cost of the reaction, which is
what stops it re-triggering on its own and makes setting it up a real decision.

Concretely this means:

- `freeze` goes in `AUXILIARY_STATUS_IDS` (`status_effect_definition.gd:14`),
  the escape hatch for conditions that are not element-owned.
- The uniqueness check at `element_catalog_data.gd:33-35` is relaxed to apply
  only to non-auxiliary ids. A chill and a freeze may both be element 7; two
  passive element statuses still may not.
- `element = 7` is a **tint key only**, not an ownership claim. It makes
  presentation free: `element_aura_component.gd:136-154` tints from the
  element, `hud_controller.gd:531-...` tints badges, and
  `effects_spawner.gd:1007-1011` picks the particle texture.
- Freeze authors `extinguishes = [&"burn"]`; status extinguishing is now applied
  from any definition that names extinguished statuses. Wet continues to use
  the same shared behavior. The WATER and ICE ingredients are separately
  consumed by the mixture controller.

Rejected alternative: a ninth `Element.FROST = 8`. That touches
`element_catalog.gd:12-21`, `element_catalog_data.gd:16`, three hard-coded
`0..7` export ranges (`status_effect_definition.gd:18, 35, 48, 70`), the authored
matchup table, and every palette lookup — and it would imply Frost is a castable
element, which it is not.

### The pair table

New `scripts/content/status_mixture_definition.gd`, a sibling of
`StatusEffectDefinition`, holding `first_element`, `second_element`,
`result_status_id`, `guaranteed`, and `consumes_ingredients`, plus
`validate()` rejecting self-pairs, neutral elements, and unregistered results.

Registered as `@export var status_mixtures: Array[Resource]` on
`ElementCatalogData` (`element_catalog_data.gd:13`) **next to** `status_effects`,
not as a parallel table, per the single-registry rule in
`elemental-ability-and-status-system.md:117-118`. `AspectCatalog.FUSION_RECIPES`
(`aspect_catalog.gd:27-32`) is explicitly *not* the home for this: that table
converts two flames into one persistent aspect identity for the hub, and is not
a combat reaction table.

### Delivery seam

`StatusApplication.apply` resolves the definition as
`request.definition_override if != null else ElementCatalog.status_effect_for_element(request.element)`
(`status_application.gd:14`). That override channel is the proven, narrow
insertion point — transmission already uses it
(`status_transmission_controller.gd:66-79`).

New `status_mixture_controller.gd` owns the reaction:

1. Called from `StatusApplication.apply` after any successful application, so
   both combat hits and contact-transmitted statuses can complete a pair.
2. Collects the actor's active APPLIED status elements (`:13`,
   `status_record.gd:39`). The innate status counts as one of the two
   ingredients — this is what makes a Water slime freezeable by a single Ice
   cast, and an Ice slime wetted by a single Water cast.
3. Looks up the unordered pair in the registry. One dictionary hit. If no
   authored pair matches, return immediately.
4. On a match, applies the registered product, then strips applied ingredient
   records. An innate ingredient remains configured and is hidden by Freeze's
   applied-status suppression until Freeze expires.

Anti-spam is inherent: the ingredients are consumed, so a re-freeze needs two
more casts. No new cooldown is required, and none should be added.

Because `StatusComponent` is one class attached as the `Status` node to both
player and slimes, and `StatusApplication.apply` has no actor-type branch, this
works symmetrically on both sides with no per-side code. That matches the
standing rule in `elemental-ability-and-status-system.md:80-81` — a status must
not test what kind of actor it is on.

### Movement lock and action behavior

`freeze` reads as total. Its explicit `MOVEMENT_LOCK` family returns a zero
movement multiplier. Chill's slow floor cannot express a full stop (its lower
bound is 0.1, and its authored floor is 0.55), so Freeze does not overload the
slow parameters. The lock affects player motor and slime navigation while
leaving attack speed at normal, as recommended below.

The original movement-only decision is superseded by the 2026-10-05 combat
update: Freeze still leaves `attack_speed_multiplier()` unchanged, but Slime
actors pause attack updates while Freeze is active. The current and legacy
Slime tick paths share this lock, and boss phases that resist movement locks
also resist Freeze's attack lock. Player Freeze remains governed by the player
control path; this update specifically prevents enemies from attacking.

Runtime enforcement also stops movement already in progress: an active slime
scoot is canceled, Skeleton's direct-walk path is guarded, and attack lunges,
knockback, and actor-separation pushes cannot displace a locked target. Enemy
attack animation and hit resolution pause at their current frame and resume
after Freeze expires. Boss phases that resist movement locks continue to use the existing combat resistance
callback.

### Presentation

- `PARTICLE_STYLES` (`:15`) gains `&"ice_shard"`, plus the matching arm in the
  pixel-pattern `match` at `effects_spawner.gd:1007-1011` — the `_:` default
  means a missing arm silently renders nothing.
- `badge_glyph` on the definition; `hud_controller.gd:531-...` composites it.
- Element 7 tint is inherited, so the aura at `element_aura_component.gd:136-154`
  needs no new art, only a distinct badge glyph to tell freeze from chill.
- Wet and Freeze use the requested `W` and `F` badge glyphs. The world-space
  status outline is a top-level sibling at one depth step behind the actor;
  player, enemy, and NPC setup share the same `ElementAuraComponent` path.

## Numbers, and why they are provisional

- Duration 3.0 s — two normal attack cycles, short enough that a miss feels
  earned rather than wasted.
- Vulnerability +25%, `maximum_stacks = 1` with duration refresh rather than
  stacking — stacking would need a rising curve and a hard cap decision that
  the first version does not need.

Both live in `resources/tuning/status_freeze.tres` and should be tuned in
playtest before anything else in this doc is considered finished. Tune duration
first; vulnerability second.

## Scope boundary

`combat-and-dungeon-design-principles.md:81-83` says "do not build a universal
elemental-reaction simulator," and `elemental-ability-and-status-system.md:74-79`
defers reactions to a separate system. This design is compatible with both
because it is a **lookup, not a simulation**:

- One authored pair. Not a rule engine, not order-dependent resolution, not
  chained intermediates.
- No new call sites on the damage path. All four damage boundaries already read
  `StatusComponent` (`combat_runtime_controller.gd:104-108`, `:648-651`,
  `slime_actor.gd:301-304`, `actor_status_runtime_controller.gd:50-52`).
- No change to `actor_collision_system.gd` contact capture.
- No change to `AspectCatalog.FUSION_RECIPES`.

If a second pair is ever added, that is the moment to re-open the question of
whether this should be a table at all. Document the two systems separately:
this doc should be titled *mixture*, never *fusion*, to stop readers assuming
`aspect_catalog.gd` is extensible here.

## Interaction with existing statuses

Unspecified today and now load-bearing: `elemental-ability-and-status-system.md:74`
states the statuses may coexist, and `:245-249` has no exclusivity groups.

Decide and record:

| Coexisting with | Proposed |
| --- | --- |
| `wet` | consumed by the mixture, so never coexists |
| `chill` | consumed by the mixture, so never coexists |
| `burn` | freeze **extinguishes** burn (reuse `extinguishes`, `:39`) |
| `shocked` | unaffected; a frozen target is still conductive |
| `poison` | unaffected |

`freeze` being consumed-by-freeze is not an interaction; but a frozen actor must
still be able to be *shattered* by a follow-up hit, which is a follow-up proposal,
not this one.

## Acceptance criteria

1. `wet` then `chill` and `chill` then `wet` both produce `freeze` on the same
   actor, on either side (player or slime).
2. The reaction does not fire without both ingredients, and does not fire for any
   pair not in the table.
3. `freeze` is removed on expiry and `wet` and `chill` are gone at that moment
   (consumption, not co-existence).
4. A frozen actor moves at the floor multiplier and deals normal damage.
5. Incoming damage to a frozen actor is multiplied by 1.25, for both
   player→slime and slime→player boundaries, and for `chill`/`wet`-freeze and
   innate-water-freeze alike.
6. Status DoT ticks are unaffected by `freeze`.
7. `freeze` does not appear in `damage_taken_multiplier()`.
8. Bosses: `freeze` applies and its vulnerability works; its movement lock
   respects the existing boss gate.
9. Presentation: `freeze` shows a badge glyph and edge particles distinct from
   `chill`, and element 7 tint.

## Verification

The status system's existing tests are **registered but unrun** —
`status_component_smoke`, `status_combat_smoke`, `status_transmission_smoke` are
all `state = unverified` in `tests/manifest.csv`, and
`elemental-affinity-and-transmission-plan.md` says the same in prose. Before
building on that baseline, run them standalone with no MCP Godot editor attached
and get them to `verified`. A new feature on an unexecuted foundation is how
this bug class gets shipped.

Then:

- New `tests/status_mixture_smoke.gd` covering criteria 1-3 and the ordering
  symmetry, with a table-driven case per authored pair.
- Extend `tests/status_combat_smoke.gd` for criteria 4-8.
- `tools/validate_definitions.ps1` for the registry and `validate()` changes.

**Validator boundary:** status `.tres` files live in `resources/tuning/` and
are not individually discovered by the definition manifest. The authored
`element_catalog.tres` references them, and its `ElementCatalogData.validate()`
walks and validates every registered status and mixture. Keep Freeze registered
there so the existing definition validator reaches its contract.

## Risks

- **Bosses are the most interesting freeze target** and also the one with the
  least existing test coverage. Verify criterion 8 explicitly.
- **Freeze on the player is strong.** It is a guaranteed proc from two
  commonly-cast elements with a +25% damage window. If it dominates boss fights,
  the lever to pull is `duration`, not `vulnerability`; shorten the window rather
  than making it unreliable.
- **The element-index relaxation is a real semantic change** to registry
  validation, not a local hack. It is scoped to auxiliary statuses, but review
  it deliberately — `element_catalog_data.gd:33-35` currently protects a genuine
  invariant for passive statuses.
- **Naming.** "Fusion" already means element→element identity change in
  `aspect_catalog.gd`. Keep this system named *mixture* everywhere, including
  the `FUSION_RECIPES` neighbors, or the next reader will try to extend the
  wrong table.

## Implementation record (2026-10-04)

The authored WATER + ICE pair is registered on `ElementCatalogData` beside
`status_effects`. `StatusMixtureController` runs after every successful status
application, consumes applied Wet/Chill, and applies the auxiliary `freeze`
status; innate Wet remains beneath its suppression. The shared world-space
status outline renders below player, enemy, and NPC sprites. Freeze has a dedicated
movement-lock family, a 25% direct damage vulnerability family, a three-second
single-stack definition, burn extinguishing, an ice-shard particle, and the
`F` badge. Wet's badge is `W`. Test source covers symmetric order, innate Wet,
consumption, movement, vulnerability, and expiry. The focused smoke is
registered but unrun, so runtime acceptance remains pending.

## Related

- `docs/elemental-slimes-and-combat-plan.md` — owning feature plan; add the
  mixture rule to its composition section.
- `docs/elemental-ability-and-status-system.md` — status contract; `:74-79`
  and `:245-249` are the exclusivity passages this design makes load-bearing.
- `docs/combat-and-dungeon-design-principles.md:81-83` — the non-goal this
  design is scoped to respect.
- `docs/elemental-binding-and-fusion-design.md` — element→element fusion, a
  different system.
