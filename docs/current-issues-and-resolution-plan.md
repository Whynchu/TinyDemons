# Current Issues and Resolution Plan

Created: 2026-09-09

## Approved direction and evidence rules

Latest user decisions supersede older proposals below:

- Keep authored R1–R5; use generated maps from R6 onward for now.
- Show unvisited flame landmarks greyed out on the expanded minimap; allow
  travel only to visited flame rooms, starting from a flame room.
- Bound players at zero Chroma retain their bound elemental identity and
  appearance shape, with desaturation only. They must not become Normal.
- Normal/Gray players can collect and store Chroma while remaining Normal.
- Chroma pickups visually match the element the player currently needs,
  including a neutral appearance for Normal players.

The first implementation pass was applied on 2026-09-09. This document now
records the original report, the source changes, and the verification still
needed. “Implemented in source” means the behavior has focused coverage and
passed Godot script diagnostics; it does not claim that runtime timing or every
display orientation has been measured. No runtime performance measurements have
been recorded yet.

This is the active tracker for the menu, gear, progression identity, and
backtracking issues reported during playtesting. It is a working document: code
changes should update the status and verification notes here as each issue is
resolved.

## Issue 1 — Demon Hub select/back presentation differs by menu

**Observed:** The Demon Hub has four select/back button formats. SHOP and FUSION
match the intended authored format. The other two hub destinations use the
wrong positioning/orientation when the menu is entered or rotated.

**Likely owners:** `screen_state_controller.gd`, the Demon Hub scene, and the
hub menu layout/navigation contract. Use `demon-hub-menu-navigation-plan.md`
and `hub-menu-visual-display-contract.md` as existing references.

**Investigation:** Compare the four button instances, their anchors, offsets,
rotation/orientation handling, and the code path that applies the active page
layout. Identify whether the mismatch is scene data, duplicated constants, or
a transform being applied twice.

**Acceptance criteria:** All four hub destinations use the same intended
select/back format. Their positions remain correct after entering, leaving,
and changing orientation. SHOP and FUSION retain their current appearance.
Add a scene/layout characterization check where practical and perform a visual
playtest at the supported display orientations.

Status: **Implemented in source — visual orientation verification pending**

### Current code state (2026-09-09)

- The shared authored footer contract says SELECT/BACK should be common across
  hub routes, but the hub currently mixes scene-authored menus with legacy
  presenter paths. Equipment, Shop, Fusion, and Bind have dedicated layouts;
  BindMenuLayout dynamically creates its internal controls. Its scene is wired
  and rendered by ScreenStateController. The older claim that Bind still needs
  migration to a dedicated layout is obsolete.
- `BindMenuLayout` now uses the same responsive left-field geometry and footer
  lane as the canonical Hub SELECT/BACK layout. Its previous lower-left BACK
  target was the outlier.
- The Equipment presenter hides its dedicated navigation footer when mounted in
  the Hub, so the Hub's shared footer remains the only visible SELECT/BACK
  format. Pause retains the dedicated equipment footer.
- Source characterization covers the Hub and equipment paths. A visual pass at
  each supported orientation is still pending; the live check so far confirmed
  the Hub root's shared footer.

## Issue 2 — Shop selling merges gear across levels

**Observed:** In the SHOP sell flow, gear with the same name appears to be
grouped together regardless of its `+` level or other instance identity. This
can show an incorrect inventory quantity and can make it unclear which gear is
being sold.

**Likely owners:** shop/sell presentation in `screen_state_controller.gd`,
the equipment/inventory data model, and the gear identity rules documented in
`gear-system-rework.md` and `demon-hub-menu-navigation-plan.md`.

**Investigation:** Trace the sell-list key, quantity calculation, selected-row
identity, and removal/refund path. Confirm the intended grouping key. At a
minimum, different enhancement levels must produce independent rows; if gear
has additional independent identity fields, those fields must also remain
available to the sell operation.

**Acceptance criteria:** A sell row represents one exact sellable gear variant
and displays its correct quantity. Selecting and selling one variant cannot
remove another variant with the same base name. Quantities update immediately
after a sale, selection remains stable when possible, and the flow does not
become slower as inventory size grows. Add focused characterization coverage
for same-name gear at multiple levels and for selling the final item in a row.

Status: **Implemented in source — runtime transaction verification pending**

### Current code state (2026-09-09)

- `ItemInstance.shop_stack_key()` is now the single sell identity. It includes
  definition, rarity, quality, affixes, random stat points, transmutation,
  enhancement, and fusion investment fields.
- `HubFlowController` builds and sorts a cached representative list with exact
  member instance IDs. The cache is reused for row rendering, owned counts, and
  sale selection until inventory or equipped IDs change.
- Sale removal uses the exact cached IDs and reselects the same exact variant
  after the inventory rebuild. `tests/demon_hub_menu_scene_smoke.gd` now covers
  same-name gear with different enhancement/random-roll identity and verifies
  independent quantities.

## Issue 3 — Shop sell flow feels unusually slow and lags between items

**Observed:** The sell screen is extremely slow during normal use, with
noticeable lag when moving between sellable items. The slowdown may be caused
by rebuilding rows, repeated gear lookups, sorting, texture work, or an overly
broad inventory scan.

**Likely owners:** sell-list construction and refresh code, with the data model
as a possible contributor.

**Investigation:** Measure the list-build and post-sale refresh paths with a
representative inventory. Resolve Issue 2 first so performance work preserves
exact gear identity. Avoid optimizing by caching stale quantities or weakening
the sell contract.

**Acceptance criteria:** Opening SELL, moving between rows, confirming a sale,
and returning to the refreshed list feel immediate at the supported inventory
size. Any measured hot path has a documented reason for its change and keeps
the focused sell tests green.

Status: **First performance pass implemented — timing baseline pending**

### Current code state (2026-09-09)

- The nested inventory/group scan and per-comparison catalog construction were
  removed from the sell path. The exact group cache is invalidated by the
  profile's in-memory `inventory_revision`, including equip/sell/fuse/salvage
  mutations.
- Opening and browsing SELL can reuse the grouped result. A sale still performs
  the necessary equipment refresh, profile save, currency refresh, and one cache
  rebuild; those synchronous costs remain profiling targets.
- No device timing baseline exists yet, so the reported lag is not marked
  resolved until shop open, row movement, sale, and post-sale refresh are
  measured in a runtime session.

## Issue 4 — First flame pickup causes an audio/room hitch

**Observed:** The first time a flame is picked up in a room and the room music
starts, gameplay briefly lags. Later playback may be smooth, suggesting that
the first-use path is loading, decoding, instantiating, or switching audio
resources synchronously.

**Likely owners:** flame pickup/room transition code, `sound_manager.gd`, and
the music asset loading path. The room and progression owners should remain
responsible for the event and state transition; audio initialization belongs to
the sound owner.

**Investigation:** Reproduce with a cold launch and record the exact flame,
room, music track, and frame hitch timing. Trace the first pickup through room
state updates and music selection. Compare the first play with a second play,
check whether the audio resource is loaded on demand, and measure whether
visual room updates or save/profile work occur in the same frame. Inspect WAV/
OGG loading and any generated audio fallback behavior before choosing a fix.

**Acceptance criteria:** Picking up a flame and starting its room music does
not produce a noticeable gameplay hitch. The music still starts exactly once,
the correct track is selected, room/progression state remains correct, and
audio remains safe when the resource is unavailable. Add a focused regression
check for one-time music initialization where a deterministic timing assertion
is practical, plus a cold-start manual playtest.

Status: **Warmup/cache implemented — cold-start timing pending**

### Current code state (2026-09-09)

- `SoundManager.preload_music_tracks()` now resolves and loads the title and run
  tracks into an in-memory cache. `_start_music_track()` uses that cache and
  keeps a fallback load path for unavailable resources.
- `GameplayBootstrap` performs the warmup after the loading screen has had a
  frame to draw. `tests/run_music_flame_gate_smoke.gd` checks both streams are
  cached and that run music remains gated until starter flame attunement.
- A cold versus warm flame-room playtest and frame profile are still required
  before claiming the hitch is gone. The warmup moves work into boot, so boot
  duration should be measured as part of that check.

## Issue 5 — Pause equipment touch scrolling escapes its window

**Observed:** Touch scrolling of equipment items works, but rows can be dragged
too far upward and remain outside the equipment panel's intended visible area.
They should be clipped sooner by the equipment window.

**Likely owners:** `equipment_menu.tscn`, `equipment_menu_layout.gd`, and the
pause menu container/clip configuration. The shared equipment menu is also
instanced in the hub, so both contexts need checking.

**Investigation:** Inspect the scroll/content bounds, clip node, drag clamp,
and viewport-to-logical-coordinate conversion. Determine whether the visual
overflow is caused by missing clipping, an oversized content rect, or a drag
offset that is not clamped to the final row boundary.

**Acceptance criteria:** Equipment rows cannot render outside the authored
equipment window during touch drag, release, or repeated fast swipes. The last
row remains reachable, the first row can return fully into view, and desktop
controller/keyboard navigation is unchanged. Verify both pause and hub
instances at the supported aspect presets.

Status: **Implemented in source — runtime touch verification pending**

### Current code state (2026-09-09)

- `equipment_menu.tscn` now places all candidate rows and hitboxes under a
  `CandidateClip` Control with `clip_contents` enabled. The clip spans the
  authored 49-pixel candidate window above the footer.
- `EquipmentMenuLayout` keeps candidate positions local to that clip, reapplies
  the scroll after responsive layout changes, and includes the parent offset in
  cursor placement. Existing equipment smoke coverage now checks the clip and
  reparenting.
- Runtime touch verification is still needed for fast swipes and both Hub and
  Pause instances at the supported aspect presets.

## Issue 6 — R5 and R6 currently produce identical rooms

**Observed:** R5 and R6 are identical in play, although they were intended to
be distinct. This suggests a room-generation, authored-room selection, seed,
or progression mapping regression.

**Likely owners:** `room_controller.gd`, `dungeon_graph.gd`, room definitions,
and progression/depth mapping. Existing R5/R6 route and generator documents
should be checked before changing content.

**Investigation:** Capture the room identifier, seed, generated graph, enemy
setup, rewards, and milestone data for both routes. Compare the source data and
the runtime selection key to locate whether the duplication is intentional
content or an indexing/fallback error.

**Acceptance criteria:** R5 and R6 have distinct authored or generated
identities matching their design contracts. Their distinction is stable across
fresh runs and does not depend on visual appearance alone. Add a deterministic
regression check for the room identity and the relevant milestone/depth data.

Status: **Implemented in source — runtime route/recovery verification pending**

### Current code state (2026-09-09)

- The active route branch now keeps authored R1–R5 and sends `completed_runs >=
  5` through the deterministic generated route. The historical R6 compiler
  remains available for old tooling but is no longer selected for new runs.
- Active run snapshots now store `layout_id`. New generated R6 checkpoints can
  be restored against the same topology; an older schema 1 checkpoint at the
  ambiguous R6 boundary is refused with an explicit discard path instead of
  silently regenerating under saved room IDs.
- `tests/generated_layout_smoke.gd` covers the generated route contracts and
  source diagnostics pass. A runtime fresh-run and save-recovery check remains
  before shipping this route policy.

### Approved resolution — generated R6+

Replace the active authored-R6 branch with the existing generated route path
for `completed_runs >= 5`; keep authored R5 at `completed_runs == 4`.
Do not create another authored R6 map in this slice. Retain historical assets
unless a separate cleanup is warranted.

Audit generator thresholds, flame availability, bound-origin handling, gate
requirements, validators, map labels, run recovery, and tests that assume R7
is the first generated run. Existing R6-only assumptions must not bypass
generated validation or restore the old authored branch.

Verify R5 remains authored; R6/R7 use generated layouts; fixed seeds reproduce
layouts; representative starter/bound combinations remain completable; saves
resume against the correct topology. Decide how existing in-progress authored
R6 saves are handled before shipping: do not silently regenerate their graph
under saved room IDs. Record the compatibility policy and regression coverage.

## Issue 7 — Add minimap access and flame-room fast travel

**Observed:** Backtracking can be frustrating. The player should be able to
open the minimap with the DS4 Select/Options button and fast travel between
the Hub and discovered flames from the Hub or a flame room.

**Likely owners:** `input_router.gd`, `dungeon_minimap_controller.gd`, room
interaction/flame-room logic, and the screen state/input-context boundary.

**Design questions to settle during implementation:** whether Select/Options
maps to a new `open_minimap` action or reuses an existing action; whether the
minimap is an overlay or a menu state; which flames count as discovered; what
confirmation/cancel behavior is required; and how touch, keyboard, and other
controllers access the same feature.

**Acceptance criteria:** Select/Options opens the minimap from valid gameplay
contexts without interfering with pause. A flame room presents only eligible
discovered destinations, allows cancel/back, and moves the player to the
selected flame with room/progression state intact. The feature is unavailable
or clearly inactive outside a flame room, and equivalent non-DS4 input paths
are documented. Add input, destination eligibility, and travel-state coverage
before relying on manual playtest.

Status: **Implemented in source — runtime travel verification pending**

### Current code state (2026-09-09)

- `open_minimap` is now a dedicated action with keyboard `M`, DS4 button 4
  (Share/Select), and DS4 button 6 (Options). Options shares the existing pause
  binding, but the gameplay frame consumes the minimap edge first; pause and
  other menu contexts remain isolated. The pause edge is synchronized while
  the map owns input so closing it cannot fall through into Pause on a held
  Options press.
- The expanded minimap lists all flame rooms, greys unvisited flames, keeps
  visited/current colors, and supports Up/Down, confirm travel, and Back/Options
  close. Touch has a MAP target and can close the overlay after opening it.
- `DungeonMapState` persists actual visited flame rooms separately from map
  landmark discovery. `RoomController.fast_travel_to_flame()` validates both
  endpoints, then uses the existing transition/save/arrival lifecycle without
  refilling or awarding room rewards.
- Source coverage includes unvisited/visited color state, serialization,
  input, and eligibility. Live MCP verification has opened and closed the map;
  travel itself still needs a runtime flame-to-flame playtest.

### Approved map/travel contract

Keep unvisited flame landmarks visible but greyed out and non-selectable for
travel. Visited flames retain their elemental colors. Map inspection should
remain available outside flame rooms; only travel is restricted by origin.

`DungeonMapState.reveal_landmark_rooms()` adds fire/rest landmarks to
`discovered_rooms` at run start. That dictionary cannot establish a visit.
Track actual visits separately, persist them for run recovery, and reset them
for a new run. Missing legacy visit data must not unlock every flame.

Use a typed travel request/result at the map/room boundary. Validate current
origin and destination again on confirmation, save outgoing room state, use
the existing room transition lifecycle, and place the player at a safe flame
arrival position. Preserve enemies, rewards, puzzle/Orb state, and Chroma;
travel must not implicitly grant a refill or duplicate room rewards.

Resolve the physical DS4 button before binding: Select/Share and Options are
not interchangeable, and pause already has a controller binding. Include a
keyboard action, touch map target, cancel behavior, and input-context isolation.
Test Hub and unvisited/visited flame destinations, non-flame origins, repeated travel,
save/load, and travel after changing the active puzzle color.

## Issue 8 — Bound identity must survive zero Chroma

**Reported:** Bound players appear to transform into Normal when depleted.
**Approved:** Retain the bound elemental identity, sprite/form, and existing
identity-based rules at zero Chroma. Apply desaturation and preserve resource
cost checks; retaining an element does not authorize free elemental attacks.

**Owners:** `player_chroma_component.gd`, player animation/equipment visuals,
and their palette/desaturation consumers through the existing frame schedule.

**Source evidence:** `spend_chroma()` already preserves a bound aspect and
returns a depleted temporary aspect to the bound aspect; unbound depletion
sets NONE. The report may involve presentation or another mutation path.
Trace zero-resource signals, runtime restore, palette selection, and sprite
selection before changing the domain rule.

**Acceptance:** A bound player spending their last Chroma keeps the bound
identity and form but becomes desaturated; pickups restore saturation.
Unbound depleted players become Normal and remain Normal when collecting.
Test bound depletion, temporary-aspect depletion, save/load at zero, and both
body and equipment presentation. Temporary fusion behavior beyond these rules
is unchanged unless explicitly agreed.

Status: **Implemented in source — runtime presentation verification pending**

### Implementation applied

- `PlayerChromaComponent.spend_chroma()` leaves a bound aspect active at zero;
  only the resource is depleted. The shared MP desaturation path now supplies
  the weakened visual state without replacing the elemental palette with Gray.
- Runtime restore repairs old snapshots that recorded a bound zero-Chroma
  player as `NONE`, and the Chroma smoke coverage checks bound Electric identity,
  palette, weakened mode, and recovery.
- A live body/equipment presentation check remains useful because the visual
  path is asynchronous and the standalone runner is currently crashing before
  producing test logs.

## Issue 9 — Normal players can collect Chroma

**Approved:** Normal/Gray players below the Chroma cap successfully collect
pickups, gain Chroma, and remain Normal. Resource storage and elemental identity
must be independent. Refilling must not resurrect an expired unbound element.

**Source evidence:** `restore_neutral_chroma()` currently rejects NONE and
forces bound identity when applicable. It also ignores its value argument and
uses CHROMA_PICKUP_VALUE. Audit this value contract; do not change pickup amounts
incidentally. `refill_chroma()` separately rejects NONE and needs review for
consistent caller expectations.

**Owners:** PlayerChromaComponent for resource/identity rules;
ChromaPickupController and its collection caller for pickup lifecycle.

**Implementation:** Separate successful resource restoration from attunement.
Audit collection eligibility, attraction, removal, HUD, runtime restore, and
any assumptions that NONE implies zero Chroma. Preserve current cap and cost
rules. Remove a pickup only when collection succeeds under the chosen policy.

**Acceptance:** Normal at zero and partial Chroma can collect without becoming
elemental; cap handling remains consistent; bound players retain their element;
save/load preserves Normal with positive Chroma; collection cannot duplicate
resource gains. Verify Normal ability behavior still follows existing rules.

Status: **Implemented in source — runtime collection verification pending**

### Implementation applied

- `restore_neutral_chroma(value)` now accepts Gray/Normal players, uses the
  pickup's actual value, caps at `MAX_CHROMA`, and preserves `NONE` as the
  identity while storing the resource.
- Bound identities remain elemental when they recover. A pickup is removed only
  after restoration succeeds, so a full bar leaves the pickup available.
- HUD refresh and Chroma presentation refresh run after a successful collection;
  focused Chroma smoke coverage checks Gray storage, cap behavior, bound
  recovery, and the full-bar retention path.

## Issue 10 — Pickup colors follow the player's needed Chroma

**Approved:** Display pickups in the player's current elemental color; use
neutral grey/white for Normal. Bound players at zero still need their bound
element's color, even though their body is desaturated.

**Working interpretation:** Pickups are adaptable resource pickups, not fixed
element drops. Existing ground pickups update when the player's effective
element changes, so color matches what collection will restore. Confirm this
interpretation during visual review; it does not grant elemental attunement.

**Owners:** PlayerChromaComponent supplies effective identity;
ChromaPickupController and the existing pickup spawn/render owner apply color.

**Implementation:** Centralize the color lookup using existing palette data.
Refresh live pickups on identity changes through a signal or scheduled owner;
avoid per-frame texture generation and new independent processing loops.
Keep animation, readability, and collection value independent from tint.

**Acceptance:** Spawned and existing pickups match Normal, bound, temporary,
and depleted states; collecting never changes identity because of pickup tint.
Verify multiple live pickups update together without a visible hitch.

Status: **Implemented in source — runtime color verification pending**

### Implementation applied

- `PlayerChromaComponent.chroma_palette_name()` supplies the effective current
  elemental/neutral palette. Spawned pickups use that palette for their texture,
  light, and collection effects.
- Existing pickups refresh only when the palette metadata changes, avoiding
  per-frame texture generation. Normal/Gray uses neutral grey; a depleted bound
  player continues to produce the bound element's color.
- Scene smoke coverage checks neutral spawn color and live recoloring to red;
  visual checks for bound, temporary, and multiple simultaneous pickups remain
  pending.

## Applied implementation order and remaining work

1. Correct sell identity and navigation performance together (Issues 2–3).
2. Fix equipment clipping and Hub footer geometry (Issues 5 and 1).
3. Move R6+ to generated maps and protect active-save compatibility (Issue 6).
4. Implement Chroma identity/storage, adaptive pickup color, and music warmup
   (Issues 8–10 and 4).
5. Implement the expanded minimap, persisted visits, and flame travel on the
   updated run-generation/state contracts (Issue 7).

The source implementation covers the approved behavior without changing
unrelated balance. Remaining work is measurement and runtime acceptance:
compare all Hub footer orientations, exercise a complete sell transaction,
profile cold/warm flame pickup, test equipment swipes in both menu instances,
restore a generated R6 checkpoint, travel between two visited flames, and
visually inspect bound/temporary pickup colors.

## Verification and handoff

Source verification on 2026-09-09: Godot MCP script diagnostics passed for all
changed scripts and focused smoke scripts. The live MCP session confirmed the
expanded minimap opens and closes from gameplay and that the Hub root shows the
shared footer. `git diff --check` is clean.

The full smoke suite was not run because an editor peer was active, as required
by `AGENTS.md`; earlier supervised standalone Godot attempts exited with signal
11 before producing test logs. Runtime timings, cold-start audio behavior,
flame-to-flame travel, orientation comparison, and the complete touch swipe
matrix therefore remain open acceptance checks. Do not record a phase change in
`docs/AUDIT.md` until those checks and the normal smoke gate are available.
