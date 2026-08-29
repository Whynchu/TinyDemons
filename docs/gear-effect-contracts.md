# Tiny Demons — Gear Effect Contracts

## Status

**Approved contract registry — active existing effects are implemented; future
effects remain gated.** Every effect added to the catalogue must be assigned to
one of these contracts or receive a reviewed new contract before code is
written. The equipment/snapshot read model preserves declared future effects
for UI and review without activating them in combat.

## Contract principles

1. One owner calculates an effect.
2. UI preview and combat consume the same derived result.
3. Every multiplier has an explicit order and clamp.
4. A negative tradeoff is visible in the item comparison.
5. Effects do not infer behavior from item names, palette colors, or slot text.
6. A gear effect never directly awards run Style or bypasses the player’s
   action requirement for earning it.

## Existing stat contracts

### Flat attribute package

The existing catalogue defines authored bonuses for VIT, STR, DEF, AGI, INT,
and MND. One item has one `primary_stat`; rarity and enhancement advance that
lane. Secondary values remain fixed and readable.

```text
flat gear = authored base package
          + rarity flat points on primary_stat
          + enhancement points on primary_stat
```

### Attribute rate package

The current runtime applies a rarity rate to positive supplied attributes. The
rate is accumulated with other applicable rates and applied after flat points:

```text
effective stat = (base + allocation + flat gear) × (1 + summed gear rates)
```

The six-slot catalogue must keep package sizes small enough for this existing
rule to remain readable. A future change to rarity budgeting requires a
separate balance/migration decision; content entries must not quietly invent a
second rarity formula.

## Derived stat contracts

| Effect ID | Owner | Meaning | Initial legal slots |
| --- | --- | --- | --- |
| `max_health_rate` | Combat snapshot/health calculator | Additive Core HP rate after the approved HP baseline | Body, selected Accessory |
| `core_health_rate` | Combat snapshot/health calculator | Current Core HP multiplier owned by a transmutation | Body |
| `vit_health_multiplier` | Combat snapshot/health calculator | Explicit VIT effectiveness modifier | Body, selected Accessory |
| `flat_health` | Combat snapshot/health calculator | Small visible flat HP addition | Body, Head |
| `guard_durability` | Equipment/guard setup | Shield durability package | Shield |
| `guard_reduction` | Equipment/guard setup | Guard damage-reduction package | Shield; Arm only after guard setup supports Arm effects |
| `knockback_resistance` | Combat snapshot/knockback owner | Bounded resistance to authored knockback | Body, Shield, Arm |
| `move_multiplier` | Player movement owner | Bounded movement/run effect | Arm, Body, Accessory |
| `recovery_multiplier` | Player action owner | Bounded action/recovery timing effect | Head, Arm, Accessory |
| `combo_window` | Combat momentum owner | Bounded successful-hit window adjustment | Arm, Accessory |
| `attack_lunge` | Player attack owner | Bounded lunge distance/forward motion adjustment | Weapon, Arm |
| `charge_profile` | Player attack owner | Charge output/timing tradeoff | Weapon, Arm |
| `spin_profile` | Player attack owner | Spin coverage/output tradeoff | Weapon, Arm |
| `running_attack_profile` | Player attack owner | Run-attack lunge, power, or recovery adjustment | Weapon, Arm, Accessory |
| `pickup_radius` | Pickup/runtime collection owner | Bounded Souls/Chroma collection comfort | Accessory |

Action profiles are not free-floating percentage affixes. Each must point to
a named tuning field and declare its effect on Attack 1, Attack 2, spin,
charge, run attack, recovery, or guard.

## Magic and elemental contracts

### `imbue_resonance`

`imbue_resonance` is keyed by an explicit element, or by an explicit
active-aspect match condition, and applies only while the player has an active
Imbue of that matching element. It may modify one approved channel:

- magic portion power;
- Chroma cost or duration, if a later tuning review allows it; or
- bounded visual intensity.

It does not alter the player’s current or bound aspect and does not make a
neutral attack elemental. The current player Imbue formula remains:

```text
physical raw = weapon base + STR × physical scale
magic raw    = Imbue base + INT × Imbue scale
```

P.DEF and M.DEF resolve their portions independently, the values combine, and
one elemental matchup applies to the entire combined result.

### `elemental_ward`

`elemental_ward` is a future defensive contract. It is not a replacement for
the player’s defender element and not part of the existing slime-combat slice.
The contract must specify:

- one or more explicit elements;
- whether the ward is a flat reduction or bounded multiplier;
- whether it applies before or after the full-packet matchup;
- its stacking rule; and
- the displayed comparison text.

Recommended order:

```text
attacker composite portions
    -> P.DEF/M.DEF mitigation
    -> combine
    -> one roll / critical result
    -> one attacker-vs-defender elemental matchup
    -> elemental ward modifier
    -> final damage floor/immunity rule
```

This preserves the approved rule that the matchup affects the full combined
composite result.

## Resource and economy contracts

Allowed initial resource utility is deliberately narrow:

| Effect | Allowed? | Rule |
| --- | --- | --- |
| Pickup radius | Yes | May make Souls/Chroma easier to collect |
| Pickup landing/bounce comfort | Yes | Presentation/collection utility only |
| Chroma capacity | Future review | Requires HUD, save, and balance contract |
| Chroma cost reduction | Future review | Must preserve explicit resource decisions |
| Souls per enemy | No initial catalogue | Prevents direct economy inflation |
| Gold multiplier | No initial catalogue | Prevents accessory from replacing run performance |
| Drop-rate multiplier | No initial catalogue | Drop quality remains a run/source rule |
| Style points | No | Style is earned by player actions |

## Behavioral passive contracts

An ordinary passive is an always-on or clearly timed effect with one sentence
of player-facing explanation. It must define:

```text
trigger
eligible action/target
value and duration
cooldown or stack limit
tradeoff
whether it is active in hub/run/result screens
UI comparison text
test fixture
```

Candidate passive families include:

- `run_attack_profile` for the recently added post-roll running attack;
- `charge_profile` for charged Attack 2;
- `guard_profile` for active block and shield recovery;
- `combo_window` for the visible combo timer;
- `recovery_profile` for dodge/backflip/attack recovery;
- `imbue_resonance` for matching elemental composite attacks; and
- `elemental_ward` after its defensive contract is implemented.

The older design labels guard_profile and recovery_profile are shorthand only:
implementation uses guard_reduction and recovery_multiplier, with their
stacking and timing declared by the owning action contract.

No passive may silently change the animation sheet frame count or hit-frame
index. AGI and gear action modifiers may affect bounded timing/motion values,
not authored frame identity.

## Transmutations

Transmutations remain separate from ordinary numeric effects. They are rare,
behavioral, and attached to a particular item definition or explicitly
controlled process. Current transmutations are:

| ID | Slot | Trigger/result |
| --- | --- | --- |
| `gathering_edge` | Weapon | Multi-target Attack 1 improves the same-target Attack 2 share |
| `blood_feed` | Weapon | Damage dealt heals a bounded portion of the hit |
| `bloodwoven_core` | Body | Core HP and VIT-derived health identity |
| `bastion_core` | Shield | DEF improves durability; successful blocks charge Attack 2 knockback |
| `duelist_focus` | Accessory | Locked target gains STR scaling; other targets receive the documented tradeoff |

New transmutations should be authored only after the base catalogue effect
budget is working. A transmutation may react to attack variants, combo timing,
lunging, multi-target sharing, guard, roll, target lock, knockback, health
thresholds, or room performance, but its trigger and reset must be explicit.

## Stacking rules

Default rules until a contract says otherwise:

- Flat attributes add before rates.
- Rates in the same category add before applying once.
- Action multipliers multiply only inside their named action profile and obey
  the profile’s clamp.
- Guard durability and guard reduction use their own shield contract.
- Identical passive IDs do not stack unless explicitly marked `stackable`.
- Two different effects that touch the same action must declare an order in the
  action profile rather than relying on dictionary iteration order.
- A transmutation does not duplicate its item’s ordinary stat package.
- Negative values are shown and remain negative at every rarity.

## UI contract for every effect

The Equipment comparison strip must be able to answer:

```text
what changes immediately?
what changes conditionally?
what is the tradeoff?
what does not change?
```

Examples:

```text
STR +2   AGI -1
RUN ATTACK: LUNGE +10%
FIRE IMBUE: MAGIC PORTION +8%
ELEMENTAL WARD: FIRE -10% AFTER MATCHUP
```

The exact values belong to tuning data. The labels and condition must never be
hidden behind an item name.

## Verification contract

Every new effect requires:

1. A pure or component-level test for its formula.
2. A snapshot/preview parity assertion.
3. A save/load assertion if it persists on the instance.
4. A stacking/conflict assertion.
5. A player-facing description assertion where the UI renders it.
6. A full smoke-suite run before the implementation checkpoint.
