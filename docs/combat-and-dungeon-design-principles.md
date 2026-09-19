# Tiny Demons Combat and Dungeon Design Principles

Status: current player-facing design authority

Scope: elemental identity, enemy composition, dungeon interaction, and
minimalist content expansion

Owner: combat, dungeon, progression, and content-authoring design

Current code: `AspectCatalog`, `PlayerChromaComponent`, flame/binding/fusion
flows, `DungeonGraph`, authored run definitions, R6+ route generation, and the
current player attack components

Verification: combat and Chroma smoke tests, authored/generated route tests,
focused scene checks, and manual native-resolution playtests

Supersedes: none; this document consolidates the accepted direction from the
elemental, dungeon, enemy, and long-term composition plans

Updated: 2026-09-18

## 1. Product intention

Tiny Demons is a compact action dungeon RPG with a large amount of replayable
expression. It should feel small, readable, and fast to learn while allowing
many different decisions to emerge from a few interacting rules.

The player chooses one of three primary starting flames—Fire, Water, or
Electric—then discovers additional flames through dungeon exploration, flame
attunement, and fusion. Elements are class identities and combat modifiers,
not a requirement that every room or dungeon be an elemental puzzle.

The intended long-term loop is:

```text
choose a starting identity
  -> explore a readable dungeon
  -> fight, route, and discover
  -> make optional elemental/object interactions
  -> earn flames, abilities, gear, and mastery
  -> return to the hub and refine the loadout
  -> revisit the world with more options
```

The game is deliberately minimalist in rules and presentation, but should be
“massively tiny”: a small number of mechanics should combine into a large
number of encounters, routes, and player solutions.

## 2. Design pillars

### 2.1 Small rules, deep combinations

Prefer one clear rule that combines with several other rules over a separate
system for every situation. A new mechanic should create new decisions in
existing rooms before it creates a new category of content.

### 2.2 Elements are classes, not dungeon keys

The current element changes how the player fights, spends Chroma, and solves
optional problems. A matching element may reveal a shortcut, secret, reward,
or alternate route. The ordinary critical path should not require a specific
element unless a safe alternate solution or temporary access is provided.

### 2.3 Places have identities independent of elements

Slimey Depths is a normal foundational dungeon, not a Water tutorial level.
The same dungeon should be playable by Fire, Water, and Electric starters, with
the player’s class changing the experience rather than determining access.

Future places should have their own visual, spatial, enemy, and hazard identity
while offering several elemental opportunities inside them.

### 2.4 Readability before complexity

At native resolution, the player must understand what an enemy or object is
about to do. Silhouette, animation, sound, timing, and color should communicate
more than text or UI explanation.

### 2.5 Interactions should be juicy but bounded

Actions should have satisfying anticipation, impact, hit reaction, sound,
particles, and recovery. Effects should remain short, legible, and affordable
on low-end hardware. Do not build a universal elemental-reaction simulator.

## 3. Elemental identity model

### 3.1 Primary and derived flames

The current elemental catalog distinguishes three starter flames from later
elemental identities:

| Group | Elements | Meaning |
|---|---|---|
| Primary | Fire, Water, Electric | Starting class choices and early world identities |
| Derived | Shadow, Ground, Grass, Ice | Discoveries produced through fusion and later progression |

The current fusion recipes are:

```text
Fire + Water      -> Shadow
Fire + Electric   -> Ground
Water + Electric  -> Grass
Water + Grass     -> Ice
```

These recipes are progression foundations, not permission to add seven large
skill trees immediately. Derived flames should first prove a distinct combat
and interaction identity before receiving a broad content surface.

### 3.2 Current, bound, and mastered

These are separate concepts:

- **Current element:** the class package active during the present run.
- **Bound element:** the persistent identity retained for profile and depleted
  Chroma behavior.
- **Mastered ability:** a learned technique that may eventually be equipped
  outside its native element.

Changing the current element must not erase the player’s equipped abilities or
previous progress. Binding should preserve identity, not prevent experimentation.

### 3.3 Future ability loadout

The intended future loadout has three ability roles:

1. Regular magic: quick, reliable, lower-commitment elemental action.
2. Held magic: charged or held high-impact spell with positional commitment.
3. Held attack: charged physical or hybrid attack that changes combat rhythm.

The universal attack, roll, guard, target, spin, and charge foundations remain
available. Elemental abilities should modify or extend those foundations rather
than replace the entire combat kit.

Each element eventually needs a small signature package, not an oversized tree.
Mastery may allow a native ability to travel across elements, with balance
managed through power, cost, or secondary-effect differences.

### 3.4 Class identity targets

These are directional identities, not final balance values:

| Element | Combat identity | Environmental expression |
|---|---|---|
| Fire | Burst, aggression, expensive commitment | Burn, melt, destroy |
| Water | Efficiency, control, knockback, area shaping | Extinguish, flow, reveal, fill |
| Electric | Stun, chaining, targeting, tempo | Power, conduct, activate |
| Grass | Sustain, drain, regeneration, restraint | Grow, restore, bind |
| Shadow | Deception, curse, phase, lifesteal | Conceal, possess, bypass |
| Ground | Defense, armor, stagger, force | Break, brace, raise, lower |
| Ice | Slow, freeze, preservation, momentum | Freeze, solidify, preserve |

An element should first feel different in combat. Environmental interactions
are a bonus expression of that identity, not the sole reason the element exists.

## 4. Enemy taxonomy

Enemy definitions must distinguish combat role from movement. Aerial is a
movement layer, not a replacement for melee, ranged, or support.

### 4.1 Primary combat roles

#### Melee

Closes distance and threatens the player directly. It needs a readable attack,
a clear counter, and a punish window.

#### Ranged

Controls space from a distance. It needs a visible wind-up, a readable attack
path, and vulnerability while firing, reloading, or repositioning.

#### Support

Changes the effectiveness or behavior of other enemies. It must create a
visible relationship and provide more than one counter: kill it, interrupt it,
separate it, or exploit its target.

### 4.2 Movement traits

Movement is described separately:

- Ground
- Aerial
- Stationary
- Burrowing or phased, when later content proves the need

An aerial enemy may eventually be melee, ranged, or support. The first aerial
enemy can remain a simple dive attacker.

### 4.3 Initial core roster

The first roster should remain deliberately small:

| Enemy | Role | Movement | Core question |
|---|---|---|---|
| Biter slime | Melee | Ground | Can I manage spacing and punish the bite? |
| Spitter slime | Ranged | Ground | Can I close distance without losing the room? |
| Healer slime | Support | Ground | Do I remove support or break its connection? |
| Cave bat | Melee/hazard | Aerial | Can I read and evade the dive? |

The Biter is the existing basic slime: its hop is movement and telegraphing;
its bite is the actual threat. The roster should not expand until these four
produce satisfying encounters alone and in combinations.

### 4.4 Enemy contract

Every enemy should have:

- one primary behavior;
- one strong telegraph;
- one reliable counter;
- one punish window;
- one memorable reaction;
- one reason to combine it with another role.

Enemy variants should add one meaningful change—timing, movement, terrain,
defense, or defeat consequence—not five new systems at once.

Biome families may reuse roles without becoming reskins. A skeleton soldier
can be a melee expression with resurrection or weapon timing; a ghost can be a
support or ranged expression with phasing; a bone archer can reuse the ranged
contract. The role vocabulary remains stable while the presentation and one
consequence change.

## 5. Dungeon and elemental interaction

### 5.1 Three gate classes

Every interaction should be classified during design:

1. **Mandatory and universal:** the critical route is solvable by any valid
   loadout.
2. **Optional and elemental:** a matching element opens a secret, shortcut,
   reward, elite encounter, or alternate route.
3. **Multi-solution:** different elements or objects solve the same problem in
   different ways.

Avoid mandatory elemental locks that merely require menu administration. If a
mandatory element is ever justified, provide temporary access, an alternate
solution, or a clearly telegraphed return path.

### 5.2 Elemental opportunity examples

These are interaction patterns, not a requirement for every biome:

- Fire burns growth, wax, or blockages.
- Water extinguishes flames, fills channels, or reveals residue.
- Electric powers mechanisms, stuns devices, or activates conductors.
- Grass restores plants, grows bridges, or binds hazards.
- Shadow reveals possession, hidden paths, or phase routes.
- Ground breaks weak walls or stabilizes dangerous terrain.
- Ice freezes channels, creates surfaces, or preserves mechanisms.

The same object may support multiple solutions. Water may fill a channel while
Ice freezes it into a bridge; Ground may break around it; Electric may activate
the destination mechanism.

### 5.3 Orb objects

The existing shared Orb/vault state remains useful for generated optional
branches. A physical carryable Orb is a separate authored puzzle object.

A physical Orb must:

- have a visible origin pedestal and destination pedestal;
- be droppable without permanent loss;
- return after death or a controlled reset;
- never strand the player behind a door;
- support a non-destructive recovery route;
- create a meaningful movement or combat decision.

Use physical Orbs in special puzzle sections, not as a universal replacement
for all gates.

### 5.4 Core dungeon-puzzle vocabulary

Elemental interactions are only one part of dungeon problem solving. The game
should also use a small, reusable vocabulary of physical and spatial objects:

| Object | Player question | Safe design rule |
|---|---|---|
| Key | Where is the lock, and is this worth carrying forward? | Keys are readable, stable, and never permanently lost through ordinary failure |
| Switch | What changed when I activated it? | The result is visible in the room or on the minimap |
| Lever | Which route or state did I alter? | Use clear before/after states and avoid invisible global effects |
| Pressure plate | What must occupy or remain on this surface? | Provide a clear reset state and do not strand the player |
| Breakable obstacle | What tool, attack, or element can remove this? | The obstacle communicates its weakness and has a non-destructive fallback when required |
| Carryable object | Can I move this safely through the space? | The object has a known origin, destination, reset, and recovery route |
| Timed mechanism | Can I act within the window? | Use short, learnable timing challenges rather than trial-and-error punishment |

These objects should create spatial reasoning, not inventory administration.
The player should understand what changed after an interaction and retain a
mental model of the dungeon.

### 5.5 Puzzle design principles

Puzzles should follow a simple teaching curve:

1. Introduce one object or rule in a safe room.
2. Ask the player to use it with ordinary movement or combat.
3. Combine it with one known enemy or environmental pressure.
4. Offer an optional shortcut, reward, or alternate route for mastery.

The game should avoid puzzles that depend on hidden interactions, pixel-perfect
placement, or repeated failure with no new information. A failed attempt should
leave the player understanding more than before.

The critical path must remain recoverable:

- keys cannot disappear permanently through ordinary death;
- switches and levers must have deterministic reset or persistence rules;
- carryable objects must return to a known safe state;
- a room cannot seal the player away from the solution object;
- a puzzle must not require an ability the player could reasonably have lost;
- puzzle state must survive or reset consistently when the room is revisited.

Combat and puzzles should support one another without making every puzzle a
combat encounter. A Biter may pressure a switch interaction, but some rooms
should allow the player to think, explore, and manipulate the space without
being attacked.

### 5.6 Dungeon identity

Each location should have a spatial and emotional identity independent of the
player’s element. A location should define:

- one visual rule;
- one spatial rule;
- one danger or environmental behavior;
- a small role-based enemy roster;
- one optional discovery language.

Slimey Depths is the neutral foundational dungeon. It teaches combat,
Chroma, route reading, and the first elemental opportunities without requiring
Water or any other starter.

## 6. Minimalist content rules

- Prefer four strong enemy roles over a large bestiary.
- Prefer one room idea executed well over rooms containing every mechanic.
- Do not make every enemy have every elemental reaction.
- Do not make every biome require a new AI family.
- Do not add a currency when an existing resource can express the decision.
- Do not add a skill-tree node unless it changes a real player choice.
- Do not make an optional reward mandatory through hidden power scaling.
- Reuse systems through composition, not copy-pasted special cases.
- Keep effects short, readable, and within the low-end mobile performance budget.

The target is not low content. The target is high content density per rule.

## 7. First vertical-slice acceptance bar

The first complete proof should use Slimey Depths and include:

- Fire, Water, and Electric starter experiences in the same dungeon;
- Biter, Spitter, Healer, and one readable aerial enemy;
- one encounter for each single role;
- at least three mixed-role encounters;
- one optional elemental interaction;
- one non-elemental solution to a dungeon problem;
- one recoverable physical-object or Orb section;
- one key, switch, lever, pressure-plate, or breakable-obstacle interaction;
- one meaningful reward choice;
- one elite or boss encounter that tests positioning and target priority;
- native-resolution readability and stable low-end performance evidence.

The slice succeeds when the same authored dungeon feels meaningfully different
for each starter without requiring a different dungeon or a mandatory color
key chain.

## 8. Change review questions

Before approving new content, ask:

1. What existing role, element, or dungeon rule does this use?
2. What new player decision does it create?
3. Is the interaction mandatory, optional, or multi-solution?
4. Can the player read it at 240×160?
5. Does it work with all three primary starters where it is on the critical
   route?
6. Does it add one clear idea or several overlapping systems?
7. Can it be composed from existing definitions and owners?
8. What focused test or manual acceptance proves the player-facing contract?
9. What is its expected cost on the Samsung A17 target?
10. Does it preserve the game’s small, expressive ruleset?
