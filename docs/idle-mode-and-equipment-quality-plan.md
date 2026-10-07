# Idle Mode and Equipment Quality Plan

Status: proposed feature plan; source review corrections incorporated,
lifecycle decisions settled 2026-10-07; implementation not started

Updated: 2026-10-07

Decisions: the six open design questions are resolved below and folded into
the behavior contract. The settled answers are start-from-Hub-only,
looping as a separate opt-in, puzzle-avoiding routing, equal six-lane stat
weighting, best equip in Pause Equipment, and mandatory manual starter
attunement.

Scope: optional input-driven autoplay for ordinary generated runs, human
override and pause access, plus numerical gear sorting and an explicit
best-stat-pool equip action

Authority: this document proposes a bounded feature direction. Existing runtime
behavior remains authoritative until implementation and acceptance land.

## Product intent

Idle Mode lets a player opt into a modest autonomous run while keeping the
normal game in control of movement, targeting, combat, interactions, rewards,
and transitions. It should route through supported generated content, fight
with the normal attack/guard/roll/magic actions, collect nearby rewards, beat the
boss, settle the run, and optionally begin another run. It is not intended to
solve puzzles, select gear, allocate stats, buy/fuse items, or make build choices.

The feature must remain optional (default off), work with keyboard, controller,
and touch, and let a person take over at any time. A separate Equipment action
can equip the numerically highest stat-pool loadout; equipment candidates should
also be ordered highest score first so the existing comparison UI stays useful.

## Current source facts

- `InputRouter` is the single polling and merge boundary for keyboard, mouse,
  controller, and touch. `gameplay.gd._physics_process()` polls it before
  `GameplayFrameController.tick()` consumes input and calls
  `update_player_input()` before simulation. `PlayerController` exposes the
  established action methods used by that input path. Automation should supply
  ordinary action state at this boundary; it must not move the player node,
  call attack components directly, or create a second update loop.
- The router has gameplay/menu contexts and already receives touch snapshots
  from `TouchControlsLayer`. Touch controls are context-gated while a menu is
  active. A new source must preserve these rules and distinguish physical human
  input from generated automation input.
- Pause and Settings are distinct routes. Settings are stored device-wide by
  `SettingsService` in `user://settings.cfg`; add an `idle_mode` boolean there,
  defaulting to false, and expose it through the existing settings route. A
  person must always be able to open Pause and turn the setting off.
- `DungeonGraph`, `DungeonMapController`, and `RoomController` own topology,
  route state, and room transitions. The run starts at the hub/Gray room and
  requires normal starter-flame attunement. Generated rooms include combat,
  treasure, fire, Orb, puzzle, and boss/downstairs roles. Boss completion and
  settlement already have standard owners; Idle Mode must invoke their normal
  paths rather than manufacture rewards or mark rooms complete.
- Starter attunement uses the ordinary flame service: it spends five Souls,
  changes the active element, and opens the start-room gate. This needs an
  explicit automation exception or manual handoff; a generic Interact request
  does not make the cost or build effect disappear.
- Route eligibility must use room/connection topology and live gate state.
  `_mark_orb_utility_rooms()` changes Orb role/tier metadata without moving its
  connections. An Orb utility label does not prove a room is off the boss route,
  and a global Orb count does not prove a reachable gate-compatible path.
- Hub run start currently goes through `HubEconomyController.start_from_hub()`
  and a scene transition. Reuse that operation through a typed boundary and
  rebind automation after reload; an in-process Hub/run rewrite is not a
  prerequisite for this feature.
- `WalkableArea` answers walkability and nearest-walkable queries, but the source
  audit found no player pathfinding service. This is a real implementation item:
  add a small room-local planner that emits movement vectors and re-plans after
  doors, collision, knockback, target changes, or stuck detection. It must use
  the same perspective movement and walkability rules as the player.
- Targeting, guard, roll/backflip, attack combo, and magic already have normal
  action paths. Attack input buffers the second hit during the first attack;
  roll while target-locked can backflip when facing away. The automation can
  request these actions, but acceptance must prove normal eligibility,
  cooldowns, MP, and animation locks still apply.
- `ItemCatalog.bonuses()` calculates effective flat bonuses including rarity,
  enhancement, fusion, random points, and authored tradeoffs.
  `stat_allocation_total()` sums the six canonical primary lanes
  (VIT/STR/DEF/AGI/INT/MND) and explicitly avoids counting the AGI/speed alias
  twice. This is a good initial definition for “stat pool.”
- `HubEquipmentMenuPresenter` currently renders candidates in the order supplied
  by its menu context and previews their effective combat snapshot. The profile
  owns inventory/equipped IDs, and `EquipmentComponent` builds the combat
  snapshot. The best-loadout action should score legal complete assignments
  using the same catalog/stat path. Existing per-item equipment operations need
  a batch proposal/commit boundary to validate once, refresh once, and save once.
- **The Hub Equipment page is unreachable in play.**
  `HubMenuState.HUB_COMMAND_PAGE_TARGETS`
  (`scripts/ui/hub_menu_state.gd:15`) is
  `[HUB_PAGE_STATS, HUB_PAGE_SHOP, HUB_PAGE_FUSION, HUB_PAGE_BIND]` and omits
  `HUB_PAGE_EQUIPMENT` (=1). Every hub page change goes through that list —
  `HubInputController` (`scripts/ui/hub_input_controller.gd:98`),
  `HubEconomyController` (`scripts/runtime/controllers/hub_economy_controller.gd:1098`),
  and `HubFlowController`
  (`scripts/runtime/controllers/hub_flow_controller.gd:185`) all index it. The
  `EquipmentMenu` instanced at
  `scenes/menus/hub/demon_hub_menu.tscn:673` therefore has no navigation path.
  Pause's `PauseEquipmentPage`
  (`scenes/menus/pause/pause_menu.tscn:235`, page 2, resolved by
  `PauseScreenPresenter.update_page_visibility`) is the only reachable
  equipment route. Hub-side equipment presenters still run and still need to
  keep working, but they are not a player-facing surface today.

## Proposed behavior contract

### Mode lifecycle and human override

1. `idle_mode` is a persisted opt-in setting and is off by default.
2. Settled 2026-10-07: an explicit one-time human action is the only way to
   begin. The Hub command list gains a "Start autoplay" action; pressing it
   starts the run through the existing Hub run-start operation and enables the
   bot for that run. The bot never starts a run on its own, never infers
   consent from idle time, and never synthesizes menu confirms.
3. Settled 2026-10-07: looping is a **second, separate** setting
   (`idle_mode_loop`, default off), independent of `idle_mode`. With it off,
   settlement stops the bot in the Hub and waits for human input. With it on,
   the bot waits the short restart delay and starts another run through the
   same Hub operation. `idle_mode` alone therefore never produces a second
   unattended run.
4. With a loaded profile the bot is eligible during the active run and, only
   when `idle_mode_loop` is on, the supported between-run Hub flow. It is inert
   on title/save-select, during dialogue choices, settings, pause, loading,
   death, and transitions. It must not operate menus.
5. Every deliberate human gameplay input (keyboard, mouse, controller, or
   touch) suspends bot input for five seconds after the most recent human input.
   Bot-generated input never refreshes that timer. During suspension, the human
   receives the normal input stream. Show a clear “AUTO / MANUAL” state and
   resume indication so control ownership is legible.
6. Physical pause/back/menu actions always outrank automation. The bot never
   emits pause, settings, equipment, or menu navigation actions. Opening Pause
   suspends the bot for the whole menu route; turning Idle Mode off persists
   immediately. Returning to gameplay resumes after the override window rather
   than mid-menu.
7. Settled 2026-10-07: starter attunement is **always manual**. The five-Soul
   paid exception is withdrawn. The bot waits at the start-room gate, shows a
   visible "attune the starter flame to continue" handoff, and issues no
   gameplay actions until the gate is open. It never spends currency. This
   makes every automated run begin with a deliberate human action, and it means
   the `idle_mode_loop` restart path always requires one manual attunement per
   run unless the gate is already open from the previous run — that repeat-run
   cost is accepted and must be stated in the loop setting's description.
8. The system does not equip, buy, fuse, sell, allocate stats, choose a flame,
   or dismiss player-facing reward/overwrite decisions. Any required
   build/dialogue decision produces a visible manual handoff; do not automate
   NPC choices, fusion, or later flame changes.

### Input schedule and takeover

- Preserve the current poll-before-tick order. Schedule `IdleModeController`
  once in the frame controller to publish a typed intent for the next poll.
  Initial, expired, wrong-context, and transition-invalidated intents are neutral.
- At poll time, read physical/touch input first and evaluate human activity
  before merging the pending bot intent. A human action suppresses all bot
  actions in that same frame, including held movement, guard, and attack.
  Pause/back remains physical input and wins before gameplay action dispatch.
- Define deliberate input using existing deadzones and gesture/action rules;
  stick drift and passive pointer movement must not indefinitely suppress the
  bot. Held deliberate input continues the override until released.
- Clear bot intents across menus, loading, death, room changes, and scene
  reloads. Re-observe the new room before publishing another intent; never
  replay a held action against the next room's interaction target.

### Run and room policy

- Start only from the explicit Hub "Start autoplay" action, through the normal
  Hub run-start operation (never synthetic UI confirmation). After any scene
  reload, initialize from the loaded profile, both persisted opt-in settings,
  and the current route. In the first room, wait at the start-room gate for
  manual attunement and show the handoff until the gate is open. Never repeat a
  charge after the gate has opened.
- Use topology to choose a deterministic, puzzle-free route toward the boss.
  Prefer mandatory combat and treasure rooms that the run requires; collect a
  chest when unlocked and nearby, plus nearby drops/pickups while traversing.
  Do not enter optional puzzle/NPC/content branches solely for completion.
- Never interpret a puzzle as a combat or navigation problem. Do not interact
  with puzzle objects, spend special resources to bypass a puzzle, use minimap
  fast travel to evade its rules, or invoke puzzle solution APIs.
- Settled 2026-10-07: routing **takes the puzzle-free branch**. A puzzle or NPC
  room on the current path is an obstacle to route around, not an automatic
  stop, provided a puzzle-free branch to the boss exists in the reachable
  subgraph and its gates are satisfiable by ordinary traversal. Dialogue/NPC
  rooms that require a choice remain hard handoffs, because no branch selection
  removes the need to choose. If no puzzle-free branch exists, stop safely and
  explain why. This raises the bar on route search: the planner must search the
  reachable subgraph for a viable branch rather than assume the next
  connection is the correct one, and acceptance must include a seed where a
  branch is required and taken.
- Evaluate authored early runs separately from later generated runs. Plan on
  actual connections and supported gate requirements rather than assuming
  room depth, role labels, or Orb counts guarantee a completable route. Cover a
  supported complete route and a mandatory unsupported interaction that stops
  safely; one successful seed is not proof that every run can autoplay.
- Clear active enemies using standard input actions, then use the normal
  doorway/interact transition. Handle combat, treasure, Orb, fire, and boss
  rooms only where the required action is supported without puzzle solving.
  Stop instead of guessing when the room requires a puzzle, dialogue choice, or
  other unsupported authored interaction.
- On boss defeat, allow the ordinary clear/settlement flow to finish. If
  `idle_mode_loop` is off, stop in the Hub and wait for human input. If it is
  on, wait a short safe restart delay (initial proposal: three seconds); any
  human input cancels/restarts that delay. Never reset the profile, skip
  settlement, or silently make equipment choices.

### Combat policy

- Choose the nearest valid hostile using the existing target/interaction data;
  face it and maintain a safe approach distance using local movement planning.
- Use Attack 1, then request Attack 2 inside the normal combo buffer window.
  Keep pressure simple; no charge/spin/advanced combo requirement for the first
  delivery.
- Use Magic only when a valid target exists, MP/cooldown permits it, and the
  cast does not conflict with a more urgent survival action.
- Read available enemy attack/windup and boss airborne/slam state. Guard during
  a readable incoming hit window; dodge or backflip away from imminent area
  attacks and crowded threats. Avoid holding guard/roll indefinitely.
- Respect death, knockback, attack/cast locks, invulnerability, element and MP
  rules. If it becomes stuck, repeatedly hit, or cannot make progress, stop
  issuing movement and expose a recoverable manual state instead of looping
  unsafe inputs.

## Equipment quality contract

### Candidate ordering

- Sort each slot's eligible candidates by descending `ItemCatalog.stat_allocation_total()`.
- Use deterministic tie breaks: total positive primary bonuses, then rarity,
  enhancement/fusion rank, then stable item instance ID. Keep negative primary
  tradeoffs in the primary total; do not hide them by summing only positives.
- Keep equipped items and explicit unequip options in their existing semantic
  positions or mark them clearly; sorting must not break selected-item identity,
  touch targets, candidate scrolling, preview comparison, or Pause's editable
  equipment route. Re-resolve selection by stable instance ID after resorting.

### Best-stat-pool action

- Settled 2026-10-07: add the "BEST STATS"/"AUTO EQUIP" action in **Pause
  Equipment only**. The Hub Equipment page is unreachable in play —
  `HubMenuState.HUB_COMMAND_PAGE_TARGETS` (`scripts/ui/hub_menu_state.gd:15`)
  omits `HUB_PAGE_EQUIPMENT`, and every hub page change indexes that list, so
  the `EquipmentMenu` instanced at
  `scenes/menus/hub/demon_hub_menu.tscn:673` cannot be navigated to. Pause's
  `PauseEquipmentPage` (`scenes/menus/pause/pause_menu.tscn:235`, page 2) is
  the only equipment route a player can reach. Do not build Hub presentation
  for this action; if the Hub page is ever made reachable, add the action there
  as a separately reviewed change rather than duplicating it speculatively.
- Settled 2026-10-07: the score sums all six primary lanes equally. No player
  weighting in the initial slice. Keep the stated limitation in the Pause UI:
  "Best" is the highest sum of the six primary flat stats, not a role-aware or
  preferred build; percentage/guard effects and elemental synergy are excluded.
- Choose the legal complete assignment with the highest summed stat-pool score.
  Independently ranked slot candidates are inputs, not the final answer: compare
  the best Demon Cloak assignment against the best compatible body-plus-head
  assignment because the cloak clears and locks the head slot. Respect other
  slot compatibility, shield behavior, and profile integrity; never use one
  instance twice. Include an empty-slot candidate with score zero wherever
  unequipping is legal, so negative-score gear is not compulsory.
- Make assignment ties deterministic using the candidate tie rules and a stable
  canonical slot order, preserving the current loadout when it already has the
  maximum score. Preview against the same inventory revision/equipped state
  that commit validates; if either changes, refresh the proposal before confirm.
- Present the proposal and resulting six primary stats before one confirmation;
  apply the complete assignment atomically through the profile/equipment owner.
  Reject invalid/stale proposals without partial slot changes. Reapply the
  resulting combat snapshot and request persistence once on success. Provide a
  clear no-change result when already optimal.
- State the limitation in the UI: “Best” means highest sum of the six primary
  flat stats, not a role-aware or personally preferred build. Percentage/guard
  effects and elemental synergy are not part of the initial score. A later
  scorer can replace this only as a separately reviewed design decision.

## Ownership and planned changes

| Concern | Existing owner / intended boundary |
|---|---|
| Bot state machine and observations | New `IdleModeController` under the runtime controllers; scheduled from `GameplayFrameController`, publishes intent for the next router poll |
| Input composition and human activity | `InputRouter` (or a typed automation snapshot source consumed there); human input must be identifiable separately from synthetic input |
| Route graph and transition calls | `DungeonMapController`, `DungeonGraph`, `RoomController`, `RunFlowController`, and existing Hub start operation through typed queries/results |
| Room-local movement planner | New focused algorithm/controller using `WalkableArea`, actor geometry, and normal perspective movement; no direct teleporting |
| Hub "Start autoplay" command action | `HubMenuState.HUB_COMMAND_PAGE_TARGETS` and `HubCommandShellPresenter`; the action starts the run through `HubEconomyController.start_from_hub()` |
| Settings persistence and UI row | `SettingsService`, `SettingsScreenPresenter`, `ScreenRouteController`; both `idle_mode` and `idle_mode_loop` rows; update the settings scene/presenter test as required |
| Candidate score/order and best assignment | `ItemCatalog`, profile/equipment owner, and the **Pause** equipment route (`PauseScreenPresenter`, `PauseMenuState`, `ScreenRouteController`) over the shared `EquipmentMenuLayout`. Hub-side equipment presenters must not gain the best-equip action while the Hub page stays unreachable. |
| Documentation/verification | This plan, feature owner docs, focused contract smokes, manifest entries, and current audit/known-issue evidence after implementation |

Keep `GameplayState` as a wiring/state facade, not the home for bot strategy or
gear scoring. If the feature crosses these owners, use a typed observation and
intent/result boundary instead of adding more root dictionary reach-through.

## Delivery slices and exit evidence

Suggested cross-plan order: first the central stat policy and atomic Apply in
`anchored-stat-allocation-proposals.md`, then the independent equipment-quality
slice below, then Idle Mode. Gear scoring is independent of the stat cap; this
order keeps the first changes bounded. The start/repeat and attunement decisions are
settled (see the decision table), so the lifecycle can be implemented.

**Equipment quality:** sort candidates, preserve identity and scroll/touch state,
then add complete-loadout scoring, preview, and atomic confirmation in **Pause
Equipment**. Acceptance must cover a cloak that scores higher than either
individual alternative but lower than their combined body/head score,
negative-score candidates versus legal empty slots, tie stability, stale
proposals, rejection without mutation, one runtime refresh/save request, and
input parity across keyboard, controller, and touch on the Pause route.

Idle Mode follows these slices:

1. **Input seam and settings:** add the two default-off settings
   (`idle_mode`, `idle_mode_loop`), their settings options and descriptions,
   the Hub "Start autoplay" command, typed automation snapshot composition,
   manual activity detection, five-second override, and pause precedence. Prove
   all three human device classes override, bot input cannot trigger pause/menu,
   and menu contexts never receive bot gameplay actions. Prove same-frame
   takeover, suppression of held bot actions, drift filtering, and neutral
   intents across context/room changes and scene reload. Prove `idle_mode`
   without `idle_mode_loop` stops in the Hub after settlement.
2. **Room navigation:** create a local path planner over walkable space, door
   targets, objective/obstacle observation, timeout/stuck handling, and typed
   room transition selection. Prove door-to-door navigation with obstacles and
   room transition/replan behavior at supported aspect ratios.
3. **Combat and loot:** add simple target/approach/attack-combo/magic/guard/roll
   policy and supported pickup/chest collection. Prove normal action gates,
   enemy death/room clear, status/MP behavior, boss telegraph response, and
   loot collection without direct health/reward mutation.
4. **Run lifecycle:** implement the start-room gate handoff, puzzle-free route
   policy including branch selection, boss completion, normal settlement, the
   loop-gated hub delay, and the repeat-run loop. Prove a deterministic
   generated seed completes end-to-end, no puzzle action is ever emitted, a seed
   requiring a puzzle-free branch takes it, unsupported mandatory content stops
   safely, and manual input cancels the restart delay. Cover authored early-run
   handoff, reachable Orb/gate state, the bot waiting for manual attunement
   without spending Souls, no repeated attunement charge, both settings'
   persisted state after a scene transition, and that the loop stops in the Hub
   when `idle_mode_loop` is off.
5. **Acceptance and documentation:** focused smokes for input override,
   navigation, route policy, combat, run loop, settings persistence, candidate
   ordering, and best equip; browser/touch manual acceptance; update test
   manifest state truthfully. Use MCP-first editor verification when connected.
   Only run the curated release gate as the supervised standalone step
   described in `AGENTS.md`.

## Settled design decisions (2026-10-07)

All six previously open questions are resolved. Each answer is folded into the
behavior contract above; this table is the index.

| # | Question | Decision | Consequence for scope |
|---|---|---|---|
| 1 | Automatic idle-triggered start, or explicit action? | **Explicit "Start autoplay" Hub action.** | New Hub command action; bot never infers consent. Simplest lifecycle. |
| 2 | Auto-restart after settlement, or wait? | **Separate `idle_mode_loop` opt-in, default off.** | Second persisted setting. `idle_mode` alone can never produce two unattended runs. |
| 3 | Stop at puzzles, or route around them? | **Route around puzzle rooms; dialogue/NPC choice rooms stay hard handoffs.** | Route planner must search the reachable subgraph for a viable branch; needs a seed where a branch is required. |
| 4 | Equal stat weighting, or player-selected? | **Equal six-lane sum.** | No weighting UI. The limitation is stated in the Pause Equipment UI. |
| 5 | Pause or Hub for best equip? | **Pause Equipment only.** | Hub Equipment page is unreachable (`HUB_COMMAND_PAGE_TARGETS` omits it). No Hub presentation built. |
| 6 | Auto or manual starter attunement? | **Always manual.** | Five-Soul exception withdrawn; bot spends no currency. Each looped run needs a manual attunement unless the gate is already open. |

Items still open, and deliberately not decided here: the five-second override
duration and the restart delay length both need phone/controller playtesting;
generator constraints for an always-solvable puzzle-free branch are an
acceptance question that depends on observed dead ends; and whether the Hub
Equipment page should become reachable at all is a separate feature question.

## Risks and non-goals

- This is a significant gameplay feature, not a small settings toggle. A
  competent first pass needs player navigation, combat telegraphs, room
  outcomes, and a human takeover contract.
- Five seconds is a starting override duration and needs phone/controller
  playtesting; the player must also have an immediate explicit “Pause Auto” way
  to prevent surprise resumption.
- Every looped run now needs a manual starter attunement, because the bot never
  spends Souls. The loop setting's UI copy must say so, or a player who enables
  looping will discover the stop-and-handoff mid-loop.
- Routing around puzzle rooms raises the route-search cost and the failure
  surface. A branch search that cannot find a viable path must stop safely
  rather than settle for the shortest path through a puzzle room.
- Some generated paths or unique room interactions may be incompatible with
  puzzle-free autoplay. The bot must fail safely; generator constraints should
  only change after evidence identifies a repeatable dead end.
- The flat primary stat pool is explainable but ignores stat-specific value,
  guard bonuses, and player preference. It must be described as a convenience,
  not objectively best gear. Equal six-lane weighting is a settled decision, so
  the limitation is a documented product statement rather than a pending
  design question.
- Best equip lives only in Pause Equipment because the Hub Equipment page is
  unreachable. If the Hub page becomes reachable later, that is a separate
  reviewed change; do not treat Hub parity as a requirement of this feature.
- Web and mobile performance, touch gestures, browser tab suspension, save
  timing, and long unattended runs require real browser/device acceptance.
- Not in scope: puzzle solving, new combat mechanics, direct actor movement,
  automatic item purchase/fusion, stat allocation, build optimization, or
  changing the generated dungeon's product contract merely to make autoplay
  appear successful.
