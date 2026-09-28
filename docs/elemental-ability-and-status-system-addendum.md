# Tiny Demons — Elemental Ability and Status System: Decision Addendum

Status: decision record; the current implementation choices are consolidated in
[`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md).

Scope: closing the open decisions in
[`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md) §9,
plus the owner-directed enemy status-marker presentation.

Owner: product/design owner (final sign-off); implementation owners named per row.

Current implementation owners: `element_catalog_data.gd` and
`resources/definitions/element_catalog.tres`; `StatusComponent` and the typed
application/tick contracts; `CombatRuntimeController` plus the scheduled player
and enemy ticks; `HudController` status badges; and `ElementAuraComponent`.
This addendum records the directed decisions; runtime acceptance is tracked in
the implementation plan.

Verification: this document records decisions; each decision's implementation
slice carries its own focused verification in the parent design doc §11.

Supersedes: none. Companion to the parent design doc; the parent remains the
technical authority, this file is the decision log.

> Every row is marked **DIRECTED** (owner stated the intent; values/timing still
> open), **RECOMMENDED** (advisor proposal awaiting owner sign-off), or
> **DEFERRED**. No row is treated as ratified until it is **DIRECTED** or signed
> off by the owner.

## A. Status set per element

| # | Decision | Resolution | State |
|---|---|---|---|
| A1 | Which elements carry a status? | **Fire Burn, Shadow Poison** (DoT); **Electric stun** and **Ice slow** (control). Water and Ground stay status-free. (Owner-directed 2026-09-28.) | DIRECTED / RESOLVED |
| A2 | Electric | **Passive flat-chance stun proc on every Electric hit.** (Owner-directed 2026-09-28.) Risk accepted: Hexley flagged random stun on a fast enemy as potentially unreadable — mitigate with a clear stun aura/badge, a short duration, and a low per-hit chance (tuning value). | DIRECTED / RESOLVED |
| A3 | Ice | **Slow** status (continuous). (Owner-directed 2026-09-28.) No exclusivity group is active in this pass; if a future `temperature` group is added, Slow stays outside it. | DIRECTED / RESOLVED |
| A4 | Grass | Healing caster exists (Healer Slime, element 4). Grass **lifedrain** would duplicate Grass support identity | RECOMMENDED: keep Grass on heal; move lifedrain elsewhere |
| A5 | Lifedrain owner | Give a **blood/crimson** enemy a lifedrain *cast* (reuse `SlimeSupportComponent` template), not a passive status | DEFERRED — **not this pass** (owner-directed 2026-09-28) |
| A6 | Player special move | Shadow poison delivered by a **long-cooldown special** | DEFERRED — **not this pass** (owner-directed 2026-09-28); interim: fold into existing regular/held magic |
| A7 | Water/Fire reaction | Water extinguishes fire | DEFERRED to the separate environmental-interaction system |

**Note on A2/A3:** the ratified contract rejects "ailments on every element"
(`design-interview-record-2026-09-18.md:80`) but explicitly names Electric
"fast/stun" and Ice "slow/freeze" as hand-feel identities
(`:68`) and design targets (`combat-and-dungeon-design-principles.md:147,151`).
The intended reading: stun and slow are **element identities expressed by
abilities**, which is why A2 lists them separately from the DoT ailment set.

## B. Proc model

| # | Decision | Options | Recommendation |
|---|---|---|---|
| B1 | How a status procs | **Flat chance per hit.** (Owner-directed 2026-09-28.) Each eligible hit rolls once; proc chances are `@export`/tuning values and are expected to be re-tuned later, so no buildup meter, pity floor, or per-target buildup state is built. | DIRECTED / RESOLVED |
| B2 | Does a status el-efficiency gate application? | Yes / no | **Resolved: gate on `effectiveness > 0`.** A Fire slime cannot be Burned; a strongly-resistant enemy visibly resists the status too. (Owner-directed 2026-09-28; see H2.) |
| B3 | Electric stun model | — | **Resolved by A2:** passive flat proc on every Electric hit (owner-directed). Supersedes the earlier guaranteed-ability recommendation. |
| B4 | Re-proc while active | refresh / stack / ignore | **Stack magnitude up to a per-status cap.** (Owner-directed 2026-09-28; semantics in H1.) Cap is a tuning value. |
| B5 | Re-proc after expiry | lockout / immediate | **Immediate re-proc allowed.** (Owner-directed 2026-09-28.) No immunity window. |

## C. Player, presentation, and persistence

| # | Decision | Resolution | State |
|---|---|---|---|
| C1 | Can the player receive statuses? | **Both control and DoT.** (Owner-directed 2026-09-28.) Enemy Burn/Poison and stun/slow can all land on the player. | DIRECTED / RESOLVED |
| C2 | Gear-granted resistance | Deferred; no gear-based status resistance in the first pass | DEFERRED |
| C3 | Player status HUD | Use the existing player HUD area; do not add `GameplayState` fields (owner-directed in H9) | DIRECTED / RESOLVED |
| C4 | Enemy status marker | Owner-directed: element-colored badge in a black circle to the **right** of the overhead health bar (see §D) | DIRECTED |
| C5 | Persistence across room transition | Clear on room entry and new run; pooled enemies clear in `SlimeActor.reset_runtime_state` | IMPLEMENTATION DEFAULT |
| C6 | DoT lethality | **Yes, DoT can kill, but never off-screen.** (Owner-directed 2026-09-28.) A tick that would reduce a non-visible / un-engaged actor to 0 holds it at 1 HP until it is visible/engaged; kills then reuse `_kill_slime`. | DIRECTED / RESOLVED |

## D. Enemy status marker (owner-directed)

**Intent:** a sprite *similar to the aggro marker* (`aggrodot(blue).png`),
placed to the **right** of the overhead health bar instead of the left, showing
each active ailment as a symbol inside a **black circle**. Start with the
circle highlighting the element color and swap in prepared per-element icons
later.

**Where it lives (grounded):** the overhead bar is assembled in
`hud_controller.register_overhead_bar` (`hud_controller.gd:1324`) and
`ensure_overhead_bar` (`:1361`). That function already creates two sibling
markers: `AggroMarker` (left edge, `top_level`, `z_index = 3`) and
`EliteOverheadSymbol`. The status badge is a **third sibling** in the same
pattern, anchored to the bar's **right** edge, and registered in a new typed
dictionary alongside `target_overhead_aggro_markers`.

**Spec (proposal):**

- Backing: a small black filled circle (authored PNG), nearest filter.
- Glyph: element highlight color first (`ElementCatalog.damage_number_color` /
  `PaletteLibrary.accent(palette_key)`); replace with `status_mark_id` icon
  textures from the element effect profile later.
- Position: right of the bar, `top_level = true`, z above the fill, matching the
  aggro marker's transform handling (`update_overhead_bars()` assigns world
  position/scale).
- Data source: the actor's `StatusComponent` active records → status element →
  element effect profile. The presenter is **read-only** and driven by
  `status_applied` / `status_removed`; no per-element branch, only lookup.
- Limits: cap simultaneous badges (proposal: 3); expiry removes the badge; free
  on death and on `reset_runtime_state`.
- Guardrail: no new `GameplayState` fields; the badge list belongs to
  `HudController` (matching `target_overhead_*` dictionaries).

**Readability acceptance:** use the actual colored status marks in a native-res
240×160 combat scene with 8–9 actors and the full HUD. Confirm a new player can
find the afflicted combatant and distinguish its ailment.

## E. Authoring / pipeline decisions

| # | Decision | Resolution | State |
|---|---|---|---|
| E1 | Definition bootstrap | Use the existing `ElementCatalogData` registry while M1 acceptance is open; migrate when M1 accepts | IMPLEMENTATION DEFAULT |
| E2 | Eligible targets | Player and combat actors only | DIRECTED / RESOLVED (2026-09-28) |
| E3 | Effect profile field | Keep status lookup in the existing `ElementCatalogData`; do not add a parallel element table | IMPLEMENTATION DEFAULT |
| E4 | Aura tinting for overlap | One outline uses the strongest active status; silhouette uses the blend; never stack full outlines | IMPLEMENTATION DEFAULT |
| E5 | Status particles | `StatusEffectDefinition` owns particle style and interval; Burn uses the imbue-like ember trail, Poison motes, Electric sparks, and Ice crystals | IMPLEMENTED IN SOURCE; visual acceptance open |

## H. Gameplay detail decisions (round 2, owner-directed 2026-09-28)

| # | Decision | Resolution |
|---|---|---|
| H1 | Control stacking axis | **Stack magnitude.** DoT stacks damage-per-tick magnitude; slow stacks slow %. Stun uses a cadence model instead of duration stacking — see H11. All capped per status. |
| H2 | Element gating | A status cannot land when `effectiveness == 0` (a Fire slime cannot be Burned). |
| H3 | Authored immunity | `EnemyDefinition` gains a `status_immunities` field through the M1 data pipeline; a definition may be immune to a status regardless of element. |
| H4 | Stun behavior | A **small interruption**: cancels an in-progress action, then briefly blocks move + attack. **No damage tick.** Respects the existing boss stun-resistance flag. |
| H5 | Slow strength | Scales with stacks from mild toward a cap (`slow_per_stack`, `slow_max`). |
| H6 | DoT duration | Short: **2–3 s** per application (tuning value). |
| H7 | Tick rate | **1 tick per second.** |
| H8 | Tick numbers | Shown, small, reusing the existing damage-number path. |
| H9 | Player status HUD | Badge near the player HUD, same pattern as the enemy badge. |
| H10 | Implementation order | **All four statuses in the first pass** (owner-directed). Note: Pip recommended DoT-first; this expands slice-1 scope, so the readability probe and the pipeline proof now gate a larger change. |
| H11 | Stun cadence & stacking | Electric applies a stun *status* that fires brief interruptions on a **periodic cadence** (default ~1 s). Each stack reduces the time to the next stun by **0.05 s** (floored at a minimum). Stun deals **no damage tick**. Cadence, step, and floor are tuning values. |
| H12 | Reapplication and timing | Add magnitude up to cap, refresh active duration, preserve the current tick/cadence phase. Initial implementation durations/chances are tuneable playtest defaults in the implementation plan. |

## F. Status of decisions

The owner-directed behavior is resolved. The implementation plan also records
defaults for implementation details that remain tuneable during playtesting:

- **Status set (A1–A3, H2–H5):** Fire Burn, Shadow Poison, Electric stun, Ice
  slow; Water/Ground none; element and authored immunity gate application.
- **Proc model (B1):** flat chance per hit.
- **Re-proc (B4/B5, H1):** stack magnitude up to a cap while active; immediate
  re-proc after expiry.
- **Timing (H6–H7, H12):** DoT 2–3 s, 1 tick/second; reapplication adds
  magnitude, refreshes duration, and preserves tick phase. Ice and Electric
  durations use the initial defaults in the implementation plan.
- **Lethality (C6):** DoT can kill, but never off-screen.
- **Player (C1, H9):** player can be afflicted by control and DoT; status badge
  near the player HUD.
- **Deferred (A5/A6):** crimson lifedrain enemy and player Shadow special.

Deferred work:

1. **C2** — gear-based status resistance.
2. Generalized `ElementalAbilityResolver` and new ability delivery types.
3. Migrate authored status definitions to the M1 manifest after M1 acceptance.

## G. Immediate next action

The directed status rules are implemented in the working tree. Complete the
native-resolution readability and runtime checks in the implementation plan;
the proc, stack, and duration values remain initial playtest tuning defaults.
