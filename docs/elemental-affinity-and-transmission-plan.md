# Elemental Affinity and Transmission Plan

Status: implementation in source; pure-text checks passed, gameplay acceptance open
Scope: Give the weapon imbue its per-element look, add a real `wet` status, give
enemies an innate element affinity with presentation-only suppression, allow
bidirectional contact transmission, and constrain room generation to synergistic
elemental mixes usually with two and sometimes three non-Normal enemy elements
across each run and each room, including supports that all heal their allies.
Plan author: space-bunny; implementation: codex; owner-directed behavior choices recorded 2026-10-03
Review: codex, owner-requested corrections recorded 2026-10-03. Slice numbers
are retained for coordination; shipping dependencies are clarified below.
Current code: five element-owned statuses (`burn`, `poison`, `chill`, `shocked`, `wet`), auxiliary `freeze`, typed applied/innate `StatusRecord`s, and bidirectional contact transfer limited to Wet, Burn, Chill, Shocked, and Freeze. Poison is explicitly excluded from contact transfer.
Verification: focused component/transmission/theme smoke coverage is registered but has not been run. Both pure-text composition modes and `git diff --check` pass. Godot script/definition/catalog checks, runtime combat and native 240x160 readability, seed sweep, and browser playtest remain outstanding.
Supersedes: nothing. Extends
[`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
and its execution plan
[`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md).

## Current implementation checkpoint — 2026-10-03

S1–S7 are implemented in source: typed status records and deterministic
presentation; innate affinity/suppression; Wet mechanics and shared bubbles;
weapon-sprite imbue particles with reserved particle capacity and occlusion-cache
revision keys; bidirectional pre-separation contact transmission; saved seeded
run themes; elemental healer variants that all use shared ally healing; and
legacy active-run roster migration. S8 updates this plan, owner docs, tuning,
authoring guidance, focused component/transmission/theme smoke coverage, and the
manifest. Both composition modes and `git diff --check` pass. No Godot smoke,
editor diagnostics, runtime playtest, seed sweep, or browser run has been
performed in this implementation turn.
## 1. Summary

This began as a narrow presentation request: give the weapon imbue the elemental
look that today only appears on status victims, and add a bubble-based `wet`
treatment for Water. Discussion widened it into a status and affinity system. The
two halves are tracked separately below because they can and should ship
separately — the presentation work is low-risk and independently valuable, while
transmission is the highest-risk item in the whole feature.

Owner follow-up: runs usually select two non-Normal enemy elements and sometimes
three, with a hard cap of three. Synergistic combinations are preferred, and
elemental support variants all heal. This supersedes the original room-only cap
and the proposal to make damage-table compatibility a mandatory roster rule.

| # | Slice | Risk | Independently shippable |
| --- | --- | --- | --- |
| S1 | `StatusRecord` conversion + staged `wet` schema | low | mechanical conversion ships alone; Wet activation waits for S3/S4 |
| S2 | Innate affinity, own-element immunity, suppression | medium | requires S1; Water acceptance waits for Wet activation |
| S3 | `wet` mechanics (conduct / extinguish) | low | requires S1; completes Wet activation with S4 |
| S4 | Bubble particle style | low | visual helper ships alone; Wet activation requires S3 |
| S5 | Imbue element emission from the weapon sprite | medium | yes |
| S6 | Contact transmission | **high** | yes, but gated on S1-S3 |
| S7 | Saved run theme (usually two, sometimes three elements), room rosters and healing supports | medium | requires supported theme selection, support authoring and snapshot migration |
| S8 | Docs, tuning, test debt | low | — |

## 2. Ratified owner decisions

Recorded 2026-10-03. These are settled; the plan implements them as written.

1. **One aura owner.** `ElementAuraComponent` renders every elemental overlay.
   A second aura implementation is forbidden
   (`docs/ARCHITECTURE.md:104-105`,
   `docs/elemental-ability-and-status-system.md:309-310,362-364`).
2. **The imbue look emits from the weapon sprite, not the character body.**
   Owner wording: "the imbue wraps around the sprite of the WEAPON. always has,
   always should." The existing imbue outline and flash on the weapon gear layers
   are correct and are not modified.
3. **Reuse existing status particle styles.** Fire `ember`, Ice `frost_crystal`,
   Electric `electric_spark`, Shadow `poison_mote`. Water gets bubbles. Grass,
   Ground and Normal get nothing for now and must fall back cleanly.
4. **`wet` is a real fifth status** with two halves: it conducts electricity and
   it extinguishes player-applied burn.
5. **Innate status never affects its own owner.** Suppression is
   presentation-only **and** stops transmission.
6. **Transmission is bidirectional and element-agnostic.** The debuff comes from
   whichever actor is carrying it, not from the matchup table. The only bound is
   a per-pair cooldown.
7. **Enemy avoidance AI is deferred.** The substitute is generation-side
   placement.
8. **Chroma tracks HP loss.** The elemental enemy's 20-point Chroma pool drains
   with its health and is exhausted when it dies. There is no separate living
   state at zero Chroma to design for. This feature adds no depletion mechanic
   or Chroma-based affinity switch.
9. **Usually two, sometimes three non-Normal enemy elements per run and room.**
   Select the run's allowed elements once; every enemy roster draws from that
   set. Normal does not count. The hard cap is three across both the whole run
   and each room, including supports, bosses, summons and respawns. A room may
   use fewer than the run's theme; teaching policy may choose a Normal-only or
   single-element run.
10. **Favor synergistic run pairs where possible.** Prefer useful authored
    interactions, such as Water/Wet conducting Electric/Shocked. Synergy is a
    selection preference, while the three-element limit is mandatory. Damage
    matchup resistance alone neither proves nor disproves status synergy.
11. **Every support heals its friends.** Healing is the common support role,
    independent of element. Supports use the existing ally-healing behavior and
    may heal allies of either allowed element or Normal. Their element controls
    appearance, affinity and status interactions; it does not replace healing
    with a different ability. Author elemental healer variants so supports draw
    from the run's allowed set rather than introducing Grass into every run.

## 3. Corrections to earlier assumptions

Recorded because they change the work, and because two of them were stated
wrongly in discussion before being checked.

- **The bubble sounds are already wired.** `water_bubble_sent` and
  `water_bubble_burst` are registered in `scripts/sound_clip_catalog.gd:28-29`,
  exposed in `scripts/sound_mix_profile.gd:65-66,124-125`, warm-loaded by
  `scripts/sound_manager.gd:108`, and played at
  `scripts/magic_runtime_controller.gd:1110,1411`. They are **not** available
  for `wet` to claim. If `wet` wants audio it needs its own cue.
- **A bubble visual already exists.** `_magic_bubble_texture`
  (`scripts/magic_runtime_controller.gd:1296`) generates it procedurally, with
  `spawn_magic_bubble_pop` (`:803`), a burst (`:828-831`), projectile wobble
  (`scripts/magic_projectile_controller.gd:136-143`), and
  `SpellFormDefinition.ProjectileShape.BUBBLE`
  (`scripts/spell_form_definition.gd:18`, used by the Water form at
  `scripts/spell_form_catalog.gd:52`). `wet` should reuse this visual idiom
  rather than author a parallel one. S4 should extract the shared idiom rather
  than call across the magic runtime from the status path.
- **Enemy selection lives in `scripts/room_controller.gd`.** The weighted pool
  is built at `room_controller.gd:209-252` and the single weighted pick is
  `EncounterDefinition.select_weighted_variant` at `:271`, defined at
  `scripts/encounter_definition.gd:66-75`. `room_enemy_spawn_services.gd` has
  no selection logic.
- **`scripts/element_catalog.gd:741-758` is about vault gate requirements**, not
  enemy element composition.
- **`strongest_active_definition()` breaks stack ties by insertion order**
  (`scripts/status_component.gd:131-144`). Equal-stack outcomes therefore depend
  on application history. This is not evidence of spontaneous frame-to-frame
  flicker. S1 must establish a deterministic presentation order: applied records
  before innate, stacks descending, then status id ascending.
- **The matchup table never blocks a status.** Every value in
  `element_catalog.tres` is `0.25`, `0.8`, `1.0` or `1.25`; there are no zeros,
  so the documented rule that effectiveness of zero prevents application
  (`docs/elemental-ability-and-status-system-addendum.md`, H2) never fires from
  the table. What actually prevents a fire slime from burning is immunity. This
  is why decision 6 is coherent: element already does not gate status.
- **`scripts/gameplay_state.gd` has zero headroom** — 1718 lines against a 1719
  max and 286 fields against a 286 max
  (`tools/validate_composition.ps1:43,95-96`). Nothing in this feature may touch
  that file, including the obvious-looking status seam around
  `gameplay_state.gd:1294-1319`.

## 4. Non-goals

- No enemy steering or avoidance behaviour. Rationale: ally-avoidance in tight
  rooms risks stuck actors and can break boss behaviour, and there is no
  navigation layer to build it on. Generation-side placement gets most of the
  benefit for none of the risk.
- No new per-element presentation table. See §5.1 — the existing status registry
  is already keyed by element and supplies the style, so a second table would be
  the "fifth parallel table" the authoring plan warns against
  (`docs/authoring-system-plan.md`).
- No change to the matchup table. `tests/element_catalog_smoke.gd:12-21` pins the
  8x8 grid and is a `gate` row; tuning Water's row later needs its own slice.
- No audio for `wet` in the first pass.
- No silhouette fill or wrap on the character body. The earlier tinted-fill
  direction was dropped when the owner confirmed the imbue belongs on the weapon.

## 5. Data model

### 5.1 Where the imbue's element look comes from

The element look is read through the **existing** status registry:

```text
imbue element -> ElementCatalog.status_effect_for_element(element)
              -> definition.particle_style
              -> EffectsSpawner style branch (art + motion)
```

Fire resolves to `burn`/`ember`, Ice to `chill`/`frost_crystal`, Electric to
`shocked`/`electric_spark`, Shadow to `poison`/`poison_mote`, and — once S1 lands
— Water to `wet`/`bubble`. Grass, Ground and Neutral resolve to `null` and emit
nothing. This is why decision 3's "Grass, Ground and Normal get nothing" needs no
fallback table, and it is why `wet` had to be a real status rather than a
cosmetic entry: the look is a consequence of the status existing.

Cost of this coupling: if an element ever needs a status look the imbue should
not use, a per-element override flag is required. Not needed now; noted for
future.

### 5.2 `StatusEffectDefinition`

`scripts/status_effect_definition.gd:5-14` currently declares
`enum Family { DAMAGE_OVER_TIME, MOVEMENT_SLOW, PERIODIC_STUN,
DAMAGE_AMPLIFICATION }`, `STATUS_IDS` of four ids, and `PARTICLE_STYLES` of four
styles.

```gdscript
enum Family {
    DAMAGE_OVER_TIME,      # 0
    MOVEMENT_SLOW,         # 1
    PERIODIC_STUN,         # 2
    DAMAGE_AMPLIFICATION,  # 3
    AMBIENT_MODIFIER,      # 4 NEW — no tick, no slow, no stun, no damage of its own
}

const STATUS_IDS: Array[StringName] = [&"burn", &"poison", &"chill", &"shocked", &"wet"]
const PARTICLE_STYLES: Array[StringName] = [&"ember", &"poison_mote", &"electric_spark", &"frost_crystal", &"bubble"]

@export_group("Ambient modifier")
## Incoming element whose hits this status amplifies. A data field, not a branch.
@export var conducts_element := 0
@export_range(0.0, 4.0, 0.05) var conduct_damage_bonus_per_stack := 0.0
@export_range(1.0, 4.0, 0.05) var conduct_stun_cadence_divisor := 1.0
## Status ids removed when this status is applied.
@export var extinguishes: Array[StringName] = []
@export_range(0, 10, 1) var extinguish_stacks_per_application := 3
## Whether contact may pass this status to another actor.
@export var transmissible := false
```

`validate()` (`scripts/status_effect_definition.gd:34`) must gain an
`AMBIENT_MODIFIER` block requiring `conducts_element` in
`1..element_count-1` **or** a non-empty `extinguishes`, and must reject non-default
conduct/extinguish configuration on other families. Keep the base Resource
defaults neutral (zero bonus, cadence divisor one, no conducted element or
extinguished ids), so existing four-status resources still validate. Wet sets
its proposed bonus and divisor explicitly. Validate extinguished ids and positive
stack-removal counts whenever that list is non-empty. A mistyped or half-configured
ambient status should fail loudly, not silently do nothing. Note the existing
family bound check at `:40` is an explicit range test rather than an enum
membership test, so it must be widened rather than merely appended to, and the
`PARTICLE_STYLES` membership check at `:61` is where `bubble` must be admitted.

Two knock-on effects:

- `scripts/element_catalog_data.gd:36-38` currently asserts
  `status_effects.size() != STATUS_IDS.size()` with the message "must contain all
  four registered definitions". Adding `wet` breaks the message and pins a count.
  Replace the size pin with a set comparison against `STATUS_IDS`.
- `_status_particle_texture` (`scripts/effects_spawner.gd:1219`) falls back to a
  solid 1px `["p"]` for an unknown style, and `StatusEffectDefinition.validate()`
  rejects styles outside `PARTICLE_STYLES`. There is no clean fallback. S4 should
  make an unknown style return `null` — `spawn_actor_status_particle` already
  returns on a null texture (`:1159`) — so a missing style means *no particle*
  rather than a solid dot.

### 5.3 `StatusRecord` (new)

`scripts/status_component.gd:19-27` stores a `Dictionary` per status with no
origin, no suppression and no provenance. Transmission and innate affinity both
need those, so S1 converts the record into a typed `RefCounted`:

```gdscript
# scripts/status_record.gd
extends RefCounted
class_name StatusRecord

enum Origin { APPLIED, INNATE }

var definition: StatusEffectDefinition = null
var origin: int = Origin.APPLIED
var remaining := 0.0
var stacks := 1
var source_element := 0
var tick_timer := 0.0
var cadence_timer := 0.0
var initial_stun_pulse_pending := false
## Derived presentation label for an innate record's current suppressor.
## Never the source of truth for whether suppression continues.
var suppressed_by: StringName = &""
var arrived_by_transmission := false
```

`_active` becomes `Dictionary[StringName, StatusRecord]`. Because it is keyed by
status id, an innate and an applied record of the same id can never coexist —
which is correct, because own-element application is rejected upstream (§5.6).

### 5.4 `StatusComponent` API additions

```gdscript
signal suppression_changed(innate_id: StringName, suppressor_id: StringName, is_suppressed: bool)
signal transmission_received(status_id: StringName, from_actor: Node)

var innate_status_id: StringName = &""

func configure_innate(status_id: StringName) -> void
## Room/spawn reset: remove applied effects and restore configured affinity.
func reset_for_spawn() -> void
## Death/disposal: clear active records; retain configured affinity for pooled reuse.
func clear_all() -> void
func record_for(status_id: StringName) -> StatusRecord
func is_suppressed(status_id: StringName) -> bool
## Applied records first (stacks descending), then unsuppressed innate records.
func presentation_definitions() -> Array[StatusEffectDefinition]
func strip_statuses(ids: Array[StringName], stacks_per_application: int = 999) -> int
func transmissible_records() -> Array[StatusRecord]
## Product of APPLIED AMBIENT_MODIFIER records conducting `element`.
func incoming_damage_multiplier_for(element: int) -> float
func conduct_stun_cadence_divisor() -> float
```

`presentation_definitions()` replaces `active_definitions()` as the presentation
source in `scripts/element_aura_component.gd:178` and both HUD paths
(`scripts/hud_controller.gd:498,690`). `strongest_active_definition()` must select
from this same ordered, suppression-aware list. In S1 the new seam introduces
no affinity or suppression behavior.

### 5.5 `resources/tuning/status_wet.tres`

Provisional first-pass values; they are tuning proposals, not evidence.

```text
id            = &"wet"
element       = 2 (WATER)
family        = 4 (AMBIENT_MODIFIER)
proc_chance   = 0.25
duration      = 3.0
maximum_stacks = 2
conducts_element = 3 (ELECTRIC)
conduct_damage_bonus_per_stack = 0.35
conduct_stun_cadence_divisor   = 1.5
extinguishes  = [&"burn"]
extinguish_stacks_per_application = 3
transmissible = true
badge_glyph   = "~"
particle_style = &"bubble"
particle_interval = 0.22
```

Appended to `status_effects` in
`resources/definitions/element_catalog.tres`.

### 5.6 `EnemyDefinition` — no new authored field

`scripts/enemy_definition.gd:20` already carries `element: int`. The innate
status is therefore **derived**, not authored:

```gdscript
# scripts/element_catalog.gd
static func innate_status_id_for_element(element: int) -> StringName:
    var definition := status_effect_for_element(element)
    return definition.id if definition != null else &""
```

`scripts/enemy_factory.gd:60-62` gains one line calling
`status_component.configure_innate(...)` with that result. Grass, Ground and
Neutral return `""` and arm nothing, with no element branch anywhere.

Own-element immunity is enforced in `scripts/status_application.gd` beside the
existing `status_immunities` check (`:18`), as
`definition.id == component.innate_status_id`, and repeated inside
`StatusComponent.apply_effect` because transmission (S6) makes that a second
entry point. Both are id comparisons against a field.

Authored `status_immunities` (`enemy_definition.gd:39`, validated against
`STATUS_IDS` at `:105-111`) continue to work unchanged and now accept `&"wet"`.
Recommended: `configure_innate` declines to arm when the innate id is also
authored-immune, so "immune to my own aura" means no aura rather than an
invisible one. This is a judgment call and must be documented in
`docs/GAMEPLAY_TUNING.md`.

### 5.7 `EncounterDefinition`

`scripts/encounter_definition.gd` gains composition limits and a preference flag:

```gdscript
@export_range(1, 3, 1) var max_run_elements := 3
@export_range(1, 3, 1) var max_distinct_elements := 3
@export_range(0.0, 1.0, 0.05) var three_element_run_chance := 0.20
@export var synergy_enabled := true
```

Validate both limits in `1..3`. The room limit cannot exceed the run limit, and
disabling synergy preference cannot disable either cap. Normal run selection
chooses two elements; `three_element_run_chance` adds a third where eligible.
The proposed 0.20 chance is a tuning starting point, not a ratified balance
value; seed sweeps and playtests should set it. Teaching policy can select fewer.
The saved run theme contains one to three unique non-Normal element ids, chosen
from eligible enemy and healer content; it is runtime run data, not a mutable
definition property.

`default_data()` loads the authored `.tres` (`:15-16`). Duplicate that definition
before `_encounter_definition()` changes its runtime `matchup_policy`; another
`load()` or `preload()` of the same path still returns the cached resource and
does not isolate it. The guard compares two separate properties, but mutation
of shared data can couple controllers and runs.

## 6. Systems

### 6.1 Innate affinity and suppression

An enemy with element FIRE has innate burn. It is immune to burn, so it is never
actually burning — the innate record is an identity marker, an aura, and a
transmission source.

- **Immunity** is enforced at the gate (§5.6). Innate never applies its own
  effects to its owner.
- **Innate lifecycle**: all innate records, suppressed or visible, are permanent
  identity records. `advance()` never ages them or produces damage/stun results
  from them. Movement, attack-speed, damage-amplification and Wet conductivity
  queries inspect only APPLIED records. Innate Water therefore never amplifies
  damage to its own owner. `strip_statuses()` removes only applied records.
- **Spawn and death**: `SlimeActor.reset_runtime_state()` currently calls
  `clear_all()` after factory setup, which would erase affinity. S2 changes that
  call to `reset_for_spawn()`, restoring the configured innate record after
  clearing applied effects. Death/disposal continues to call `clear_all()`.
  Verify reused slots whose variant is unchanged as well as newly configured
  slots: room entry now skips redundant variant configuration.
- **Suppression**: affinity is suppressed while any admitted APPLIED record with
  a different id remains. Recompute this after application, refresh, removal,
  extinguishing and expiry. Choose `suppressed_by` from the deterministic
  presentation order for signaling only; expiry of one suppressor must not
  restore affinity while another remains. Emit the out/back tell only when the
  suppression boolean changes. Innate stacks and timers remain untouched.
- **Presentation** is one seam: `presentation_definitions()` filters suppressed
  innate records, so the aura outline, the status particles and both HUD badge
  sets all stop in one place.
- **Transmission stops** while suppressed, which is the mechanic that gives
  suppression teeth: soaking a fire slime opens a window where it can neither
  burn you nor pass burn on. Note the trade — `wet` is itself transmissible, so
  you convert a fire threat into a wet threat.
- **The tell**: `suppression_changed` fires two one-shot particle bursts from the
  silhouette edge in the innate element's colour, one out and one back. This is
  the whole "dry off" moment and it needs no new art.

### 6.2 `wet` mechanics

Both halves resolve inside `StatusComponent`, which is why no per-element branch
exists.

- **Amplify electric damage**: `incoming_damage_multiplier_for(element)` scans
  `AMBIENT_MODIFIER` records whose `conducts_element == element` and multiplies
  `1.0 + conduct_damage_bonus_per_stack * stacks` alongside the existing
  `damage_taken_multiplier()` (`:173`). Call sites, where the attack element is
  already in scope: `scripts/combat_runtime_controller.gd:100-103`,
  `scripts/slime_actor.gd` (enemy to player), and the tick path at
  `combat_runtime_controller.gd:762`.
- **Amplify electric stuns**: the cadence is computed inside `advance()` from
  `definition.stun_interval_for(stacks)` (`scripts/status_component.gd:84`, and
  again at `:99`). Divide by `conduct_stun_cadence_divisor()` and clamp to the
  existing interval floor, so the interaction stays inside the loop that already
  owns stun cadence.
- **Strip burn**: at the end of `apply_effect`, for an admitted
  `AMBIENT_MODIFIER` record, call
  `strip_statuses(definition.extinguishes, definition.extinguish_stacks_per_application)`.
  Against a fire enemy the burn is innate and suppressed rather than applied, so
  the extinguish is a no-op there and suppression does the work instead — which
  is consistent, not a gap.

### 6.3 Contact transmission

Bidirectional and element-agnostic for the explicit transferable set only:
Wet, Burn, Chill, Shocked, and auxiliary Freeze. Poison is a deliberate special
case: it never passes on contact, even if a resource flag is accidentally set.

**Rule 1 — direction.** Both directions, always. The player is a vector like any
other actor.

**Rule 2 — innate transmits.** A fire slime you touch burns you. This is the
intended identity behaviour, and own-element immunity (§5.6) is what stops it
compounding, because a fire slime can never be burned by another fire slime.

**Rule 3 — suppression blocks transmission.** A suppressed innate record is not
transmissible.

**Rule 4 — per-pair cooldown.** The only bound.
`TRANSMISSION_PAIR_COOLDOWN := 3.0 s` regardless of how many statuses the pair
carries. One unordered actor-pair key schedules a batch containing both
directions. Start the cooldown on an eligible attempted batch, including batches
rejected by immunity or special defenses, so repeated frame contacts cannot
reapply a status every frame. Contact does not reroll the status proc chance.
Actors with no eligible source records do not consume an attempt. Instance IDs survive pooled reuse:
clear cooldowns on room changes and include a spawn generation in each actor's
pair identity for respawns within a room. Prune stale entries.

**Rule 5 — everything still gates.** Transmission routes through
`StatusApplication.apply` with a new
`StatusApplicationRequest.SourceKind.CONTACT_TRANSMISSION`
(`scripts/status_application_request.gd:4-7`) and `guaranteed_proc = true`. The
request carries the actual immutable status definition, not just its element;
ordinary elemental hits retain the element-to-definition lookup. The target's
authored immunities, its innate own-element immunity, boss
invulnerability, boss stun resistance, the neutral rejection and the
`effectiveness <= 0` check all still apply. The `STATUS_TICK` guard at
`status_application.gd:8` is untouched. Snapshot eligible source records for all
contact pairs before applying any transfer, so newly received effects cannot
bounce back or cascade through another pair in the same frame. Transfer one
normal application of each eligible status, using its configured duration and
stack cap rather than sharing mutable records or copying the donor's full stack
count. Ordinary elemental hits retain the definition's proc chance; contact
transmission does not roll it a second time.

The runtime allowlist is authoritative and the resource flag is an additional
opt-in. Explicitly set `transmissible = true` on Burn, Chill, Shocked, Wet, and
Freeze; keep Poison false. New statuses do not transmit until both the allowlist
and their resource flag are updated. Successful transfer sets provenance on
the receiving record. The badge ring remains until that record expires or is
removed, even if a later ordinary hit refreshes it.

**Rule 6 — eligibility.** Skip dead, spawn-locked and non-visible actors; skip
while the room is not engaged. Reuse the existing guards.

**Rule 7 — adjacency, not enumeration.** Use `slime_grid_candidates`
(`scripts/actor_collision_system.gd:116`) and the existing contact test rather
than the full actor list, to keep this O(n*k) at nine actors. Capture exact
contacts after movement and before separation changes their positions; include
player-enemy contacts as well as enemy-enemy pairs. Pass the resulting contact
snapshot to the transmission controller after capture. A tick beside the early
player status update would see stale geometry and is not the integration point.

**Rule 8 — player-facing tell.** Required, because with bidirectional spread the
player will acquire conditions they did not aim for.
`HudController.status_badge_texture` (`scripts/hud_controller.gd:527-553`) gains
an `arrived_by_transmission` flag that adds a 1px white outer ring, with the flag
included in the cache key (`:531`). A `transmission_received` signal drives a
one-frame flash on the new badge. Audio is deferred.

**Known risk.** A nine-actor room has roughly 36 pairs; at a 3s per-pair
cadence a crowded room can blanket itself in one condition in a few seconds.
That is the intended generosity (owner decision 6), and it makes the 240x160
crowd probe the real acceptance test for S6. If the room turns to mush, raising
the pair cooldown is the cheapest fix and requires no design change.

### 6.4 Two-element run themes, rooms and healing supports

**The run owns the allowed elements.** Choose one, two or three distinct
non-Normal enemy elements once when generating the run, using the run seed and
teaching/rank policy. Usually choose two; sometimes choose three. Save this set with the active run and restore it without
rerolling. Every room's final roster must be a subset of Normal plus this set;
rooms never choose an independent pair. Validate the union across the entire
run, since separately capped rooms could otherwise introduce many elements.
Player spells and attunements are outside this enemy-roster constraint.

**Synergy is preferred, not mandatory.** Pair selection should favor actual
authored status interactions. Water + Electric is the first concrete example:
Wet conducts electric damage and increases Shocked cadence. Preserve legal
single-element and Normal-only teaching runs. If no synergistic pair is eligible,
choose an eligible pair without inventing an interaction; still enforce the
hard limit of three. Turning `synergy_enabled` off disables preference, not limits.
The matchup table remains a damage balance table and must not serve as the sole
synergy test. Pair preferences belong to encounter composition data, not to a
new per-element presentation table. Repeated same-element enemies are legal.

**All enemy creation paths obey the theme.** Apply the allowed set to normal,
special and treasure encounters, support companions, boss rosters and their
summons, popcorn, respawns and authored enemy slots. Existing flame/preferred
variant policies must select within the theme rather than injecting a third
element. Special-room required colors must be planned with the run theme; a
conflicting authored requirement is reported before play rather than waived.
Forced debug-variant encounters may bypass theme selection only as an explicit
non-production diagnostic mode.

**Supports all heal.** Expand the existing support-caster definition/catalog
with elemental healer variants, using the shared `SlimeSupportComponent` healing
behavior. Element and support role are independent: Fire, Water, Electric, Ice,
Shadow, Grass and Ground support variants all heal living allied enemies,
including friends of another allowed element or Normal. Their palette, affinity
and transmitted status match their own element. Do not introduce electric-charge,
shield or hazard abilities as replacements for healing in this slice.

The support pool is filtered to the run's allowed elements before companions
are selected. A Water/Electric run can include Water and Electric healers; a
Fire/Ice run can include Fire and Ice healers. Grass healers occur when Grass is
in the theme. Keep the current heal amount, range, cadence and targeting rules
for the first pass. Distinct healing visuals and casting patterns are later
polish. Reuse the healer actor/artwork with palette treatment and authored
variants; no separate behavior implementation per element. Pair eligibility
must account for healer availability, and enabling a themed run with supports
requires authored healer coverage for its selected elements.

**Completed-roster validation.** Preserve the existing generator's seeded
count/level/support policy where possible, then validate after
`finalize_room_encounter()` has appended support companions. A pure checker
accepts both the completed roster and the saved allowed-element set; it checks
membership and the room cap. A second checker validates the run-wide union,
including boss/summon definitions and cached rooms. Normal is excluded by its
combat element, not by encounter role: a Normal healer is still a support.

If adapting an existing generated roster, use a deterministic replacement pass
with no additional draws from the encounter RNG. Prefer replacements of the
same actor family, support/baseline role and elemental/Normal classification.
Do not fall back to an unfiltered pool or silently turn an elemental enemy into
grey: that would remove a 20-point Chroma carrier. Report seeds for which those
constraints leave no legal replacement. Preserve slot count, levels and flags
when they remain semantically valid; remapping a Shadow ambush or authored
special enemy may require an explicit policy change, so do not promise all flags
are byte-identical without evidence. All intentional changes belong in the
seed-sweep report. Filtering earlier in the generator is also a balance change
because conditional RNG consumption can alter later selections and levels.

**Expected visible change.** R3+ currently permits six or seven elements in its
pool. Restricting the entire run to two changes shipped rosters and support
frequencies; it is intentional and needs a seed sweep. Bosses are included in
the limit, superseding the earlier claim that their rosters are unaffected.
Physical adjacency is no longer the criterion for the type cap: floor placement
cannot authorize a third element. Enemy avoidance AI remains deferred.

**Persistence and legacy snapshots.** Store the allowed set in the typed run/
dungeon owner and serialize it through `ActiveRunSnapshot`; add no field to
`GameplayState`. New rooms and respawns consume the restored set. Existing
snapshots without a theme need an explicit migration policy covering every
cached roster and authored requirement, not just the next generated room.
The earlier 'no save migration' claim is withdrawn. Gate legacy migration on the
owner decision in section 10 and verify slot/runtime-state mapping so health,
Chroma payout, death flags and saved pickups are not reset or duplicated.

### 6.5 Imbue element emission

The existing imbue path is not modified: `ElementAuraComponent.update_imbue_layer`
(`scripts/element_aura_component.gd:63-82`) and
`PlayerEquipmentVisualComponent._update_imbue_overlays`
(`scripts/player_equipment_visual_component.gd:944-964`) stay byte-identical,
including the early return for `NEUTRAL` at `:945` and the
`EquipmentSwordBack`/`EquipmentSwordFront` list at `:958`. Neutral uses that early
return. Grass and Ground retain the existing imbue outline and flash, but their
null status-registry lookup skips the additional particles.

New, inside the single aura owner:

```gdscript
const IMBUE_EMISSION_TAG := &"imbue_element"

func update_imbue_element_particles(delta: float, layer: Sprite2D,
        definition: StatusEffectDefinition, effect_parent: Node2D,
        effects: EffectsSpawner, rng: RandomNumberGenerator,
        pixel_texture: Callable) -> void
func clear_imbue_element_particles() -> void
```

`definition` is resolved by the §5.1 lookup, never by matching on the element
id. The emission source is the weapon layer: `spawn_actor_status_particle`
already works on any `Sprite2D` — it calls `_status_edge_positions(actor)`
(`scripts/effects_spawner.gd:1141`) and positions from `actor.get_rect()`
(`:1154-1156`) — so pass the visible sword layer and nothing new is needed. It
sets `z_index = actor.z_index + 1` (`:1167`), which puts weapon particles one
pixel above the weapon, the same relationship the body aura has.

Persistent tagged emission follows the existing `CHARGE_AURA_TAG` precedent
(`effects_spawner.gd:33`, `update_charge_aura_from_root` at `:337`) and
`clear_effect_particles` (`:1319-1331`). Prefer an optional
`effect_tag_override: StringName = &""` parameter on
`spawn_actor_status_particle` over a second spawn function — smaller diff, one
code path.

**Particle budget.** `MAX_PIXEL_PARTICLES` is 90 (`effects_spawner.gd:55`) and the
overflow behaviour is contradictory: `spawn_actor_status_particle` drops the
**newest** (`:1139-1140`) while `update_pixel_particles` drops the **oldest**
(`:1337-1342`). With one weapon plus up to nine enemies emitting continuously,
that will flicker. Introduce a reserved budget for tagged persistent emitters
and charge it per tag inside `EffectsSpawner`, rather than inventing denser art.

## 7. Slices

The coordination precondition below records the original shared-tree risk. The full implementation now lands the dependent slices together; source edits are complete, but runtime acceptance is still pending.

**Original sequencing note:** this plan was drafted while overlapping local work was active. The coordination gate is resolved in the current source pass; the numbered slices remain useful implementation records, not pending code tasks.

Each slice is independently verifiable. No slice adds a `_process()`, a
`GameplayState` field, or a `root.call/get/set`.

### S1 — `StatusRecord` and the `wet` definition

Files: `scripts/status_record.gd` (new), `scripts/status_component.gd`,
`scripts/status_effect_definition.gd`, `scripts/element_catalog_data.gd`,
`scripts/element_catalog.gd`, `resources/tuning/status_wet.tres` (new),
`resources/definitions/element_catalog.tres`,
`scripts/element_aura_component.gd`, `scripts/hud_controller.gd`,
`tests/status_component_smoke.gd`, `tests/imbue_spell_scene_smoke.gd`,
`tests/manifest.csv`.

Land the mechanical `_active` conversion **first, on its own, with no behaviour
change and no new status**. If that pass is not clean in isolation, the
origin/suppression/provenance fields that S2 and S6 both depend on are being
built on sand.

Then prepare: the new `Family`, the new fields, `STATUS_IDS` and `PARTICLE_STYLES`, the
validator rewording at `element_catalog_data.gd:36-38`, `status_wet.tres`, and
the `presentation_definitions()` seam. Replace the tie-break in
`strongest_active_definition()` with a deterministic order.

The mechanical conversion and presentation ordering can ship first. The Wet
schema/resource/registry changes are a staged activation bundle: land them with
S3 mechanics and S4 bubble rendering, not as an active but incomplete fifth
status. Do not publish a registry whose required-id set and registered resources
disagree. S2 can ship the existing four affinities after the conversion; Water
affinity becomes active only with the complete Wet bundle.

Fix the two broken tests in this slice:

- `tests/imbue_spell_scene_smoke.gd`: the obsolete `imbue_outline_overlays` checks now inspect the shared `ElementAuraComponent` outline dictionary. Its finish path calls `quit()` for both pass and failure. The manifest is marked `unverified` until a named focused run.
- `tests/status_component_smoke.gd`: stale `slow` lookup is now `chill`; coverage also includes Wet, innate affinity, conductivity, suppression, pooled-affinity restoration, and cadence changes while Shocked is already active. The check is registered and remains unrun.

Acceptance: `script_check` clean on every changed script;
`validate_composition.ps1` floor and `-RequireTargets` unchanged; a scene probe
reads the complete six-status registry and
`ElementCatalog.DATA.validate().is_empty()`. At Wet activation, additionally
require `ElementCatalog.status_effect_for_element(2).id == &"wet"` and both
S3/S4 acceptance bars. Verify equal-stack presentation is independent of
application order and Shadow Poison remaining non-transferable like every other
Poison status; only Wet, Burn, Chill, Shocked, and Freeze may transfer.

### S2 — Innate affinity and suppression

Files: `scripts/enemy_factory.gd`, `scripts/status_application.gd`,
`scripts/status_component.gd`, `scripts/element_aura_component.gd`,
`scripts/hud_controller.gd`, `scripts/slime_actor.gd`.

`EnemyFactory` arms the innate status from the existing `element` field. Gate
immunity in `status_application.gd` and again in `apply_effect`. Implement
permanent harmless innate records, derived suppression, spawn reset, and the
`suppression_changed` tell. All mechanics queries must exclude innate records.

Acceptance: a Fire slime retains innate Burn beyond the normal status duration
without self damage, rejects applied Burn, and accepts Chill unless separately
authored immune. Two overlapping applied debuffs keep affinity suppressed until
both are gone. Spawn reset restores affinity, including unchanged reused
variants; death clears the active aura record and a reused slot restores its
configured affinity on spawn reset. Grass/Ground/Neutral show no aura. After Wet activation,
a Water slime shows its aura, loses it when shocked, regains it after suppression,
and receives no conductivity bonus from innate Wet.

### S3 — `wet` mechanics

Files: `scripts/status_component.gd`, `scripts/combat_runtime_controller.gd`,
`scripts/slime_actor.gd`.

Acceptance: scripted probe — one wet stack plus an electric hit shows the
amplified damage number; two stacks scale again; a shocked target's stun cadence
tightens by the divisor and never falls below the interval floor; applying wet
to a burning target leaves zero applied burn stacks and the aura clears in the
same `status_changed`. Innate Burn is retained and suppressed rather than
stripped. Damage probes cover melee, spell and enemy-to-player paths; cadence
probes cover adding and removing Wet while Shocked is already active. Activate
the staged Wet registry/resource changes only when S4 rendering is also ready.

### S4 — Bubble particle style

Files: `scripts/effects_spawner.gd`, `scripts/magic_runtime_controller.gd`
(idiom extraction only), `scripts/bubble_visuals.gd` (new shared procedural
helper), `resources/tuning/status_wet.tres` (staged until activation).

Extract the bubble visual idiom from `_magic_bubble_texture`
(`magic_runtime_controller.gd:1296`) into a shared procedural helper rather than
reaching across the magic runtime from the status path. Give bubbles a slow rise
and a long lifetime, deliberately distinct from `poison_mote`'s fast rise so the
two sustained-upward styles stay tellable apart at 240x160. Make an unknown
particle style return `null` instead of the solid-dot fallback.

Acceptance: the generated texture is visibly a bubble ring, not the fallback
pixel; Water spell bubbles retain their right-side highlights and sound behavior.
At the S1/S3/S4 activation boundary, `status_wet.tres` and the registry validate.

### S5 — Imbue element emission from the weapon sprite

Files: `scripts/element_aura_component.gd`,
`scripts/player_equipment_visual_component.gd`,
`scripts/effects_spawner.gd`, `scripts/occlusion_renderer.gd`.

**Coordination gate resolved:** the prior aura-alignment pass is incorporated in the current implementation. Keep the visual acceptance bar below open until a native-resolution playtest is available.

Add the emission methods, the tag, and the reserved particle budget. Fix the
occlusion cache defect first: `occlusion_renderer.gd:602-604` mutates a
**reused** `occluded_actor_textures[actor]` ImageTexture in place, so its RID
never changes and both `_sprite_cache_key`
(`element_aura_component.gd:305-309`) and
`effects_spawner._status_sprite_cache_key` (`:1258-1262`) never miss. Add a
revision counter to the renderer and include it in both keys, or the weapon edge
mask is computed once from whatever occlusion state existed at first use.

Acceptance: a native 240x160 playtest capture shows the weapon outline and flash
unchanged against a pre-slice reference, embers rising from **sword** pixels with
none from the body, the same for Ice/Electric/Shadow, bubbles on the sword for
Water, and an unchanged outline-only look for a Grass imbue. While in that
playtest, attempt to reproduce the unresolved transient magenta rectangle
(`docs/KNOWN_ISSUES.md:649-652`) and record the result either way.

### S6 — Contact transmission

Files: `scripts/status_transmission_controller.gd` (new),
`scripts/status_component.gd`, `scripts/status_application_request.gd`,
`scripts/status_application.gd`, `scripts/slime_actor.gd`,
`resources/tuning/status_burn.tres`, `status_poison.tres`, `status_chill.tres`,
`status_shocked.tres`, `status_wet.tres` (all under `resources/tuning/`),
`scripts/gameplay_bootstrap.gd`, `scripts/gameplay_frame_controller.gd`,
`scripts/hud_controller.gd`, `scripts/actor_collision_system.gd`,
`scripts/slime_runtime_controller.gd` (contact capture integration).

A blind typed controller: no `GameplayState` field, no `root.call`. Ticked once
per simulation frame with a snapshot of contacts captured after movement and
before separation. Wiring through the existing frame/contact owners introduces
no new `GameplayState` field. Own the spawn-generation token on the actor and
use an explicit room-change reset on the controller.

Acceptance: touching a burning enemy burns the player; the player's own wet
status transfers to the enemy it touches; a suppressed innate record does not
transmit; a pair cannot transmit again inside the cooldown; the received badge
carries the transmitted ring; and a nine-actor room screenshot at 240x160 remains
readable. Immunity or special-defense rejections obey cooldown; both directions
use the same pre-transfer snapshot; no same-frame propagation chain occurs; a
respawned slot and a newly entered room inherit no old cooldown. Auxiliary Hex
does not spread.

### S7 — Two/three-element run themes and elemental healing supports

Files: `scripts/encounter_definition.gd`, `scripts/room_controller.gd`,
`resources/definitions/encounter_definition.tres`, `scripts/dungeon_graph.gd`,
`scripts/run_state.gd` (select the existing typed run owner for the theme),
`scripts/active_run_snapshot.gd`, `scripts/active_run_snapshot_context.gd`,
`scripts/slime_variant_catalog.gd`, authored enemy catalog/definition resources,
and `scripts/slime_support_component.gd` only if its existing heal behavior needs
a generic palette/definition seam. Audit boss/summon creation and per-run layout
policies for theme consumers; do not add coordinator fields to `GameplayState`.

Execution order within S7: author healer variants using shared behavior; select
and persist the run theme; constrain every enemy creation path; validate complete
rosters and run unions; cover snapshot restoration and legacy migration. Fix the
cached-resource mutation by duplicating before setting runtime policy. Pair
synergy preferences require authored interactions, with Water/Electric as the
first grounded example, and may fall back to eligible non-synergistic themes.

Acceptance: across a seed sweep, the union of non-Normal enemy elements over an
entire run never exceeds three, and every room is a subset of the saved theme
with no more than three elements. Two-element themes are more common than
three-element themes; report observed frequencies against the configured chance.
Include supports, bosses, summons and respawns in that check. Every elemental
support heals allied enemies using the shared heal behavior; friends of the
other allowed element and Normal remain valid heal targets. A Water/Electric
run never gains a Grass healer; a Grass theme can use Grass healers. Normal-only
and single-element teaching runs remain legal. Repeated elements are legal.
Saving/loading preserves the theme, existing enemy health/Chroma/death state
and pickup values; room revisits never reroll it. Report changed rosters, flags,
levels, family frequencies and support frequencies rather than asserting
unproven byte equality. Preserve enemy counts and Chroma carrier counts wherever
possible and report explicit exceptions. Authored special-room requirements
must remain solvable. Two controllers cannot mutate each other's definition.
Forced debug bypass is explicit; legacy migration policy must be resolved and
validated before release.

### S8 — Documentation and test debt

`docs/GAMEPLAY_TUNING.md` (the five-status table and the provisional Wet numbers),
`docs/ARCHITECTURE.md` (ownership), `docs/AUDIT.md`,
`docs/KNOWN_ISSUES.md` (the occlusion cache defect and the magenta rectangle
result), `docs/elemental-status-implementation-plan.md`,
`docs/elemental-ability-and-status-system.md` and its addendum (the status set,
and the E4 aura decision),
`docs/elemental-ability-and-status-system-addendum.md`,
`docs/CONTENT_AUTHORING.md`. Then close the two acceptance bars: the 240x160
readability probe with a full crowd and HUD, and the web/browser playtest.

## 8. Verification

**Safe with the live MCP editor connected:**

- `script_check` per changed file.
- `discover_tools` for `lsp_code_analysis`, then `lsp_project_diagnostics`.
- `execute_code` on `channel: 'editor'` for data assertions — this is how to
  check `ElementCatalog.DATA.validate().is_empty()`, the catalog pure functions
  and synergy helpers without launching a process.
- `game_start` on `main`, `runtime_screenshot` at the native 240x160 preset,
  `debugger_get_log`, `input_simulate` for the imbue probes.
- `tools/validate_composition.ps1` — pure text analysis, no Godot launch. This
  is the automated guard on the blind-component and `GameplayState` constraints,
  so run it in **every** slice.

**Deferred to a supervised standalone step, because the editor holds the project
directory:** `tools/validate_definitions.ps1` and `tools/report_catalogs.ps1` both
run `Godot --headless --import` against this same directory. Run them only with
no MCP runtime active.

**Never in this work:** `tests/run_all_smoke.ps1` is editor-restricted *and*
claimed by opencode on `coord/BOARD.md`. Do not edit it.

## 9. Risks and coordination

| Risk | Mitigation |
| --- | --- |
| **Original overlap gate** | Aura alignment and Electric Shocked feedback are incorporated in this implementation; visual acceptance remains open. |
| Room saturation from bidirectional spread | Per-pair cooldown only, by owner decision. The 240x160 crowd probe is the acceptance test; raising the cooldown is the cheap remedy. |
| `_encounter_definition()` mutates a shared instance | `default_data()` returns a cached resource. Duplicate it before setting runtime policy; a second load/preload is not isolation. The guard compares separate properties, but shared mutation can couple controllers. |
| Insertion-dependent `strongest_active_definition` tie-break | Fixed in S1 with applied-first, stacks-descending, status-id ordering, reused by outlines and both HUD paths. |
| Occlusion texture cache never invalidates | Fixed in S5 with a revision counter. Record in `KNOWN_ISSUES.md` even if not fixed there. |
| `GameplayState` at 286/286 fields and 1718/1719 lines | Hard prohibition. If a slice seems to need a field there, the design is wrong. |
| Water becomes a status-bearing element | Wet is active in source; the provisional values and new Water status still need seed, combat, and readability tuning. |
| A support, boss, summon or authored color adds an element outside the run theme or raises a room above three | Source filters and validates generated/cached rosters and uses theme-matched healers; the seed sweep must confirm all creation paths. |
| Legacy snapshot has more than three elements | Deterministic remapping to the persisted theme is implemented; verify health, Chroma, death flags and pickups through the save/load probe. |

## 10. Owner decisions and remaining acceptance

The owner-directed choices are recorded in this plan and reflected in the
implementation:

- Usually two non-Normal enemy elements per run; sometimes three, with a hard
  three-element run and room cap. The current chance is 20% at rank 3+ and is a
  playtest starting value.
- Prefer authored synergy where available; Water/Electric is the first pair.
- Every elemental support heals its allies through the shared support behavior.
- An authored status immunity prevents that innate status record and its aura.
- Suppressed innate affinity is fully hidden and cannot transmit; the transition
  is shown by brief innate/suppressor-colored edge bursts.
- Legacy snapshots choose the most prevalent up-to-three cached elements, with
  element-ID tie-breaking; empty legacy rosters use the seeded rank policy.
  Cached rosters are remapped deterministically while slot health, Chroma,
  deaths, levels, and pickups remain in their existing room-state entries.
- Wet has no new audio cue in this pass. Existing Water spell sounds remain
  attached to the Water spell.

**Still open:** Wet's `0.25` proc chance, `3.0 s` duration, 2-stack cap, `0.35`
Electric damage bonus per stack, and `1.5x` Shocked cadence divisor are
provisional. Focused smoke execution, catalog/definition validation, a seeded
roster-frequency and save/restore sweep, native 240x160 crowd readability,
combat balance, and browser playtesting remain required before calling the
feature verified.
