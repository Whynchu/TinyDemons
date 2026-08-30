# Tiny Demons — Elemental Binding and Flame Fusion Design

Status: approved design and implemented core; R6+ entrance-orb fusion-gate curriculum included

This document is the canonical player-facing and systems-facing specification
for elemental swapping, fusion, and permanent Binding. It records the design
decisions made after the first Chroma implementation and supersedes the older
speculative Binding/Blending sections in the Chroma design documents.

Related documents:

- [`Tiny Demons — Elemental Chroma System Design.md`](Tiny%20Demons%20%E2%80%94%20Elemental%20Chroma%20System%20Design.md)
- [`elemental-chroma-implementation-plan.md`](elemental-chroma-implementation-plan.md)
- [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md)
- [`soul-economy-and-fire-exchanges.md`](soul-economy-and-fire-exchanges.md)
- [`elemental-slimes-and-combat-plan.md`](elemental-slimes-and-combat-plan.md)

## 1. Design intent

The system should make elemental identity a meaningful build decision without
turning mandatory dungeon puzzles into an expensive resource tax.

The design therefore separates three jobs:

1. **Flames** provide temporary elemental actions: swapping and fusion.
2. **The Cloaked Demon** records a permanent elemental commitment through
   Binding.
3. **Dungeon gates** have explicit puzzle-color, current-element, or
   entrance-orb requirements. Entrance-orb gates inspect the shared Orb Room
   state, not the player's current form alone.

This preserves the excitement of elemental routing while ensuring that a
required Ice, Ground, Grass, or Shadow door can be solved inside the dungeon
without first paying every permanent Binding cost.

Binding remains valuable because it preserves the chosen element when Chroma
reaches zero, enables reliable elemental recovery, updates the save-file
identity, and changes the element displayed by the hub flame.

## 2. Terminology and state ownership

### 2.1 Current element

The **current element** is the player's active run-time elemental identity.
It is the element used by:

- the current Triangle ability;
- elemental class presentation and combat-element mapping;
- current-element door checks;
- charging a matching entrance Orb;
- the first input to a flame fusion;
- the player's current color while Chroma is active.

The current element may be bound or unbound. A flame swap or fusion changes the
current element without changing the persistent profile by itself.

### 2.2 Bound element

The **bound element** is the player's persistent elemental commitment. It is
written by the Cloaked Demon only.

Binding the current element:

- saves that element to the profile;
- changes the persistent elemental color used by the file;
- changes the hub flame to that element on later visits/runs;
- preserves the elemental identity when Chroma reaches zero;
- allows neutral Chroma restoration to recover that bound identity without a
  matching flame.

The bound element is not a second simultaneous combat type. The current
element remains the active combat identity while it is charged. No dual-type
damage calculation is introduced by Binding.

### 2.3 Chroma

Chroma remains the run-local elemental resource:

- maximum: 100;
- full elemental Triangle action: 10 Chroma;
- neutral Chroma pickup: 20 Chroma;
- unbound elemental depletion follows the existing Gray fallback rules;
- bound elemental depletion follows the existing dormant-bound rules.

Binding state and Chroma amount are separate values. A player can have a
bound Water identity while temporarily using an unbound Grass or Ice fusion.

### 2.4 Starter flame

The file's `starter_flame` remains the initial/default flame selected during
file creation. It is used by the hub when no permanent Binding has been made.
Once the player binds an element, the bound element becomes the persistent hub
flame identity. The starter flame and the bound element must not be conflated
in the save schema.

## 3. Final economy contract

All values below are Souls, not Chroma and not equipment-fusion materials.

| Action | Location | Cost | Persistent profile change |
| --- | --- | ---: | --- |
| Swap/use a flame | Elemental flame | 5 | None; changes current element only |
| Fuse current element with a flame | Elemental flame | 5 | None; creates an unbound current result |
| Bind current element | Cloaked Demon | 50 | Saves/updates the bound element |
| Bind the already-bound element | Cloaked Demon | 0 | No-op; no Soul charge |

Binding is a flat 50-Soul commitment for every new permanent element. There is
no first-bind discount or later-bind discount in this version of the design.

The 5-Soul flame actions are intentionally much cheaper than Binding. A player
can explore a route, solve an elemental door, or test a fusion without risking
their permanent identity. The 50-Soul payment is reserved for the decision to
make the current element persist through the profile and hub.

The existing equipment-fusion Soul ladder remains a separate economy. This
design changes only elemental flame actions and elemental Binding.

## 4. Flame actions

A contacted flame uses one interaction input with two deliberate gestures:

- Release the button after a quick press to **Swap**.
- Hold the button through the short `0.35`-second threshold to **Fuse**.

Swap resolves on release so the game can distinguish it from a held Fuse. A
successful Fuse resolves as soon as the threshold is reached; the player does
not need to release the button or navigate a secondary menu.

### 4.1 Swap

Swap is the normal flame interaction. It is a single explicit transaction:

1. Verify that the player has at least 5 Souls.
2. Verify that the flame can be used in the current room/state.
3. Spend exactly 5 Souls.
4. Consume the flame use.
5. Set the current element to the flame's element.
6. Apply the normal one-use flame restoration behavior already established by
   the fire system: full HP and full active Chroma, with no passive recovery.

Swap never changes the bound element, save-file color, or hub flame. The
player may later visit the Cloaked Demon if they want to make the current
element permanent.

If the player uses a flame matching the current element, it is a paid normal
flame service, not a fusion, as long as it can restore missing HP or Chroma.
When the player already matches the flame and both HP and active Chroma are
full, the flame is not interactable and cannot consume Souls for no effect. It
must not silently create a second transaction or alter Binding state.

### 4.2 Fuse

Fusion is also a single explicit flame transaction:

1. Verify that the player has at least 5 Souls.
2. Verify that the current element is a valid fusion input.
3. Verify that the flame's element forms a defined recipe with the current
   element.
4. Spend exactly 5 Souls.
5. Consume the flame use.
6. Set the current element to the recipe result.
7. Mark the result as unbound unless it was already the bound element.

Fusion uses the **current element**, not the bound element, as its first input.
This is what allows a player with no bound element to solve a required hybrid
element door.

Fusion is not available when there is no current elemental identity, such as a
fresh Gray state with no active Chroma. The player must first use a flame to
become an element.

Fusion does not automatically write the profile or change the hub flame. The
result is active immediately and may be used for combat, doors, and another
valid fusion. It becomes persistent only after the player binds it at the
Cloaked Demon.

The fusion interaction should use the normal explicit flame restoration payload
unless playtesting approves a separate fusion-only payload. In either case,
fusion must remain one paid flame use, must not heal passively, and must never
charge both a fusion fee and an additional hidden flame fee.

### 4.3 Invalid or unaffordable actions

- Fewer than 5 Souls: Swap/Fuse is disabled and the flame is not consumed.
- No valid recipe: a held Fuse reports that no fusion is available; a quick
  Swap remains available.
- Gray/no current element: a held Fuse is rejected; a quick Swap remains
  available.
- Same current element with full HP and full active Chroma: the flame is not
  interactable because neither Swap nor restoration would have an effect.
- A rejected action spends no Souls, does not consume the flame, and does not
  change current, bound, Chroma, HP, or save state.
- Fusion must never happen automatically merely because the player approaches
  a different flame.

## 5. Hub Binding panel

The Cloaked Demon keeps its normal dialogue and opens the Hub as before. The
Hub now has a dedicated **BIND** panel for permanent Binding. A flame can never
perform a permanent bind.

The menu should show:

```text
CURRENT: ICE
BOUND: GRASS
BIND ICE — 50 SOULS
```

After confirmation and successful payment:

- the current element becomes the bound element;
- the profile's bound-element field is updated;
- the save file's persistent elemental color is updated;
- the hub flame presentation updates to the bound element;
- the binding UI confirms the new persistent identity;
- the player may continue using the current element without another flame use.

If current and bound already match, the Hub panel displays that the element is
already bound and disables the action. If the player has no current element,
the bind action is unavailable.

Binding must be atomic. Insufficient Souls or a cancelled confirmation leaves
every runtime and profile value unchanged.

### 5.1 Fusion results and Binding

Fusion results are intentionally **unbound** until confirmed at the Demon.
This gives the system a clear two-step rhythm:

```text
Flame: create the new current element
→ Cloaked Demon: pay 50 Souls to preserve it permanently
```

An unbound result can still open a matching elemental door and can continue a
valid fusion chain. Binding is not a prerequisite for fusion.

The player may therefore reach Ice without paying a Binding fee first, then
decide whether Ice is valuable enough to preserve:

```text
Swap to Water: 5 Souls
→ Fuse Water + Electric → Grass: 5 Souls
→ Fuse Grass + Water → Ice: 5 Souls
→ Optional Bind Ice at the Demon: 50 Souls
```

If a player already has a bound element, binding a later fusion result still
costs the flat 50 Souls. No automatic binding or hidden discount is applied.

## 6. Approved recipe table

Fusion pairs are commutative: `Fire + Water` and `Water + Fire` are the same
recipe. Only listed recipes are valid.

| Input A | Input B | Result | Visual identity |
| --- | --- | --- | --- |
| Fire | Water | Shadow | Purple |
| Fire | Electric | Ground | Orange |
| Water | Electric | Grass | Green |
| Grass | Water | Ice | Light blue/aquamarine |

The recipe table is data, not color arithmetic. Future elements may be added
without changing the transaction or Binding model.

Neutral/Normal/Gray is not a fusion input in this slice. A missing recipe is a
normal Swap-only flame interaction, not an error and not an automatic blend.

## 7. Door and puzzle contract

Every connection declares one gate type:

- **Puzzle-color gates** read `active_puzzle_color`, which is changed by the
  ordinary shared Orb color flow. A fusion result is exclusive: charging a
  mixed palette clears the ordinary Puzzle Color key, so it cannot satisfy
  either input-color door. A color gate that was already opened is latched and
  remains open.
- **Current-element gates** read the player's active element, including an
  unbound fusion result. They do not require the element to be saved or bound.
- **Entrance-orb gates** require the player to strike a shared Orb Room orb
  with the named elemental result. The orb charge updates the shared room
  palette/state and latches the matching connection. Merely changing into the
  required element never satisfies this gate.

When a gate's requirement is satisfied:

1. The door opens or the puzzle accepts the interaction.
2. The door's solved/unlocked state is latched for the applicable run/profile.
3. Later loss of Chroma, swapping, death recovery, or Binding changes cannot
   unexpectedly re-lock the solved door.

Required dungeon progression must never require the player to pay the 50-Soul
Binding cost merely to pass. A generated or authored route must guarantee:

- the input flame needed for the recipe is reachable;
- the recipe's second flame is reachable;
- a matching entrance Orb is reachable before each mandatory fusion gate;
- the required Orb Room and door are reachable after the fusion, without
  inheriting an unrelated ordinary color key;
- the route does not depend on an unbound element surviving an arbitrary
  resource depletion event;
- a failed or cancelled interaction leaves a recoverable route.

Optional secret or mastery doors may explicitly require a permanently bound
element, but that must be communicated as optional content rather than used as
the critical path.

### 7.1 Generated fusion curriculum

Procedural runs begin requiring a fusion result on Run 6 (the generator's
`completed_runs >= 5` threshold). Run 6 places two input flames on the main
route before a mandatory result-element door. The input pair rotates across
the three base combinations on later early fusion runs so the curriculum does
not always teach the same hybrid first.

Run 8 and later teach the chained Water + Electric → Grass, then Grass + Water
→ Ice sequence. The Grass and Ice gates are each placed after their required
input flames. The player charges the shared Orb Room with each result before
passing its corresponding entrance-orb gate. The second Orb is placed beside
the depth-10 Water fire room, before the Ice gate, rather than behind that
gate. Layout validation performs a reachability pass for every generated
fusion gate, including reaching an Orb Room with the required result, and the
solved state is latched when the Orb charge opens the route.

## 8. Chroma and zero-MP behavior

The existing Chroma rules remain the baseline:

- An unbound current element loses its elemental identity when Chroma reaches
  zero and resolves to Gray behavior.
- A bound element remains associated with the player at zero Chroma and can
  recover its elemental identity through neutral Chroma restoration.
- A temporary unbound fusion result is therefore powerful immediately, but
  Binding is what makes that identity reliable through depletion and future
  runs.

The implementation must make the zero-Chroma transition explicit when the
current and bound elements differ. The recommended behavior is to preserve the
bound element as the recovery/default identity while allowing the current
unbound fusion to remain valid long enough for already-solved doors to stay
solved. This must be covered by focused state tests before production use.

## 9. Player-facing UI and feedback

### Flame prompt

The flame prompt displays the 5-Soul cost. The interaction itself has two
deliberate gestures rather than a secondary action menu:

```text
quick press/release: SWAP — 5 SOULS
hold: FUSE WATER + ELECTRIC → GRASS — 5 SOULS
```

Holding at a non-fusable flame does not fall back to Swap. The interaction is
unavailable when the player already matches the flame and both HP and active
Chroma are full.

### Hub Binding panel

The Hub's BIND panel, reached by accepting the Cloaked Demon's normal Hub
invitation, must display:

- current element and color;
- bound element and color, or `NONE`;
- the flat `50 SOULS` bind cost;
- the player's Soul balance;
- a confirmation step before charging Souls;
- a clear success message when save/hub identity changes.

The visual language should distinguish:

- current and unbound: active color plus an `UNBOUND` marker;
- current and bound: active color plus a `BOUND` marker;
- Gray/no active element: neutral/gray state.

### Hub flame

The hub flame should resolve its presentation in this order:

1. Bound element, if one exists.
2. File starter flame, if no bound element exists.

Temporary swaps and unbound fusion results must not rewrite the hub flame.

## 10. Persistence and lifecycle

Profile data should distinguish at least:

```text
starter_flame: StringName       # file creation default
bound_element: StringName       # NONE until first successful Bind
has_bound_element: bool         # explicit state; avoids empty-string guessing
```

`current_element`, current Chroma, and an unbound fusion result remain run-time
state. They must not be written as permanent profile identity during a flame
interaction.

Recommended lifecycle behavior:

- New run: current element starts Gray/None at 0 Chroma; bound element
  persists.
- Hub entry: the hub flame shows bound element when available, otherwise the
  starter flame.
- Room transition: current element and unbound fusion state remain available
  for the run unless the existing run-reset contract says otherwise.
- Save/load: only the bound element and starter flame are restored as durable
  identity; a temporary unbound current must not silently become bound.
- Death/run reset: restore the last valid bound/default state according to the
  existing run lifecycle, with no free Binding.

The save schema must add the bound-element fields with a deliberate migration
default. Existing Chroma-era files with no bound element should load as
`has_bound_element = false`; the starter flame remains their fallback.

## 11. Class and combat interaction

Binding is not a second combat typing layer.

- The current element determines the active Triangle ability and current class
  presentation.
- A fusion result becomes the current class immediately, even while unbound.
- The bound element supplies persistence/recovery behavior, not an additional
  damage type.
- Player damage maps the current aspect to the existing combat element catalog.
- Current-element gates use current aspect identity, not damage effectiveness;
  entrance-orb gates use their latched shared Orb state.
- Equipment fusion remains unrelated to elemental fusion.

Any future dual-element attack, passive inheritance, or bound/current stat
stacking requires a separate design decision and must not be inferred from
this document.

## 12. Design risks and safeguards

### Binding feels too expensive

The 50-Soul fee is intentional because it changes persistent file identity.
The player can still swap, fuse, and solve mandatory doors for 5 Souls per
flame transaction. If Binding is too rare in playtesting, adjust Soul income
or the timing of the Binding unlock before reducing the contract silently.

### Fusion becomes accidental

Flame interaction uses a deliberate gesture: a quick press performs Swap, while
holding the interaction button through the short fusion threshold performs
Fuse. A flame encounter cannot infer fusion from the presence of a bound
element or from the player's current color alone.

### A required gate becomes a resource trap

Gate validation must prove the flame/recipe/Orb/door sequence before accepting
a layout. Current-element and entrance-orb gates must both latch completion so
later Chroma changes cannot invalidate progress.

### Temporary elements become confusing

Flame feedback and the Demon dialogue must identify `UNBOUND` clearly. The
player should know that they can use the element now but have not paid the
50-Soul persistence cost.

### Recipe growth becomes unmaintainable

Recipes belong in a dedicated catalog with canonical unordered keys, stable
result IDs, display colors, and validation tests. Do not scatter pairwise logic
through flame, player, or door scripts.

## 13. Final player flows

### First permanent element

```text
Start Gray at 0 Chroma
→ use starter flame for 5 Souls
→ current element becomes the starter element
→ visit Cloaked Demon
→ confirm BIND for 50 Souls
→ save file and hub flame now use the bound element
```

### Required hybrid door without prior Binding

```text
Use Water flame for 5 Souls
→ current Water
→ use Electric flame and choose FUSE for 5 Souls
→ current Grass, unbound
→ use Water flame and choose FUSE for 5 Souls
→ current Ice, unbound
→ charge the shared Orb with Ice
→ Ice entrance-orb door opens and remains unlocked
→ optionally bind Ice at the Demon for 50 Souls
```

### Bound swap versus fusion

```text
Bound Water
→ Electric flame
→ SWAP for 5: current Electric, bound Water remains
or
→ FUSE for 5: current Ground, unbound; bound Water remains
→ visit Demon later to bind Ground for 50
```

## 14. Definition of done for the design

The design is ready for implementation when the following are accepted:

- current and bound elements are separate state values;
- flame Swap and Fuse each cost 5 Souls;
- Fusion works without any bound element;
- every permanent Bind occurs at the Cloaked Demon and costs 50 Souls;
- Fusion results remain unbound until the Demon confirms Binding;
- current-element gates accept current unbound elements and latch open;
- entrance-orb gates require the matching mixed result to charge an Orb and
  latch open;
- the four initial recipes are data-driven and commutative;
- save/hub identity changes only after successful Binding;
- zero-Chroma behavior is covered for bound, unbound, and current/bound-mismatch
  states;
- the existing equipment-fusion Soul economy remains separate.
