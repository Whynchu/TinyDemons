# Tiny Demons — Elemental Chroma System Design

## Core Concept
- Tiny Demons naturally exist in a **Gray / Unaspected** state.
- Elemental color represents **Chroma**, the elemental energy currently stored in the demon.
- The demon’s sprite saturation visually tracks remaining MP/Chroma.
- Elements function as **classes**, each with a unique action used in combat, puzzles, and environmental interactions.

## Starting State
- Replace character-color selection and independent stat-archetype selection
  with **Flame Selection** when creating a new file.
- The player chooses one permanent starter flame: **Fire**, **Water**, or
  **Electric**.
- The chosen flame becomes the flame that appears in the hub's starting room
  at the beginning of future runs.
- Every run begins **Gray with 0 MP/Chroma**. The starter aspect is selected for
  the file, but is not automatically active at run start.
- Interacting with the hub flame attunes the player to the selected starter
  aspect and immediately fills Chroma to **100 MP**.
- Hub attunement may be optional during ordinary runs, although authored
  tutorial/progression sequences may force the player to use it.
- Starting elemental action cost: **25 MP**.
- This gives exactly **4 elemental uses** before depletion.

The starter flame also supplies a small class-identity package: a modest stat
adjustment, a modest passive, and the aspect-specific Triangle ability. Exact
effects are tuning decisions; flame choice should express playstyle without
locking the player's long-term build.

Before Binding, the entire active class package follows the current flame.
Attuning to another flame replaces the stat adjustment, passive, ability, and
aspect presentation together. Binding changes this replacement rule later by
allowing an existing identity to be preserved for blending; its exact class-
package behavior will be designed with the Binding system.

## Chroma Depletion
- Each elemental action consumes Chroma and visibly desaturates the demon.
- At **0 MP**, an unbound aspect disappears and the demon becomes Gray.
- Gray still has a functional neutral version of the action button.
- Reaching zero therefore changes the player’s class without disabling basic gameplay.

## MP Restoration
- Neutral Chroma pickups restore exactly **25 Chroma** during normal gameplay.
- Initial Chroma values are quantized to four charges: **0, 25, 50, 75, 100**.
- Neutral restoration preserves the player’s current aspect.
- Gray cannot store or gain Chroma. If Gray touches a neutral Chroma pickup,
  the pickup is still consumed but grants no MP and causes no attunement.
- A flame is therefore required to leave Gray and establish an aspect.
- Elemental flames are separate from ordinary MP restoration.
- Flames can refill Chroma and change the player’s elemental aspect.

## Normal Flame Attunement
- Using another elemental flame normally **replaces** the current aspect.
- Example: Fire → Blue Flame → Blue.
- Players do not need to empty their previous element first.
- Flames should refill Chroma quickly so interacting with them never becomes waiting gameplay.

## Early Tutorial — Forced Depletion
- Character creation records the player's starter flame, but the run itself
  begins Gray at 0 Chroma.
- The selected starter flame appears in the hub room. The opening flow requires
  the player to interact with it, demonstrating that flames create aspects and
  fill Chroma.
- Early in Run 1, include a puzzle requiring exactly **4 elemental actions**.
- The sequence forces:
  - 100 → 75 → 50 → 25 → 0 MP.
- The player watches their demon progressively lose saturation and become Gray.
- This explicitly teaches:
  - elemental abilities consume Chroma;
  - color represents remaining elemental power;
  - reaching zero removes an unbound aspect;
  - Gray still has its own action.
- Prevent enemy spawns or MP pickups inside puzzles designed around mandatory depletion.

## Run 1 — Learn the Starter Aspect
- The hub contains the player’s permanently selected starter flame.
- Only that starter flame appears during the first curriculum unless an
  explicitly authored lesson says otherwise.
- Focus the dungeon around that element.
- Teach:
  - elemental action;
  - combat utility;
  - puzzle/environmental utility;
  - Chroma depletion;
  - Gray state;
  - re-attunement/refilling.

## Run 2 — Learn Element Swapping
- Player begins Gray at 0 Chroma, as in every run, and may attune to the
  original starter flame in the hub before entering the dungeon.
- Initial room forks into two routes.
- One route contains a puzzle requiring a new element.
- The other route contains combat and eventually the required flame.
- Player must find the new flame, change aspect, then return to the blocked route.
- This teaches that **elemental state is part of dungeon navigation**.

## Elemental Puzzle Rooms
- Early dungeons should include both predictable and **unexpected elemental puzzles**.
- Not every elemental requirement should be visible from the doorway.
- Unexpected requirements reinforce awareness of:
  - current aspect;
  - available Chroma;
  - nearby flames;
  - previous unexplored rooms.
- These should create occasional moments where the player realizes they must alter their route or return later.

## Room Visual Language
- Rooms associated strongly with an element should receive a **subtle environmental tint** matching that aspect.
- Use tinting for:
  - elemental puzzle rooms;
  - rooms dominated by one elemental enemy type;
  - flame rooms;
  - strongly themed encounters.
- Tinting should provide atmosphere and subconscious information without completely revealing every puzzle solution.

## Element-Specific Enemies
- Some rooms can spawn exclusively or primarily enemies associated with one aspect.
- Elemental enemy rooms can share the same environmental tinting language.
- Enemy mechanics should ideally interact with elemental class abilities instead of relying only on damage multipliers.

## Dungeon Progression
Early progression should intentionally function like an elemental training curriculum:

1. Learn one pure element.
2. Learn depletion and Gray state.
3. Learn swapping to another pure element.
4. Learn navigating around elemental requirements.
5. Encounter unexpected elemental puzzles.
6. Learn intentional depletion/resource conservation.
7. Unlock Binding.
8. Learn hybrid aspects.
9. Gradually reduce forced tutorial-like routing and allow greater player expression.

## Binding
- Binding is unlocked later.
- A **Bound Aspect** remains associated with the demon even when Chroma reaches zero.
- Example:
  - Unbound Fire + 0 MP → Gray.
  - Bound Fire + 0 MP → Fire remains stored.
- A bound aspect can regain its elemental power through neutral Chroma restoration without requiring another matching flame.
- Binding therefore becomes an important progression upgrade rather than only a fusion mechanic.

## Elemental Blending
- Normal flame interaction replaces the current aspect.
- **Binding enables intentional blending.**
- Example:
  - Fire → Blue Flame = Blue.
  - Bound Fire + Blue Flame = Fire/Blue hybrid.
- Hybrids should never happen accidentally.
- The player must intentionally preserve an aspect before introducing another.

## Color System
Start with three named base aspects mapped to primary-color identities:

- Fire — Red
- Electric — Yellow
- Water — Blue

Potential combinations:

- Red + Yellow → Orange
- Yellow + Blue → Green
- Blue + Red → Purple

Each resulting color becomes its own class/aspect.

Elemental themes do not need to follow literal chemistry. The game’s Chroma system determines elemental relationships through color blending.

## Procedural Generation Requirements
Dungeon generation must operate within progression constraints.

The generator should track:

- player file's selected starter flame;
- whether the run's hub attunement lesson is optional or mandatory;
- unlocked elements;
- unlocked mechanics;
- intended lesson for the current run;
- required puzzle aspects;
- available flames;
- valid paths between required flames and puzzles;
- backtracking accessibility;
- whether MP pickups/enemies could invalidate a forced depletion puzzle;
- elemental enemy-room themes;
- room tinting/theme metadata.

Randomization should happen **inside authored progression rules**, not as completely independent room generation.

## Core Player Decisions
The game should eventually create several overlapping agendas:

- **Gear:** What equipment am I building?
- **Stats:** What physical build am I developing?
- **Aspect:** What elemental class am I currently using?
- **Routing:** What aspect will I need deeper in the dungeon?
- **Chroma:** How aggressively can I spend elemental energy?
- **Binding:** Which elemental identity should I preserve?
- **Blending:** Which hybrid aspect do I want to intentionally create?

## Core Loop
**Choose Starter Flame When Creating a File → Begin Each Run Gray → Attune at
the Hub Flame → Enter Dungeon → Use Aspect → Spend Chroma → Solve Elemental
Problems → Find/Swap Flames → Manage Routing and Resources → Unlock Binding →
Create Hybrids → Build Gear/Stats → Defeat Boss → Progress to More Complex
Dungeons**

The elemental system should gradually evolve from a guided **key-and-lock training system** into a flexible buildcraft system where experienced players deliberately manipulate Chroma, aspects, routes, and hybrids.
