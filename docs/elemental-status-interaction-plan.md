# Elemental Status Interaction Plan

Status: implemented in source; focused runtime verification pending

Updated: 2026-10-05

Owner: combat status application (`StatusApplication`,
`StatusMixtureController`, `StatusComponent`, and authored status definitions)

## Goal

Make elemental status interactions a small, readable combat loop. Heat and cold
meeting an existing status produce Wet; Wet plus Ice produces Freeze; Wet
continues to make Electric stronger and Shocked pulse faster. Burn, Poison,
and Shocked use distinct max-health-scaled tick strengths and timing. Freeze
also pauses enemy attack updates until it expires.

Ground, Grass, and Shadow receive no new special status reactions in this
slice. Existing damage matchups, status behavior, Wet conductivity, and the
Water + Ice Freeze mixture remain intact.

## Agreed interaction tree

Resolve these reactions from an incoming elemental hit and the target's active
applied status or innate elemental affinity:

| Target state before hit | Incoming element | Reaction | Status |
|---|---|---|---|
| Applied Burn | Ice | Consume Burn; apply Wet instead of Chill | Implemented |
| Applied Freeze | Fire | Consume Freeze; apply Wet | Implemented |
| Innate Fire affinity | Ice | Ice melts; apply Wet instead of Chill | Implemented |
| Wet + Chill coexist | Either ingredient was just applied | Consume applied Wet/Chill ingredients; apply Freeze | Implemented; preserve |
| Wet | Electric | +35% Electric damage taken per Wet stack; Shocked cadence divided by 1.5 per Wet stack to the configured floor | Implemented; preserve |
| Shocked | Time passes | Periodic action-lock pulses plus 2% of target max HP per stack every 3 s for a 6-second status duration | Implemented |
| Freeze | Enemy acts | Enemy attack update pauses until Freeze expires; it resumes from its current attack frame | Implemented |

The three new heat/cold-to-Wet reactions consume their triggering status: Burn
or Freeze. They apply Wet as a guaranteed reaction, do not also apply Chill,
and do not require an extra status proc roll. The existing Wet + Chill mixture
continues to consume its ingredients and apply Freeze.

Unlisted pairs have no added status reaction. In particular, do not add
Ground, Grass, or Shadow reactions here. Their ordinary elemental matchup and
status behavior continues to apply.

## Status damage scale

The authored 3/2/2 values are percentages of the affected actor's maximum
health per stack per tick, rather than literal HP. This keeps DoT strength
relevant across different health pools. Per-second potency is Burn 3%, Poison
1%, then Shocked about 0.67%; Shocked's six-second duration yields 4% total
damage per stack as shown below. Each tick is rounded to whole HP, with a 1 HP
minimum for a positive tick.

| Status | Per-stack damage | Tick interval | Duration | Total per stack |
|---|---:|---:|---:|---:|
| Burn | 3% max HP | 1 s | 3 s | 9% max HP |
| Poison | 2% max HP | 2 s | 6 s | 6% max HP |
| Shocked | 2% max HP | 3 s | 6 s | 4% max HP |

## Implementation sequence

1. **Lock down reaction semantics.** Confirmed in this plan: all heat/cold
   reactions yield Wet; Burn + Ice consumes Burn; Freeze + Fire consumes
   Freeze; Fire-affinity + Ice applies Wet; no Ground/Grass/Shadow additions.
2. **Add focused status-application coverage first.** Extend
   `tests/status_mixture_smoke.gd` or add a focused status-reaction smoke to
   prove each reaction, ingredient consumption, no unintended Chill/Burn,
   repeated hits, and unaffected unlisted cases. Cover applied Burn/Freeze and
   innate Fire separately.
3. **Implement reaction resolution at the narrow status boundary.** Keep
   status reactions in `StatusMixtureController` or a narrowly named
   companion, invoked by `StatusApplication`. Resolve target affinity before
   ordinary status application suppresses innate Fire; a Chill status
   suppresses innate Fire, so checking only after application would miss the
   Fire-affinity reaction. Preserve boss invulnerability and status immunity
   gates. Reactions should use registered Wet/Freeze definitions and
   `StatusComponent` APIs rather than direct dictionary mutation.
4. **Add Shocked tick data and behavior — implemented.** Configure the
   percentage-of-target-health damage amount and interval in
   `status_shocked.tres`. The periodic-stun family emits a standard damage
   result tagged `shocked` alongside its stun pulse; route it through
   `ActorStatusRuntimeController`'s established health/damage-number path.
   Keep status ticks free of recursive status procs and hitstop. Wet's
   conductivity bonus should affect Electric attacks; decide explicitly in
   implementation whether it also affects Shocked ticks (default: no, to
   avoid silently multiplying the DoT).
5. **Tune and document — initial values recorded.** Burn, Poison, and Shocked
   tick for 3%, 2%, and 2% of target maximum health per stack, at 1, 2, and 3
    second intervals; their durations are 3, 6, and 6 seconds. Wet does not
   amplify Shocked ticks. Enemy attacks pause while Freeze is active. Tune
   further only with combat evidence. The tuning index and interaction tables
   now match source.
6. **Verify.** Run the focused status reaction and status combat smokes, then
   the relevant curated gate when the shared editor is not active, following
   `AGENTS.md`. Manually confirm status readability and that Freeze remains
   threatening but counterable.

## Acceptance criteria

- Ice against applied Burn removes Burn and applies Wet, without adding Chill.
- Fire against applied Freeze removes Freeze and applies Wet.
- Ice against an innate Fire-affinity target applies Wet, not Chill; later Ice
  can still interact with Wet through the existing Freeze rule.
- Water + Ice still creates Freeze in either order and consumes the applied
  ingredients; innate-status suppression behavior remains correct.
- Reaction outcomes respect target status immunity and current boss
  invulnerability/status restrictions.
- Burn, Poison, and Shocked deal 3%, 2%, and 2% of target maximum HP per stack
  per tick, with 1/2/3-second tick intervals and 3/6/6-second durations.
- Shocked retains its action-lock pulses; damage ticks do not proc statuses or
  add hitstop, and Wet does not amplify their damage.
- Freeze pauses enemy attack updates for its full duration and resumes the
  current attack animation afterward; boss movement-lock resistance applies.
- Wet conductivity continues to amplify direct Electric damage and accelerate
  Shocked pulses as currently authored. Wet does not amplify Shocked damage
  ticks.
- Ground, Grass, and Shadow receive no new reactions in this work.
- Focused status verification passes; docs distinguish implemented behavior
  from pending behavior.

## Balance acceptance

Status tick values are percentages of the affected actor's maximum health per
stack, so they scale across health pools instead of representing literal HP.
The current accepted starting values are Burn 3%/1s/3s, Poison 2%/2s/6s, and
Shocked 2%/3s/6s. Confirm their total pressure at normal and boss health
scales before treating them as final balance.

## Runtime ownership and current evidence

- `StatusApplication` validates hit/source gates and applies a status.
- `StatusMixtureController` resolves registered Wet + Ice ingredients and
  handles applied/innate ingredient constraints.
- `StatusComponent` owns records, stacks, status ticking, damage modifiers,
  and stun cadence.
- `ActorStatusRuntimeController` routes status ticks through actor health and
  floating damage feedback.
- `resources/definitions/element_catalog.tres` is the consumed status and
  mixture registry. `StatusEffectDefinition` fields in `resources/tuning/`
  define the authored values.
- `tests/status_mixture_smoke.gd` covers Water + Ice order symmetry, thermal
  reactions, Freeze attack locking, and boss resistance. `tests/status_combat_smoke.gd`
  covers max-health-scaled DoT damage routing.

See [Gameplay Tuning](GAMEPLAY_TUNING.md#elemental-status-definitions) for live
status values and [Combat and Dungeon Design Principles](combat-and-dungeon-design-principles.md#35-combat-matchup-and-status-interaction-table)
for the broader element matchup and reaction coverage tables.
