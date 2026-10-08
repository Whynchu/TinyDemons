# Anchored Stat Allocation Proposals

Status: Model C implemented; Hub stat colors follow the player's current element, and Web Pages export verification is pending

Updated: 2026-10-08

Scope: constrain the spread between the player's six manually allocated
attributes while preserving a meaningful choice about which stats to favor

Current owner: `PlayerProfile`, `ProgressionController`,
`HubEconomyController`, and the Hub progression draft in `ScreenStateController`

## Current behavior

The player has six durable attributes: VIT, STR, DEF, AGI, INT, and MND. New
characters start at 2 in each; level points are banked and spent manually from
the Cloaked Demon Hub. The current level-award bands are 1 point through level
5, 2 through 10, 3 through 20, 4 through 35, and 5 afterward. The Hub keeps
pending allocations until Apply, and offers AUTO allocation profiles plus a
paid Respec after level 5.

Before this implementation, `PlayerProfile.allocate_stat()` checked only that
the stat was valid and unspent points existed. Gear is a separate bonus layer
consumed by `EquipmentComponent` and `CombatStatSnapshot`; gear does not affect
how many permanent points a player may allocate.

Relevant current authorities are
[`ffiii-inspired-stats-and-menu-implementation-plan.md`](ffiii-inspired-stats-and-menu-implementation-plan.md)
for the six-stat contract, [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) for the
level-point bands, and `player_profile.gd` / `progression_controller.gd` for
the live allocation and save behavior. The historical SPD design is
superseded and is not the authority for this feature.

## Desired player contract

- The player can favor one or more attributes, but cannot leave one attribute
  far behind the others while continuing to stack a single stat.
- The rule is visible before Apply. Pending points count, so the player cannot
  confirm a draft that exceeds the limit.
- The rule concerns the six permanent primary attributes, not equipment
  bonuses, derived combat values, or the retired SPD alias for AGI.
- Level progression can widen the permitted spread modestly. Any limit must be
  monotonic with level so leveling up never makes a previously legal build
  illegal.
- Existing saves are never silently changed. Invalid legacy spreads remain
  playable; new spending should help close their gap until they are within the
  current rule, while Respec remains available under its existing cost rules.
- AUTO patterns must find a legal distribution and spend all points whenever a
  legal full allocation exists. If not, they should leave remaining points
  banked and explain why.

## Candidate models

Let `S` be the six values `base_stat + committed_allocation + pending_allocation`
for VIT, STR, DEF, AGI, INT, and MND. Do not include gear. Let
`spread = max(S) - min(S)`.

| Model | Rule | Advantages | Tradeoffs |
|---|---|---|---|
| **A. Fixed anchor** | `spread <= 15` at every level | One simple, memorable rule; allows a substantial preference | Ignores the proposed tighter early game; a 15-point gap is proportionally much larger when stats are small |
| **B. Level-banded spread** | `spread <= 10` through L10, `<= 12` through L20, `<= 14` through L35, `<= 15` afterward | Directly matches the suggested 10-point early and 15-point late shape; easy to explain and test | At L10, base stats of 2 allow a leading value of 12 against a lowest value of 2 (6×); it controls point distance, not ratio |
| **C. Level-banded spread + ratio** | Model B plus `max(S) <= 5 * min(S)` | Keeps the absolute preference window and prevents a low stat from becoming a tiny fraction of the highest; ratio is still loose enough to allow specialization | More rules to teach; legacy profiles and zero-base edge cases need careful handling |

### Recommended starting proposal: Model C

Use the banded spread in Model B and add a broad 5× ceiling between the highest
and lowest current permanent attributes. This provides a concrete anchor in
points and addresses the ratio concern directly, while leaving room to favor a
build's main stat. Because all six current player base attributes are 2, the
ratio is well-defined for new profiles. Validate it by multiplication
(`max(S) <= 5 * min(S)`), without division or a silently clamped minimum.
Preserve migrated base values; zero-base compatibility/recovery needs explicit
handling rather than changing the meaning of the ratio check on load.
Existing profiles with a non-positive base stat keep their values and use the
level-banded spread rule without the ratio guardrail; the allocation screen
labels this compatibility mode "SPREAD ONLY". Normal new profiles use all six
positive base stats and the full Model C check.

The ratio mainly constrains builds whose lowest attribute remains small. At a
minimum of 2, it permits a highest value of 10; Model B permits 12 early and 17
late. Once the minimum reaches 4, even the largest proposed spread of 15
already satisfies the 5× ceiling. This is a low-stat guardrail, not a second
restriction that stays equally influential throughout progression.

Treat the cap as applying to the **whole final draft**, not as a fixed
per-stat maximum. For example, raising the lowest stat also raises the anchor
floor and can unlock more room for a favored stat. Show the player the current
highest/lowest values, allowed spread for their level, and the reason an
allocation is blocked. Keep this proposal subject to balance review; the 5×
number is a starting point, not a measured gameplay result.

If the additional ratio proves too hard to communicate, Model B is the simpler
fallback. The source-backed player baseline is six equal 2-point stats, which
makes Model B predictable and lets the absolute spread shrink as the total stat
pool grows.

## Allocation bars and anchor movement

Add a segmented allocation bar beside each of the six stat rows. Use the
player's current element highlight for stat labels and filled ticks, with a
black interior and visible outline/dividers for empty ticks. Show stat values
in white until they reach the current shared ceiling; show capped or
over-ceiling legacy values in red. Pending ticks use a lighter tint of the same
element color. A tick represents one permanent stat point in the displayed
range; gear bonuses never fill or extend this bar.

| Tick/row state | Meaning and feedback |
|---|---|
| Solid element-color tick | Base or committed permanent value; cannot be removed by clearing the draft |
| Lighter element-color tick | Pending allocation; immediately updates preview and can be cleared before Apply |
| Black outlined tick | Unfilled room within the current policy window; spending still requires banked points and an accepted policy result |
| Full leading-stat bar | Current anchor ceiling reached; show which lowest rows must rise to unlock further room |
| Lowest-stat row | Mark the row and relevant empty ticks as the way to raise the shared anchor; preserve black interiors |
| Existing over-limit row | Keep the actual value visible with an overflow marker; show accepted repair steps on low rows rather than hiding or trimming saved points |

Keep the stat value, current ceiling, and remaining banked points visible.
Black space represents allocation capacity, not points already earned. With no
banked points, leave capacity visible but disable Add with an explicit reason.
For legacy builds, policy-approved repair capacity takes precedence over the
normal legal window. The same policy must drive bars, Add availability, AUTO,
and Apply; the presenter must not invent a second allocation rule.

The bars have a fixed physical width and tick pitch. At high values, use a
shared labelled range near the current anchor and summarize points below it
numerically; do not draw an ever-growing bar or silently make a tick mean
multiple points. Keep actual values and any overflow readable. Clearing pending
points recalculates every bar immediately and preserves the saved build.

### Recommended movement: recalculate after each point

Use the current draft's lowest value as the moving anchor, rather than adding
another unlock tier. At a fixed level, the normal shared ceiling is
`min(S) + spread_cap` for Models A/B and
`min(min(S) + spread_cap, 5 * min(S))` for Model C. This is a visual guide;
validate each actual addition against the complete tentative vector.

If multiple stats share the lowest value, raising just one does not move the
anchor. Mark all tied-lowest rows and explain: "Raise the lowest stats to
extend the bars." The player does not need to max every bar. Once the last
tied minimum rises, all bars update, including pending allocations before Apply.

For an early-game spread cap of 10:

| Lowest permanent value | Model B ceiling | Model C ceiling |
|---|---|---|
| 2 | 12 | 10 |
| 3 | 13 | 13 |
| 4 | 14 | 14 |

Model B moves one point for each increase in the minimum. Model C recalculates
after each point too, but its ratio can unlock several ticks at once while the
minimum is small. Keep the existing level bands as the separate level-based
spread changes; do not describe Model C as strictly linear.

| Movement option | Player experience | Proposal |
|---|---|---|
| Recalculate from the minimum after every point | Filling low rows unlocks room as soon as the minimum rises; fits the existing spread/ratio rule | Recommended starting behavior |
| Unlock only at additional stat tiers | Larger unlock moments, but points between thresholds may provide no new room for the favored stat | Requires a separately chosen tier size and revised policy/migration rules; defer |

### Presentation ownership

`HubStatsScreenPresenter` owns stat-row rendering/layout; extend it with a typed
bar presentation result from the allocation policy. `HubStatsInteractionPresenter`
owns visibility and touch focus, with `HubScreenRenderController` supplying the
draft. Reflow the allocation/derived preview layout to make room for the bars;
do not overlay the current value, plus/minus controls, finger cursor, or touch
targets. Preserve controller navigation and direct touch allocation.

## Allocation and migration rules

1. Centralize the rule in a small progression policy function that accepts the
   level, permanent base values, proposed six-stat allocation, and prior vector
   for legacy-repair comparisons. Do not implement a separate check in each
   button handler. Budget/nonnegative checks and the policy result must agree
   before an atomic commit can succeed.
2. The Hub's pending draft must test each proposed point against the complete
   tentative six-stat vector. Rejected attempts keep existing pending points
   intact and provide visible feedback.
3. Apply must validate the whole draft before mutating the profile, then commit
   it atomically. `ProgressionController.allocate_stats()` currently walks the
   stat list and calls `allocate_stat()` in sequence; sequential partial commits
   are not suitable for a cross-stat constraint. Return a typed success/rejection
   result. Clear the draft, refresh runtime stats, and request a save only after
   success; rejection preserves both the profile and pending points.
4. Direct profile allocation, Hub draft/Apply, AUTO presets, level changes,
   profile load, Respec, and debug level overrides must use or respect the same
   policy. Save data does not need new fields for this rule: it is derived from
   the saved level and six saved allocations. Include
   `ProfileRuntimeController.sync_runtime_progression_to_profile()` explicitly:
   its current direct writes must not bypass allocation validation or persist
   temporary debug allocations. Loading classifies compatibility; it does not
   reject or rewrite a previously saved build.
5. For a pre-existing allocation that exceeds the selected rule, do not delete
   or respec points on load. Allow repair steps that do not worsen either limit
   and move low stats toward the required floor, even when tied minima mean the
   spread and ratio do not improve immediately. For example,
   `[20, 2, 2, 2, 2, 2]` must allow the player to raise each low stat in turn.
   Define the floor as `max(S) - spread_cap`, also bounded below by
   `ceil(max(S) / 5)` when Model C is selected. Require a repair step to reduce
   the total deficit below that floor while neither spread excess nor ratio
   excess increases. Define these excesses as
   `max(0, max(S) - min(S) - spread_cap)` and, for Model C,
   `max(0, max(S) - 5 * min(S))`. Compare against the preceding accepted draft
   vector for each point, and against the committed vector for atomic Apply. Reaching a
   legal vector also succeeds. A level increase may widen the cap but never
   narrow it.
6. AUTO should distribute iteratively using the same legal/legacy-repair policy
   as manual allocation. Preserve preset preferences, but consider all six
   stats as fallback destinations: current presets omit some stats. If no
   accepted destination remains, stop and retain unspent points with a reason.
   Repair progress can remain over-limit when the available bank cannot close
   the whole gap; do not discard that useful draft.
7. Respec returns committed points through its existing flow. A fresh draft
   starts from the current base values, so every normal Respec build is valid.
8. Monotonic bands protect level increases. Debug level decreases can tighten
   the cap; evaluate the temporary vector at the override level and report any
   incompatibility without changing the saved build. Keep debug level, trimmed
   allocations, and point budgets isolated from durable profile writes. Restore
   normal runtime values when the debug session ends. Back currently leaves the
   debug page while keeping the session active; sync/save must exclude temporary
   allocations both while that session runs and after it ends.

## Acceptance evidence

- Threshold checks for levels 10, 11, 20, 21, 35, 36, and the maximum level;
  verify spread bands, ratio boundaries, equality, and one point over each cap.
- Draft checks where the highest stat is blocked, then raising a lowest stat
  permits a later favored-stat point; Cancel preserves the profile and Apply
  changes all six allocations atomically.
- Six ticked bars and stat labels use the player's current element highlight;
  numbers stay white below the shared ceiling and turn red at or above it.
  Empty capacity remains black and outlined, and pending fill is a lighter tint
  of the element color. Numeric values/ceilings and banked points agree with the
  policy; gear changes never alter allocation capacity.
- Cover a full leading bar, one lowest row, multiple tied-lowest rows, Model C's
  early multi-tick unlock, level-band expansion, no banked points, legacy repair
  overflow, and draft Clear/Apply. Block feedback identifies the low rows needed
  to continue rather than suggesting every bar must be filled.
- Verify allocation bars and labelled high-value windows remain readable in
  portrait/landscape and supported Full layouts, with unchanged usable touch
  targets, controller cursor visibility, and derived-stat preview access.
- Rejected Apply preserves the draft and profile and does not trigger a save or
  runtime stat refresh. Runtime synchronization cannot bypass the policy.
- AUTO profiles produce legal drafts and spend all available points when
  possible; otherwise they retain points with a visible explanation.
- Direct profile allocation cannot bypass the policy; profile save/load keeps
  existing legal and over-limit allocations unchanged.
- Existing over-limit saves remain playable with their values intact and can
  spend toward a legal allocation; no data is silently discarded. The Hub
  identifies the repair path and marks capped legacy values in red. Respec
  remains compatible.
- A legacy vector with multiple tied minima accepts successive repair steps;
  neither limit worsens and the total floor deficit falls. Cover manual, AUTO,
  insufficient-bank partial repair, Apply, and save/load paths.
- Level increases retain legality. Debug decreases across band boundaries may
  report temporary incompatibility, but Back, continued debug play, session end,
  and subsequent runtime sync/save leave durable allocations and point budgets
  unchanged.
- Zero-base profiles load unchanged and expose a defined compatibility/recovery
  result; validation never divides by zero or silently replaces base values.
- No changes to gear values, combat formulas, save schema, or enemy stat growth
  are needed for this rule.

## Selected rule and remaining balance check

Model C is selected for the first implementation. Model B remains a fallback
only if playtesting shows that the ratio is hard to understand or overconstrains
builds. Model A remains a comparison point, not an implementation target.

Do not tune the level bands or AUTO profiles together with unrelated combat
balance changes. Validate representative builds through the whole level curve
before changing the selected 10/12/14/15 spread or 5× ratio.

Implement this policy and atomic allocation slice before the larger Idle Mode
feature. Equipment quality is independently deliverable; its flat gear score
does not participate in the permanent-stat cap.
