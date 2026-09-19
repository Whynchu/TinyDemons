# Tiny Demons Design Philosophy Interview Questionnaire

Status: active discovery questionnaire

Scope: product identity, player experience, combat, elements, dungeons,
puzzles, progression, presentation, accessibility, production scope, and
verification

Owner: game direction and production

Current code: use [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md),
[`AUDIT.md`](AUDIT.md), and the feature-specific design documents as the
implementation reference while answering

Verification: interview decisions should be reconciled against current code,
existing player-facing contracts, and focused vertical-slice evidence

Supersedes: none; this is a discovery tool, not a replacement for approved
design authorities

Updated: 2026-09-18

## How to use this document

This is an interview script for a producer, designer, or AI collaborator to
use with the project owner. It is intentionally exhaustive. Do not answer all
questions in one sitting if doing so produces vague answers.

For every answer, classify the decision as one of:

- **Principle:** should remain true across the whole game.
- **Contract:** a specific player-facing rule that must be implemented and tested.
- **Direction:** an approved target that may still change in detail.
- **Experiment:** a question to prototype before committing.
- **Preference:** desirable but not worth expanding scope for.
- **Rejected:** explicitly not part of Tiny Demons.

The interviewer should ask follow-ups when an answer is abstract. Convert
“fun,” “epic,” “simple,” “like Zelda,” or “like Hollow Knight” into observable
player behavior, a rule, a reference moment, or an acceptance test.

When answers conflict, do not silently resolve the conflict. Record both
statements and ask which one has priority.

## 1. Product identity

1. Complete this sentence: “Tiny Demons is the game where the player…”
2. What should a player tell a friend about the game after ten minutes?
3. What should make the game recognizable from a screenshot?
4. What should make the game recognizable from five seconds of gameplay?
5. What should make the game recognizable with the art removed and only the
   controls represented?
6. Which three existing games are useful references, and what specific lesson
   comes from each one?
7. Which parts of those references must not be copied?
8. What does “massively tiny” mean in practical terms?
9. What should the game deliberately refuse to become?
10. Is the primary fantasy being a skilled fighter, an explorer, a class
    builder, a puzzle solver, a collector, or something else?
11. Which fantasy is the priority when two systems compete for attention?
12. What is the intended emotional tone: cozy, mysterious, dangerous, funny,
    melancholic, heroic, strange, or another combination?
13. What should the player feel after a successful run?
14. What should the player feel after a failed run?
15. What is the one experience that would make the project worth finishing?

## 2. Audience and promise

1. Who is the primary audience?
2. Is the game for players who enjoy mastery, discovery, collecting, story,
   speed, experimentation, or relaxing repetition?
3. What level of genre knowledge can the game assume?
4. What should a new player understand without reading a wiki?
5. What may remain mysterious for a while?
6. How difficult should the first hour feel?
7. What type of player frustration is acceptable?
8. What type of frustration is unacceptable?
9. Is the game intended to be completed once, replayed for mastery, or played
   indefinitely as a run-based experience?
10. What is the intended session length on desktop?
11. What is the intended session length on mobile?
12. Should a player be able to make meaningful progress in a five-minute
    session?

## 3. Player fantasy and controls

1. What should the player feel they are physically doing when they attack?
2. What is the signature player action?
3. Which current actions are essential: attack, roll, guard, target, magic,
   spin, charge, interact, carry, or something else?
4. Which actions are optional depth rather than baseline requirements?
5. What should a beginner use successfully without understanding advanced play?
6. What should an expert do that a beginner cannot do yet?
7. How much precision should come from timing versus positioning?
8. Should attacks commit the player to motion, or should the player remain
   highly mobile?
9. How important are attack recovery windows?
10. Should the player be able to cancel attacks with roll or guard?
11. What should a successful guard feel like?
12. What should a successful dodge feel like?
13. What should a missed attack cost?
14. Should enemies be defeated primarily by damage, positioning, interruption,
   environmental use, or a combination?
15. What controls must work equally well on keyboard, controller, and touch?
16. Which actions may be simplified on touch?
17. What is the minimum viable control layout for a small phone screen?

## 4. Core gameplay loop

1. What is the ideal minute-to-minute loop?
2. What is the ideal room-to-room loop?
3. What is the ideal run loop?
4. What is the ideal multi-run progression loop?
5. How often should the player fight?
6. How often should the player solve a spatial or object problem?
7. How often should the player make a route choice?
8. How often should the player receive a reward?
9. How often should the player safely recover?
10. What should interrupt a long stretch of combat?
11. What should interrupt a long stretch of navigation?
12. What makes one room meaningfully different from the previous room?
13. What is the maximum acceptable run of similar rooms?
14. What is the expected rhythm of a strong run?
15. Where should tension rise?
16. Where should the game deliberately relax?
17. What should make the next room feel anticipated rather than random?
18. What does the player do when they are not fighting?
19. What should the player be thinking about while moving through a dungeon?
20. What should the player remember when returning to the hub?

## 5. Run structure and roguelike identity

1. Which parts of the game are authored and which parts are generated?
2. What must remain fixed between runs?
3. What should vary between runs?
4. Is route variation more important than encounter variation?
5. Is reward variation more important than map variation?
6. What makes a route choice meaningful rather than cosmetic?
7. How clearly should the player see route risk before committing?
8. What does a safe route offer besides lower difficulty?
9. What does a dangerous route offer besides higher reward?
10. Should the player ever knowingly choose a bad route for an interesting
    reason?
11. What can be permanently lost during a failed run?
12. What must never be lost?
13. How much of a run should be recoverable after quitting?
14. Should players be able to abandon a run without penalty?
15. What is the purpose of generated R6+ content that authored Runs 1–5 do not
    already provide?
16. When does a generated run feel meaningfully different rather than shuffled?
17. What prevents generated rooms from becoming repetitive?
18. What prevents authored rooms from becoming solved and stale?

## 6. Elemental identity

1. What does choosing Fire, Water, or Electric promise immediately?
2. How soon should the starter choice matter in combat?
3. How soon should the starter choice matter in exploration?
4. Should the three starter elements be equally powerful but differently shaped?
5. Should one be easier for beginners?
6. What is the one-sentence fantasy of Fire?
7. What is the one-sentence fantasy of Water?
8. What is the one-sentence fantasy of Electric?
9. What is the one-sentence fantasy of Grass?
10. What is the one-sentence fantasy of Shadow?
11. What is the one-sentence fantasy of Ground?
12. What is the one-sentence fantasy of Ice?
13. Are the derived elements classes, hybrid classes, advanced unlocks, or
    temporary run identities?
14. What should fusion change besides the current color or aspect ID?
15. What should binding change?
16. What should happen when Chroma reaches zero?
17. Should each element have a different Chroma economy?
18. Can elements change enemy behavior, or only player abilities?
19. Can elements alter room geometry?
20. Can elements create hazards that harm the player as well as enemies?
21. Should elemental advantages be obvious, discoverable, or both?
22. What happens when two elements interact in the same room?
23. What happens when the player carries a mastered off-element ability?
24. What is the maximum number of active elemental decisions the player should
    make at once?

## 7. Ability loadouts and mastery

1. Is the intended loadout definitely regular magic, held magic, and held
   attack?
2. What is the purpose of each slot in combat?
3. Should every element have all three slots?
4. What is universal and what is element-specific?
5. How many abilities should an element have at launch or first completion?
6. Is the player selecting abilities before a run, during a run, or both?
7. Can abilities be changed freely, only at flames, or only at the hub?
8. What is learned permanently?
9. What is temporary for a run?
10. What does mastery mean mechanically?
11. Does mastery increase power, reduce cost, unlock cross-element use, or add
    a new behavior?
12. How many mastery levels are enough?
13. What prevents the player from equipping the three strongest abilities from
    different elements every time?
14. Should off-element mastery have a cost or limitation?
15. Can abilities combine or mutate when used with another current element?
16. Are skill trees mostly horizontal choices or vertical power ladders?
17. Can a player respec freely?
18. What is the cost of a wrong build choice?
19. How does the Bind menu communicate current, bound, learned, and mastered
    abilities without becoming a spreadsheet?
20. What is the minimum viable prototype for proving this system?

## 8. Combat roles and enemy design

1. Are Melee, Ranged, and Support the only primary combat roles needed now?
2. Is Aerial strictly a movement trait?
3. Which additional movement traits might eventually be needed: stationary,
   burrowing, phased, wall-bound, swimming?
4. What makes a role recognizable at native resolution?
5. What does every enemy telegraph?
6. What is every enemy’s reliable counter?
7. What is every enemy’s punish window?
8. What makes an enemy annoying rather than interesting?
9. How many enemies may share a room before readability breaks?
10. What is the first enemy the player meets?
11. What does the Biter teach?
12. What does the Spitter teach?
13. What does the Healer teach?
14. What does the Bat teach?
15. Should the Healer heal health, grant armor, revive, empower, or alter the
    room?
16. How can the player handle a Healer without always killing it first?
17. How does the player reliably hit an Aerial enemy?
18. What makes ghosts distinct from slimes without requiring a new role?
19. What makes skeletons distinct from slimes without requiring a new role?
20. Which enemy behaviors are worth adding only after the four core roles work?
21. What makes an elite different from a normal enemy?
22. What makes a boss different from an elite?
23. Should enemy variants be defined by role, element, movement, or habitat?
24. Which enemy behaviors must be supported by reusable code rather than room
    special cases?

## 9. Encounter composition

1. What is the simplest good room containing only Melee enemies?
2. What is the simplest good room containing only Ranged enemies?
3. What is the simplest good room containing only Support enemies?
4. What is the first room that combines two roles?
5. Which role combinations are most interesting?
6. Which combinations are unfair or visually noisy?
7. Should the player always be able to identify the highest-priority target?
8. How should the room communicate target priority without text?
9. How much room geometry should matter to an encounter?
10. Should hazards be authored into rooms or generated around encounters?
11. How often should an encounter include a reward-changing decision?
12. What is the expected duration of a normal encounter?
13. What is the expected duration of an elite encounter?
14. How much repetition is acceptable before introducing a new combination?
15. How should encounter difficulty scale across authored runs and generated
    runs?

## 10. Dungeon structure and biome identity

1. What makes Slimey Depths a normal foundational dungeon?
2. What is the defining spatial rule of Slimey Depths?
3. What is the defining danger of Slimey Depths?
4. What is the defining reward or discovery language of Slimey Depths?
5. What makes Haunted Chambers mechanically different?
6. What makes Sacred Grove mechanically different?
7. What makes Burning Crypts mechanically different?
8. What makes a Water-focused area different without becoming a mandatory Water
   class area?
9. What makes an Ice-focused area different?
10. What makes an Electric or storm area different?
11. Can a biome reuse enemy roles with different presentation and one changed
    consequence?
12. What should a player learn in each location?
13. What should a player fear in each location?
14. What should a player look forward to in each location?
15. How many rooms or major landmarks justify a new location?
16. How many new assets and mechanics can a location afford?
17. What should carry across locations so the game still feels cohesive?
18. What should never be repeated between locations?

## 11. Puzzle and object design

1. What is the difference between a puzzle, a gate, a traversal challenge, and
   a combat encounter?
2. Which puzzle objects are core: keys, switches, levers, plates, breakables,
   carryables, timed mechanisms, or something else?
3. How is each object introduced safely?
4. How does the game show that a switch changed something?
5. Can every critical-path puzzle be reset?
6. Can any key or carryable object be permanently lost?
7. What happens if the player dies while carrying an object?
8. What happens if the player leaves a puzzle room unfinished?
9. How can a player recover if they enter the destination room without the
   required object?
10. How much trial and error is acceptable?
11. Should puzzles be solvable through observation, experimentation, combat,
    elemental use, or object manipulation?
12. When is an elemental solution optional?
13. When is an alternate non-elemental solution required?
14. Can one object have multiple elemental solutions?
15. Should puzzles persist when a room is revisited?
16. Which puzzle states must be saved?
17. What is the first puzzle the player learns?
18. What is the first puzzle that combines combat and manipulation?
19. What is the first puzzle that rewards an optional element?
20. What puzzle behavior would be frustrating on touch controls?

## 12. Orb and carryable-object design

1. Is the Orb a key, a tool, a companion object, or a temporary elemental
    charge?
2. What is the emotional appeal of carrying it?
3. How far should it travel?
4. What causes it to drop?
5. Can the player throw it?
6. Can enemies interact with it?
7. Can the player fight while carrying it?
8. Which actions are disabled while carrying it?
9. What does a light hit do?
10. What does a heavy hit do?
11. What happens on death?
12. What happens if the Orb is left behind?
13. Can the Orb be duplicated, reset, or fast-traveled?
14. How does the player know its origin and destination?
15. Does carrying it create a shortcut, reward, boss route, or optional vault?
16. What prevents the mechanic from becoming tedious backtracking?

## 13. Progression, rewards, and economy

1. What is persistent between runs?
2. What is temporary within a run?
3. What does Gold buy that Souls cannot?
4. What do Souls represent emotionally?
5. What does Chroma represent moment to moment?
6. What should a gear drop make the player consider?
7. How often should the player receive a meaningful equipment choice?
8. How many currencies can the game support before it becomes administrative?
9. What makes a stat point exciting?
10. What makes a skill unlock exciting?
11. What makes an elemental discovery exciting?
12. Should rewards change combat, exploration, route choice, survivability,
    or only numbers?
13. How are duplicate rewards handled?
14. How does the game avoid grind being required to maintain power parity?
15. What is the expected time to unlock a new primary flame?
16. What is the expected time to discover a derived flame?
17. What is the expected time to master one ability?
18. What should a player receive after a failed run?
19. What is the maximum acceptable inventory friction?
20. What reward is reserved for exploration rather than combat?

## 14. Hub and long-term loop

1. What should the Hub communicate visually after each major accomplishment?
2. Which hub systems are essential before starting a run?
3. Which systems are optional?
4. What should the player be able to do in under thirty seconds?
5. Which NPCs have evolving roles or dialogue?
6. What changes in the Hub after discovering a flame?
7. What changes after binding an element?
8. What changes after completing a dungeon?
9. What should the player be able to preview before committing Souls or gear?
10. How can the Bind menu remain expressive without becoming administratively
    heavy?
11. What does the player lose or risk by leaving the Hub?
12. What makes returning to the Hub feel like progress rather than interruption?

## 15. Narrative and world meaning

1. What is the player character’s immediate goal?
2. Why do flames and elements exist in the world?
3. What is the Cloaked Demon’s role in the player’s journey?
4. What are slimes in the world: creatures, manifestations, experiments,
    spirits, or something intentionally unexplained?
5. Why do different locations exist?
6. What does a dungeon boss represent beyond being a combat gate?
7. How much story should be delivered through dialogue versus environment?
8. What lore should be optional?
9. What should remain mysterious?
10. Can the player understand the emotional stakes without reading every text
    box?
11. What tone should defeat, death, and recovery have?
12. What makes the world feel connected across runs?

## 16. Presentation and juice

1. What should every player attack communicate visually?
2. What should every enemy hit communicate?
3. What should a successful dodge, guard, interrupt, and kill feel like?
4. Which effects are essential feedback rather than decoration?
5. What is the maximum screen clutter acceptable at 240×160?
6. Which colors are reserved for player information, enemy danger, rewards,
   and puzzle state?
7. How should non-color cues communicate element identity?
8. Which animation frames are gameplay-critical?
9. Which sounds should become learned warning signals?
10. Which effects must be shortened or capped for the Samsung A17?
11. What should remain beautiful even on low settings?
12. Which visual conventions must remain stable across all biomes?

## 17. Accessibility and clarity

1. Can every important elemental distinction be understood without color alone?
2. Can enemy telegraphs be understood without sound?
3. Can important sound cues be reinforced visually?
4. Are small switches, keys, and Orb sockets readable at native resolution?
5. Are timed interactions forgiving enough for touch input?
6. Can the player adjust vibration, audio, or flash intensity?
7. Are screen effects safe for players sensitive to flashing or motion?
8. Does the UI clearly communicate current element, bound element, Chroma, and
   ability readiness?
9. What happens if the player misses an optional clue?
10. Can the player review known dungeon goals without revealing every solution?

## 18. Production and scope

1. What is the smallest complete release that expresses the vision?
2. Which locations are required for that release?
3. Which elements are required for that release?
4. Which abilities are required for that release?
5. Which enemy roles are required for that release?
6. Which puzzle objects are required for that release?
7. Which systems are explicitly post-release or experimental?
8. How many bespoke enemies can the team realistically produce?
9. How many new animations can the team realistically support?
10. How many new tilesets or biome art sets can the team realistically support?
11. Which content can reuse existing scenes and components?
12. Which new feature would create the most maintenance cost?
13. Which feature is most likely to hurt mobile performance?
14. What is the acceptable implementation complexity for a player-facing idea?
15. What should be cut first if the schedule slips?
16. What should never be cut because it defines the game?

## 19. Verification and acceptance

1. What must be proven in a headless test?
2. What must be proven in an authored scene check?
3. What must be manually played?
4. What must be tested on desktop, web, and Android?
5. What are the target frame-time budgets?
6. What are the target transition and startup budgets?
7. What memory behavior is acceptable after repeated room transitions?
8. What constitutes a fair puzzle?
9. What constitutes a readable enemy?
10. What constitutes a meaningful reward?
11. What constitutes a distinct element?
12. What constitutes a successful biome?
13. What constitutes a successful run?
14. What evidence is required before a mechanic becomes a permanent contract?
15. Which metrics should never be used as substitutes for playtesting?

## 20. Decision record template

Use this after each interview session:

```text
Date:
Participants:
Topics covered:

Firm principles:
-

Player-facing contracts:
-

Approved directions:
-

Experiments to prototype:
-

Rejected or deferred ideas:
-

Contradictions discovered:
-

Changes required in current design documents:
-

Changes required in code or data:
-

Evidence still needed:
-
```

The interview is complete when the answers define a coherent first vertical
slice, identify what is deliberately out of scope, and provide acceptance
criteria that can be tested without relying on intuition alone.

