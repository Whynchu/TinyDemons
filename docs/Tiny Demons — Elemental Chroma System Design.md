# Tiny Demons — Elemental Chroma System Design

The finalized Binding and flame-fusion rules live in
[`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md).
This document remains the broader Chroma foundation; when the two documents
overlap, the Binding/Fusion document is authoritative.

## Core Concept
- Tiny Demons naturally exist in a **Gray / Unaspected** state.
- Elemental color represents **Chroma**, the elemental energy currently stored in the demon.
- The demon’s sprite saturation visually tracks remaining MP/Chroma.
- Elements function as **classes**, each with a unique action used in combat, puzzles, and environmental interactions.

## Starting State
- Replace character-color selection and independent stat-archetype selection
  with **Flame Selection** when creating a new file.
- The player chooses one persistent file starter flame: **Fire**, **Water**, or
  **Electric**.
- The chosen starter flame becomes the default flame that appears in the hub's
  starting room at the beginning of future runs until a later Binding replaces
  the persistent elemental identity.
- Every run begins **Gray with 0 MP/Chroma**. The starter aspect is selected for
  the file, but is not automatically active at run start.
- Interacting with the hub flame attunes the player to the selected starter
  aspect and immediately fills Chroma to **100 MP**.
- Hub attunement may be optional during ordinary runs, although authored
  tutorial/progression sequences may force the player to use it.
- Starting elemental action cost: **10 MP**.
- This gives exactly **10 elemental uses** before depletion.

The starter flame also supplies a small class-identity package: a modest stat
adjustment, a modest passive, and the aspect-specific Triangle ability. Exact
effects are tuning decisions; flame choice should express playstyle without
locking the player's long-term build.

The active class package follows the current aspect. Swapping or fusing at a
flame changes the current package without changing the saved bound identity.
Binding does not create a second combat type or stack stat packages; it makes
the current aspect persistent and available for zero-Chroma recovery.

## Chroma Depletion
- Each elemental action consumes Chroma and visibly desaturates the demon.
- At **0 MP**, an unbound aspect disappears and the demon becomes Gray.
- Gray still has a functional neutral version of the action button.
- Reaching zero therefore changes the player’s class without disabling basic gameplay.

## MP Restoration
- Neutral Chroma pickups restore exactly **20 Chroma** during normal gameplay.
- Chroma is an integer value from **0 to 100**; Triangle spending is separate
  from the 20-point pickup value.
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
- Early in Run 1, include a puzzle requiring exactly **10 elemental actions**.
- The sequence forces:
  - 100 → 90 → 80 → 70 → 60 → 50 → 40 → 30 → 20 → 10 → 0 MP.
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
- Binding happens at the Cloaked Demon, never directly at a flame.
- A permanent Bind costs **50 Souls** every time a new element is committed.
- Binding the element that is already bound is a free no-op.
- A **Bound Aspect** remains associated with the demon even when Chroma reaches zero.
- Example:
  - Unbound Fire + 0 MP → Gray.
  - Bound Fire + 0 MP → Fire remains stored.
- A bound aspect can regain its elemental power through neutral Chroma restoration without requiring another matching flame.
- Binding updates the save-file elemental identity and the hub flame.
- Binding is a persistence and recovery upgrade, not a prerequisite for
  opening mandatory elemental doors.

## Flame Swapping and Fusion
- A normal flame interaction is an explicit **Swap** costing **5 Souls**.
- Swap changes the current aspect only; it does not change the bound aspect,
  save-file color, or hub flame.
- **Fusion** is a separate, confirmed flame action costing **5 Souls**.
- Fusion does not require a bound element. It uses the current aspect and the
  contacted flame as its two inputs.
- The result becomes the current aspect immediately, but remains unbound until
  the player confirms a 50-Soul Bind at the Cloaked Demon.
- An unbound result may be used for combat, elemental doors, and another valid
  fusion. Binding is not a fusion permission gate.
- Fusion pairs are explicit and unordered:
  - Fire + Water → Shadow.
  - Fire + Electric → Ground.
  - Water + Electric → Grass.
  - Grass + Water → Ice.
- Hybrids never happen accidentally. The player must select Fuse and confirm
  the displayed recipe.

## Current Aspect, Bound Aspect, and Elemental Doors
- The **current aspect** is the active run-time color used by Triangle, combat
  presentation, fusion input, and elemental door checks.
- The **bound aspect** is the persistent identity used by zero-Chroma recovery,
  save data, and the hub flame.
- A current unbound fusion can open a required elemental door without first
  paying the 50-Soul Binding cost.
- Once an elemental door is solved, it remains unlocked and does not re-check
  Binding or Chroma later.

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
Problems → Find/Swap/Fuse Flames → Manage Routing and Resources → Visit the
Cloaked Demon to Bind a Chosen Aspect → Build Gear/Stats → Defeat Boss →
Progress to More Complex Dungeons**

The elemental system should gradually evolve from a guided **key-and-lock training system** into a flexible buildcraft system where experienced players deliberately manipulate Chroma, aspects, routes, and hybrids.
