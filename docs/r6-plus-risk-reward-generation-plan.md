# R6+ Risk, Reward, and Elemental Vault Generation Plan

Status: implemented in source; focused Godot verification pending

Scope: generated Run 6 and later layouts only; authored Runs 1–5 remain unchanged

Owner: `puzzle_route_generator.gd`, `puzzle_route_plan.gd`,
`puzzle_progression_planner.gd`, `puzzle_route_solver.gd`, and
`dungeon_layout_generator.gd`; encounter and reward behavior remains owned by
`room_controller.gd` and the existing item/reward services

Current code: generated layouts now add typed route policy metadata, an ungated
R6+ backbone, safe/risk fork-and-rejoin routes, guaranteed primary flames,
optional elemental Orb vaults, route encounter tiers, vault/risk reward policy,
minimap markers, explicit elite slime markers/level bands, and focused
generation coverage. Authored Runs 1-5 retain their existing builders.

Verification: `tests/r6_plus_risk_reward_generation_smoke.gd` plus the updated
generated-route scene/minimap checks; Godot execution, active-run recovery,
enemy-placement playtest, reward policy runtime checks, and manual minimap /
readability checks remain pending until a local Godot executable is available.

Supersedes: the mandatory flame/fusion progression direction for generated R6+
maps in `r7-compact-roguelike-puzzle-generator-plan.md`; that document remains
historical implementation context for the compact generator and existing solver

## 1. Outcome

Generated R6+ dungeons should create informed risk-versus-reward route choices
without depending on undeveloped biome or puzzle systems. The player should be
able to choose between:

- a longer, safer route with ordinary encounters and reliable utility;
- a shorter, harder route with stronger encounters and improved rewards; and
- an optional elite reward route ending in a guarded elemental Treasure Room.

Elemental interaction supports exploration rather than repeatedly interrupting
progression. Every generated map provides Fire, Water, and Electric flames.
Randomized elemental Orb doors protect optional bonus rewards. The main route,
all three primary flames, and the boss must remain reachable without completing
an optional Orb-locked branch.

This plan deliberately improves the map using systems that already exist:
topology, route roles, combat rooms, slime variants, Fire Rooms, Orb Rooms,
Treasure Rooms, the minimap, persistent room state, and gear generation.

## 2. Player-facing contract

The intended generated-run loop is:

```text
Explore the ungated route
    -> discover Fire, Water, and Electric flames
    -> reach a legible route choice
    -> choose safe distance or concentrated danger
    -> discover optional elemental vault doors
    -> prepare the matching Orb state
    -> return and clear an elite Treasure Room
    -> receive meaningfully better gear
```

The player is never asked to switch element merely to advance through a chain
of ordinary doors. Element changes should answer a visible opportunity: a
shortcut, a dangerous optional route, or a known reward.

### 2.1 What the player can rely on

- Every generated map contains exactly one map-owned Fire flame, one Water
  flame, and one Electric flame in this first implementation slice. Legacy
  scaffold-only flame rooms are normalized to ordinary combat rooms; adding
  more map flames remains a later design decision.
- The Hub flame does not satisfy any generated-map flame guarantee.
- All three primary flame rooms are reachable from the map start through the
  ungated traversal graph.
- The boss is reachable without opening any bonus Orb door.
- An opened Orb door remains solved for the active run and can be traversed in
  both directions according to the existing latch contract.
- Optional dead ends always have a declared payoff.
- A dangerous shortcut is genuinely shorter than its safe alternative.
- The map communicates route risk and known reward opportunities before the
  player commits.

### 2.2 What this plan removes from mandatory progression

- Back-to-back ordinary doors requiring different active flame colors.
- Mandatory fusion chains used only to change door state.
- Bonus branches that accidentally contain required flames or boss access.
- Unlabeled dangerous routes whose difficulty is discoverable only after the
  room locks behind the player.
- Ordinary Treasure Rooms presented as elite vault rewards without improved
  encounter or loot contracts.

## 3. Existing boundaries to preserve

- Authored Runs 1–5 and their stable room, connection, and save identities.
- The 35×35 compact map representation and deterministic seed contract.
- `DungeonGraph` as runtime topology authority.
- `DungeonLayoutDefinition` as generated-layout handoff.
- `DungeonMapController` as discovery, shared-Orb, and solved-door authority.
- `RoomPuzzleController` as flame and Orb interaction owner.
- `DungeonMinimapController` as the only player-facing map renderer.
- `RoomController` as encounter, room state, chest, and spawn-placement owner.
- Existing item identities, rarity definitions, source tags, and profile schema.
- Existing frame order and controller scheduling.
- Full-body enemy walkability validation and the runtime recovery path for any
  invalid generated or restored slime position.

Do not add generation policy to `gameplay.gd`. Do not introduce a biome system,
new puzzle room type, or broad combat-balance rewrite as part of this plan.

## 4. Terminology and route roles

Route roles describe player choice and generation intent. They are not biomes.
The first implementation should add or normalize these roles:

| Role | Purpose | Length | Encounter policy | Reward policy |
|---|---|---:|---|---|
| `main` | Reliable critical progression | Baseline | Normal | Normal clears and incidental treasure |
| `safe` | Longer alternative around a dangerous section | Long | Normal or reduced complexity | Utility, flame access, or modest treasure |
| `risk_shortcut` | Shorter alternative to the same rejoin | Short | Elevated | Improved clear reward; saves rooms/time |
| `elite_reward` | Optional challenge branch | Short–medium | Highest local tier | Guaranteed enhanced Treasure Room |
| `primary_flame` | Ungated access to one guaranteed primary flame | Short detour or landmark | None or normal approach | Fire, Water, or Electric access |
| `orb_utility` | Access to an Orb interaction needed for optional vaults | Short detour | Normal | Orb state opportunity |
| `elemental_vault` | Optional Orb-locked edge into elite reward content | Dead end or loop | Elite | Enhanced gear chest |
| `rejoin` | Reconnect safe and risk routes | — | Depends on destination | No reward requirement |
| `shortcut` | Persistent convenience connection | — | None | Traversal value |

Existing compatibility roles such as `fork`, `optional_treasure`, `dig`, and
fusion-specific roles remain readable while active-run compatibility is
required. New generation should emit the new semantic roles, with one explicit
translation point if old consumers still require legacy names.

## 5. Generated map grammar

### 5.1 Critical backbone

Generate and validate the critical backbone before adding optional gates:

1. Place Start/Hub entry and Boss within compact bounds.
2. Grow an ungated main path from Start to Boss.
3. Reserve at least one route-choice interval with a common fork and rejoin.
4. Place pacing landmarks along the backbone.
5. Prove ordinary connectedness and boss reachability.
6. Only then attach flame, utility, shortcut, and vault branches.

The critical path must not contain an entrance-Orb requirement, flame-color
requirement, or fusion-result requirement. Combat-clear doors are still valid
because they express room completion rather than inventory administration.

### 5.2 Pacing landmarks

Each generated map should contain the following broad rhythm, with seeded
variation in exact positions:

```text
Opening combat
    -> first route choice
    -> primary flame opportunity
    -> mid-run utility/rejoin
    -> second primary flame opportunity
    -> risk or elite opportunity
    -> final primary flame opportunity
    -> boss approach
```

Constraints:

- Do not place all primary flames in the opening cluster.
- Do not place two primary flame rooms directly adjacent unless layout repair
  has no valid alternative.
- Avoid more than three ordinary Combat Rooms in sequence.
- Avoid adjacent Fire Rooms, Orb Rooms, or Treasure Rooms.
- A required path should not travel more than six rooms without a landmark,
  route choice, reward, or utility room.
- Every optional dead end ends in Treasure, flame utility, Orb utility, or an
  explicitly labeled elite encounter.

### 5.3 Safe versus risk route

At least one generated section should fork and rejoin around the same
progression interval:

```text
                    Safe A -> Safe B -> Utility
Fork room --------<                           >-------- Rejoin room
                    Risk encounter ---------->
```

Initial structural targets:

- safe side: three to five traversed rooms;
- risk side: one to three traversed rooms;
- risk side saves at least two room transitions where compact geometry permits;
- neither side contains required exclusive state;
- both sides reach the same rejoin and boss progression state;
- choosing one side does not permanently close the other;
- each route's encounter tier and reward policy match its advertised role.

If no valid fork/rejoin can be embedded for a seed, reject the candidate or use
a documented deterministic fallback. Do not silently label equal-length paths
as safe and short.

## 6. Primary flame guarantee

### 6.1 Required flames

Every generated R6+ layout includes map-owned Fire, Water, and Electric flame
rooms. These are primary element sources, not biome labels.

Flame placement happens after the ungated backbone is proven and before bonus
Orb doors are assigned. Each flame receives a stable semantic role and seeded
room identity derived from the layout seed.

### 6.2 Reachability rules

For each primary flame, the solver must prove:

- Start can reach the flame without any elemental or entrance-Orb gate;
- the flame is not behind itself or another required flame;
- the player can leave the flame room and return to the ungated network;
- at least one useful route remains after attuning;
- save/load in the flame room preserves room identity and traversal state.

The three flames may live on the main path, safe branch, or short utility
detours. They may not be placed inside `elite_reward` or `elemental_vault`
content.

### 6.3 Distribution scoring

Candidate scoring should reward useful distribution rather than mere presence:

- graph distance between primary flames;
- placement across early, middle, and late map bands;
- proximity to meaningful junctions;
- reachable return paths; and
- avoidance of three flames on one linear corridor.

Presence is a hard validator. Distribution is initially a scoring preference,
then may become a hard rule after representative seeds are measured.

## 7. Optional elemental Orb doors

### 7.1 Purpose

Elemental Orb doors protect bonus content. They are an invitation to prepare
and return, not a requirement to finish the run.

The generator may choose any supported non-Neutral Orb element, including
primary and fused elemental colors, only when the progression solver proves
that the corresponding Orb state can be produced from interactions available
on that map. The generator queries `ElementCatalog` and `AspectCatalog`; it does
not maintain a duplicate color or fusion table.

Initial eligible set:

- Fire
- Water
- Electric
- Grass
- Shadow
- Ground
- Ice

Neutral/Gray may be introduced later as a distinct vault rule, but should not
be mixed into the first elemental-vault pool.

### 7.2 Placement contract

- Generate zero gates on the critical boss path.
- Generate one or two elemental vault doors per map initially.
- Attach each door to an optional branch, optional loop, or known side pocket.
- Place the reward beyond the gate, never before it.
- Do not place a guaranteed primary flame beyond the gate.
- Do not place the only Orb interaction needed to produce the requirement
  beyond that same gate.
- Do not consume a socket reserved for critical progression or flame access.
- Preserve bidirectional return or a separately validated rejoin.
- Persist the solved connection ID through active-run save and recovery.

### 7.3 Color selection

Color selection occurs after topology, flames, and Orb utility are placed:

1. Ask the solver which Orb elements are producible on the ungated network.
2. Remove Neutral and any unsupported/future element.
3. Weight colors to avoid repeating the same vault requirement in one map.
4. Prefer a mix of one readily accessible primary and one higher-effort fused
   element when two vaults are generated.
5. Record the exact requirement in connection metadata.
6. Re-run stateful solvability and return-path validation.

An optional door may require backtracking, but it may not be permanently
impossible for the generated run context.

## 8. Encounter difficulty by route

### 8.1 Difficulty is route metadata

Do not infer difficulty only from graph depth or room type. Generated Combat,
Special Enemy, and Treasure Rooms should receive an explicit encounter tier or
route challenge profile from the layout handoff.

Suggested initial tiers:

| Tier | Used by | Initial behavior |
|---|---|---|
| `normal` | Main and safe routes | Existing run-rank encounter generation |
| `dangerous` | Risk shortcuts | Additional composition pressure without boss scaling |
| `elite` | Elemental vault Treasure Rooms | Strongest non-boss composition and guaranteed reward protection |

The first implementation should vary encounter composition using existing
systems before adding new enemy behaviors:

- enemy count within current safe caps;
- elemental mix;
- normal versus popcorn composition;
- ambush eligibility;
- one durable lead enemy plus support enemies; and
- modest level offsets bounded by run rank.

Do not solve route difficulty only by multiplying health and damage. The exact
numbers belong in tuning resources and `GAMEPLAY_TUNING.md` after runtime
measurement.

### 8.2 Readability and commitment

- The minimap or doorway presentation identifies a dangerous shortcut and an
  elite reward branch before entry.
- Entry locking follows the existing encounter commitment contract.
- The player can back away before committing where current door semantics
  permit scouting.
- Elite rooms cannot spawn an enemy outside full-body walkable bounds.
- If an enemy cannot be placed after bounded retries, the encounter degrades
  composition or disables that slot; it never leaves an unreachable living
  enemy blocking completion.

## 9. Reward contract

### 9.1 Reward tiers

Rewards must justify route risk while preserving the existing item catalogue
and rarity ceiling.

| Reward tier | Source | Contract |
|---|---|---|
| `standard` | Main/safe clear or ordinary treasure | Existing reward behavior |
| `risk` | Dangerous shortcut completion | Improved clear-reward quality or an additional deterministic roll |
| `vault` | Elite elemental Treasure Room | Guaranteed enhanced gear reward after room clear |

The vault reward should use existing item generation with explicit inputs such
as minimum rarity, source tag, run rank, and plus-stat scaling. Do not create a
parallel item generator.

### 9.2 Initial vault reward policy

The initial implementation should choose conservative, testable guarantees:

- exactly one claimable vault chest per elemental vault room;
- chest remains locked until the elite encounter is complete;
- at least one gear item is guaranteed;
- minimum rarity is one band above the map's ordinary expected floor, clamped
  to each definition's existing rarity ceiling;
- vault source policy prefers live chest/clear-reward definitions appropriate
  to the current run rank;
- duplicate protection remains the responsibility of the current item policy;
- the same chest cannot be claimed again after revisit or save/load;
- reward seed is stable for the run, room, and vault identity.

Multiple items, exclusive definitions, or guaranteed slot targeting are later
tuning decisions. They are not required to prove this route model.

### 9.3 Risk shortcut reward

The shortcut's primary reward is saved time. Its material reward should remain
smaller than an elite vault's reward so the vault retains a distinct purpose.
Initial options, selected during implementation after tracing the current clear
reward path:

- a modest rarity-quality modifier;
- one extra ordinary drop roll; or
- increased gold/Soul yield.

Choose one policy for the first release and characterize it. Do not stack all
three before balance evidence exists.

## 10. Data and ownership changes

### 10.1 Layout metadata

Prefer extending existing typed room and connection definitions over ad-hoc
dictionaries. Candidate additions:

- room route role;
- encounter tier;
- reward tier;
- vault identity;
- known-risk/minimap marker classification; and
- optional/mandatory classification where not already explicit.

Stable defaults must reproduce current behavior for authored layouts and old
generated snapshots.

### 10.2 Generator ownership

- `puzzle_route_generator.gd`: topology, fork/rejoin candidates, compact bounds.
- `puzzle_route_plan.gd`: route roles, length comparison, landmarks.
- `puzzle_progression_planner.gd`: primary flames, Orb utility, vault
  requirements, state opportunities.
- `puzzle_route_solver.gd`: reachability, producible Orb elements, no-stranding,
  and return paths.
- `dungeon_layout_generator.gd`: active R6+ integration and compatibility
  translation while the native generator boundary is consolidated.

### 10.3 Runtime ownership

- `room_controller.gd`: encounter profile application, chest lock/claim state,
  enemy placement, and room completion.
- existing item/reward owner: rarity and item generation using typed reward
  inputs.
- `dungeon_minimap_controller.gd`: route/vault indicators derived from graph
  metadata.
- `run_state.gd` and active-run services: solved doors, claimed vaults, and
  room runtime persistence.

Do not make `screen_state_controller.gd` or `gameplay_state.gd` the owner of
route difficulty or reward policy.

## 11. Generation pipeline

The approved ordering is:

1. Generate compact topology.
2. Select Start and Boss.
3. Prove an ungated critical backbone.
4. Embed one safe/risk fork-and-rejoin interval.
5. Assign pacing landmarks and ordinary room types.
6. Place Fire, Water, and Electric flame rooms.
7. Attach Orb utility opportunities.
8. Attach one or two optional elite reward branches.
9. Ask the solver for producible Orb elements.
10. Assign elemental vault door requirements.
11. Assign encounter and reward tiers.
12. Add safe cross-links without bypassing vault gates.
13. Validate geometry, progression, rewards, and persistence metadata.
14. Score candidates and select deterministically.
15. Use a known-good deterministic fallback if no candidate passes.

Repairs may change optional gate color or remove an invalid optional gate. A
repair may not insert an elemental gate onto the critical path, move a primary
flame behind a gate, or silently downgrade an advertised vault reward.

## 12. Validation contract

Every accepted generated layout must pass all of the following.

### 12.1 Structural validation

- all room coordinates and minimap coordinates fit the compact bounds;
- no duplicate room coordinates;
- no reused source exits or destination entrances;
- no crossed/overlapping connections unsupported by the renderer;
- every room is connected to Start;
- Boss is reachable on an ungated route;
- at least one fork/rejoin safe-risk choice exists;
- the risk route is shorter than the safe route by the configured minimum;
- graph degree and room count remain within supported limits;
- every dead end has a declared payoff.

### 12.2 Flame and element validation

- Fire, Water, and Electric map-owned flame rooms all exist;
- Hub does not satisfy the count;
- each primary flame is ungated-reachable;
- each flame has a valid return path;
- every vault Orb color is supported and solver-producible;
- no vault contains its own prerequisite;
- no bonus gate is required for Boss or primary-flame reachability;
- solved gates do not create a return softlock.

### 12.3 Encounter and reward validation

- route role maps to a valid encounter tier;
- elite vault rooms map to elite encounter and vault reward tiers;
- safe rooms do not accidentally receive elite profiles;
- every vault has exactly one persistent claim identity;
- reward seeds are deterministic;
- generated enemy count fits available actor slots;
- every enemy's complete collision body can be placed inside walkable room
  geometry and away from closed sockets, chest geometry, and the player spawn;
- a failed spawn slot cannot remain alive or block room completion.

### 12.4 Persistence validation

- rebuilding from the same seed and run context reproduces topology and roles;
- active-run snapshots preserve current room, discovered rooms, solved Orb
  doors, flame visits, enemy state, and claimed vault rewards;
- restoring inside a risk or vault room cannot duplicate enemies or rewards;
- older supported snapshots receive safe defaults for new metadata;
- display resizing/rebasing preserves saved world-space enemy positions.

## 13. Minimap and presentation

The player needs enough information to make a route choice without revealing
the entire dungeon.

Initial presentation requirements:

- discovered primary flame rooms retain their exact elemental identity;
- a discovered dangerous shortcut has a consistent danger marker;
- a discovered elemental vault door shows its required Orb color;
- a known vault reward room has a distinct marker from ordinary Treasure;
- undiscovered rooms remain hidden under the existing discovery contract;
- route markers respect draw order and do not cover the player/destination
  cursor;
- responsive and touch layouts preserve marker alignment.

This plan does not require new environmental art. Reuse the established map
palette and marker language first; commission new icons only where existing
shapes cannot communicate the distinction.

## 14. Ordered implementation plan

Each phase should be independently testable and should not mix unrelated
combat balance changes.

### Phase 0 — Characterize the current generator

- Capture representative R6, R7, R10, and later seeds.
- Record room counts, graph bounds, critical-path length, gate counts, flame
  identities, Orb requirements, route repeats, and repair warnings.
- Confirm the current generated-layout owner selected at runtime.
- Add failing characterization for mandatory gate frequency and missing primary
  flame guarantees.
- Retain the current generated layout as a fallback fixture.

Exit: current behavior and failure modes are measurable.

### Phase 1 — Typed route roles and ungated backbone

- Add safe, risk-shortcut, elite-reward, primary-flame, Orb-utility, and
  elemental-vault roles at the narrow typed boundary.
- Generate Boss reachability before assigning any elemental gates.
- Add one fork/rejoin interval and validate path-length difference.
- Preserve old role defaults for authored layouts and snapshots.

Exit: every accepted seed has an ungated Boss path and one real route choice.

### Phase 2 — Three-primary-flame guarantee

- Place Fire, Water, and Electric flame rooms on ungated reachable nodes.
- Add distribution scoring and adjacency constraints.
- Update solver state and diagnostics to identify each flame source.
- Verify start, bound-flame, and save/recovery combinations.

Exit: every tested generated seed exposes all three primary flames without
optional gate completion.

### Phase 3 — Optional elemental vault topology

- Attach one or two bonus branches after critical topology is stable.
- Query solver-producible Orb elements and assign gate colors.
- Prevent critical, flame, and prerequisite content from entering vaults.
- Persist solved door identity and validate return paths.

Exit: vaults can be ignored, revisited, opened, and exited without affecting
Boss reachability.

### Phase 4 — Route encounter profiles

- Add explicit normal, dangerous, and elite encounter metadata.
- Apply profiles in `room_controller.gd` using current enemy-generation seams.
- Keep counts within actor and room-placement capacity.
- Validate every active slime before combat and room-clear accounting.
- Tune representative seeds without changing authored-run balance.

Exit: shorter routes are observably harder and elite vault rooms are the
strongest non-boss encounters without producing unreachable enemies.

### Phase 5 — Reward tiers

- Add standard, risk, and vault reward metadata.
- Route vault chests through existing deterministic item generation.
- Guarantee the initial enhanced gear contract.
- Persist claim state and prevent duplicate rewards.
- Select and tune one modest risk-shortcut material bonus.

Exit: rewards reliably match advertised route risk and survive revisit/save.

### Phase 6 — Minimap communication

- Add or reuse markers for danger, primary flames, vault requirements, and
  enhanced treasure.
- Preserve discovery and draw-order contracts.
- Verify native 240×160, wider desktop modes, and touch presentation.

Exit: players can understand a discovered route choice before committing.

### Phase 7 — Verification and rollout

- Run deterministic seed batches across supported run ranks and start states.
- Run focused generator, route, reward, recovery, enemy-placement, and minimap
  tests.
- Perform manual safe-route, risk-route, ignored-vault, opened-vault, revisit,
  save/load, and boss-completion journeys.
- Run the supervised full smoke suite only with no MCP Godot runtime active.
- Update `AUDIT.md`, `KNOWN_ISSUES.md`, `GAMEPLAY_TUNING.md`, and this plan with
  measured results.
- Remove mandatory generated fusion gates only after active-save compatibility
  and fallback behavior are verified.

Exit: R6+ consistently produces legible, completable risk/reward maps with no
mandatory elemental-door loop.

## 15. Test matrix

### Automated generator tests

- same seed/context produces identical rooms, roles, gates, and rewards;
- Fire, Water, and Electric are present and ungated-reachable;
- Boss remains reachable with zero optional doors solved;
- safe/risk routes fork, differ in length, and rejoin;
- risk route meets the configured minimum saved-distance contract;
- every dead end has utility or reward;
- vault count and colors satisfy policy;
- every vault color is solver-producible;
- no vault gate can be bypassed by a cross-link;
- compact bounds and socket uniqueness remain valid;
- R6, R7, R10, and high-rank seed batches terminate within a time budget.

### Automated runtime tests

- route role reaches encounter and reward owners;
- elite room locks chest until clear;
- vault reward is enhanced and deterministic;
- claimed vault cannot be claimed again;
- solved Orb door survives room revisit and active-run restore;
- invalid saved enemy position is recovered or made non-blocking;
- all live enemy collision bodies remain inside usable room geometry;
- clearing either safe or risk route permits the shared rejoin;
- ignoring all vaults still permits boss completion.

### Manual acceptance journeys

- take only the safe route;
- take only the dangerous shortcut;
- enter a risk route, retreat before commitment, then choose safe;
- discover a vault, leave, obtain the required Orb state, and return;
- ignore all vaults and complete the run;
- open every generated vault and verify reward quality;
- save and reload before a vault, inside its encounter, and after claiming it;
- resize between supported aspect modes and verify map/enemy alignment;
- complete a later generated run with touch controls.

## 16. Initial tuning targets

These are starting hypotheses, not final balance commitments:

- one safe/risk fork-and-rejoin choice per generated map;
- one or two elemental vaults;
- three guaranteed primary flame rooms;
- risk path saves at least two room transitions;
- dangerous encounters stay within normal actor-slot limits;
- one enhanced gear item per vault chest;
- no more than three ordinary Combat Rooms consecutively;
- no more than one required element-state change for traversal—and the target
  implementation has zero elemental requirements on the Boss path.

Record final values in `GAMEPLAY_TUNING.md` only after representative runtime
measurement.

## 17. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Generated routes exceed compact bounds | Validate every candidate before progression assignment; retain deterministic fallback |
| Primary flames cluster or become repetitive | Score graph distance and early/mid/late distribution |
| Optional gate is impossible | Choose only from solver-producible Orb states |
| Cross-link bypasses a vault door | Add no-gate-bypass validation after all links are added |
| Risk route is not actually shorter | Compare fork-to-rejoin graph distances as a hard contract |
| Elite difficulty becomes health inflation | Start with composition profiles and bounded level offsets |
| Elite enemies cannot fit the room | Validate full bodies, cap composition, and degrade failed slots safely |
| Better rewards destabilize gear economy | Begin with one enhanced item and existing rarity ceilings |
| Vault rewards duplicate after restore | Stable vault identity plus persisted claim state |
| New metadata breaks old runs | Safe typed defaults and explicit snapshot migration coverage |
| Minimap reveals too much | Show role only after discovery; preserve hidden-room rules |
| Generator becomes slow | Bound attempts, measure seed batches, and keep a known-good fallback |

## 18. Explicit non-goals

- Real environmental biomes.
- Burnable vegetation, elemental terrain, or new room hazards.
- Claiming current Puzzle Rooms provide meaningful puzzle variety.
- New enemy families or boss mechanics.
- A global combat rebalance.
- Mandatory multi-step fusion progression.
- Replacing the item catalogue or save architecture.
- Rewriting the complete generator in one patch.
- Changing authored Runs 1–5.

## 19. Completion criteria

This plan is complete when:

- generated R6+ maps always provide Fire, Water, and Electric flames outside
  the Hub;
- all three flames and the Boss are reachable without optional Orb doors;
- maps contain a validated safe-versus-short-dangerous route choice;
- randomized, solver-producible elemental Orb doors protect optional enhanced
  Treasure Rooms;
- elite routes are harder using explicit encounter profiles;
- vault rewards are deterministic, persistent, and materially better than
  ordinary treasure;
- generated enemies cannot remain alive outside usable room bounds;
- maps communicate known risk and reward clearly;
- active-run recovery preserves all new state;
- focused tests, representative manual journeys, and the supervised release
  gate pass; and
- the old mandatory generated elemental-door loop is retired or retained only
  as documented save compatibility behavior.
