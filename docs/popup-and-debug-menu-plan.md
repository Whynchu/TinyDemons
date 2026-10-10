# Popup Timing and Pause Debug Menu Plan

Status: popup lifecycle and initial pause DEBUG controls are in source; the compact command rail and profile-backed Items page are implemented in source; runtime acceptance is pending

Scope: floating gameplay text timing, an opt-in pause-menu debug page, and the
profile's read-only gear collection

Owner: `effects_spawner.gd` for floating effects; `screen_route_controller.gd`
for Settings/Pause routing; `pause_screen_presenter.gd`,
`pause_items_presenter.gd`, and `pause_items_model.gd` for Pause presentation;
a narrow debug runtime controller for debug actions

Current code: damage numbers already scale-pop in `EffectsSpawner`, then begin
drifting immediately; XP, pickup, and gold labels share some paths but gold has
a separate spawn path. `SettingsService` stores device-wide preferences, and
`ScreenStateController` composes the Settings and Pause presenters.

Verification: focused popup lifecycle checks, settings persistence/menu
navigation checks, debug command boundary checks, and desktop/touch playtests.

Supersedes: none

## Goals

1. Make floating damage and reward text easier to read by inserting a four-
   frame hold after its scale pop and before it drifts/fades.
2. Add an opt-in `DEBUG MENU` setting and a dedicated `DEBUG` page in the
   pause menu with useful, clearly labeled testing controls.
3. Keep debug changes isolated from normal profile saves and preserve the
   existing input, pause, responsive-layout, and frame-schedule contracts.

These remain separate implementation slices. The popup change is
presentation-owned; the DEBUG page uses a separate layout and transient runtime
owner, and routes run changes through `RunFlowController`.

## Slice A — Four-frame popup hold

### Current behavior

`EffectsSpawner.spawn_health_number()` already starts health/damage numbers at
an enlarged scale. `update_damage_numbers()` eases the scale back while holding
position, then immediately starts drift, lifetime countdown, and fade. XP and
level text use `CombatRuntimeController.spawn_player_number()`; Soul, Chroma,
and item pickup text use that same route. Gold's `spawn_gold_from_root()` builds
a number directly and currently skips the shared pop lifecycle.

### Proposed lifecycle

Use one frame-scheduled lifecycle for gameplay floating text:

```text
POP / SETTLE -> HOLD (4 updates) -> DRIFT + FADE -> REMOVE
```

- Preserve each number's text, color, position, direction, critical outline,
  shadow, and existing pop curve.
- After the pop settles at its normal scale, hold its position and full
  readability for exactly four calls to the existing effects update. Do not
  advance its drift velocity or fade lifetime during those four updates.
- Then resume the current drift and fade behavior.
- Route gold through the shared helper so it receives the same lifecycle.
- Cover damage, critical damage, healing, shield absorption, immunity, XP,
  level-up, pickup, and gold text. Keep HUD counters, menu labels, and the
  world-to-HUD pickup travel arc on their existing animation contracts.
- Keep each effect's scale, outline, and shadow synchronized; retain the
  existing damage-number cap and cleanup behavior.

The hold is four scheduled visual updates, matching the authored-frame request.
If later device evidence shows this duration varies too much at low frame rate,
replace the tick count with a four-frame-equivalent duration while preserving
the same state boundary.

### Ownership and acceptance

Owner: `EffectsSpawner` and its `EffectsTuning` data; keep frame advancement on
the existing `GameplayFrameController` schedule. `CombatRuntimeController`
continues to choose the content and initial motion for each number.

Acceptance:

- Every listed floating-text type visibly pops, stays still for four updates,
  then moves and fades.
- Damage, healing, critical outline, and shadow layers remain aligned.
- Gold receives the same behavior without changing its amount or position.
- Dense combat still respects the existing cap and frees every visual layer.
- Native and Web render the same pixel scale and sequence.

## Slice B — Settings opt-in and pause DEBUG page

### Proposed navigation

Add a `DEBUG MENU` on/off option to the existing Settings screen. It defaults
to **OFF** and is stored with device preferences in `SettingsService`. When it
is ON during a run, the pause command rail shows `DEBUG`; selecting it opens a
separate pause page. Turning the setting off hides the command and returns the
player to the regular pause page. The title screen may change the preference,
but debug actions are available only from an active paused run.

The Settings page already has six rows in a 160-pixel native view. Adding this
option must include a compact reflow or scrolling treatment so the option,
description, controls, and BACK action remain reachable on narrow screens and
touch devices. The debug page itself should use a scrollable or paged list so
adding controls does not compress pixel labels or make touch targets too small.

### First control groups

Use clear value controls: checkbox-style toggles, bounded steppers, and explicit
actions with a confirmation where they reset run state.

- **Run:** a run/room selector and `RESET RUN` action.
- **Player:** player-level override; refresh derived stats and related HUD
  values immediately.
- **Combat:** invulnerability and unlimited Chroma/MP toggles.
- **Enemies:** pause enemy AI and select/force a test enemy variant using the
  existing enemy catalog.
- **Visual diagnostics:** show/hide collision and attack guides, targeting and
  aggro markers, and projectile guides where the existing draw paths allow it.

Start with this small useful set, then add controls through the same typed
registry so the screen does not become a collection of ad-hoc callbacks.

### Run number contract

`R#` is the player's **run number**, not a room depth. For example, after
finishing R5, the next run is R6. The debug selector edits this run number and
`RESET RUN` restarts the run-flow using that selected run number. Dungeon room
depth is not exposed as this control. Route the change through
`RunFlowController`/progression setup so map generation, enemy scaling, reward
rules, and the displayed run number all agree; do not patch the HUD label alone.

### Runtime and persistence boundary

The setting that reveals the page may persist in `settings.cfg`. Cheat values,
level overrides, and run-selection state should be transient for the current
debug session and must not leak into the profile, cloud save, or ordinary active-
run checkpoint. Provide an obvious `END DEBUG SESSION` or return-to-run path
that clears those overrides. `RESET RUN` should name the target before applying
and confirm destructive run replacement.

Do not implement controls by adding flags and menu branches to `GameplayState`
or by mutating profile fields directly from button callbacks. Keep presentation
in a narrow debug menu/layout owner. Define a typed debug action/context/result
boundary to the runtime owner; route run changes through `RunFlowController`,
level changes through `ProgressionController`/the runtime progression owner,
and combat/visual switches through their owning systems. Apply changes only
while gameplay is paused, then refresh affected status and HUD presentation.

### Debug menu acceptance

- Setting is OFF by default, persists independently of profile slots, and
  reveals/hides the pause `DEBUG` command immediately.
- Settings and the debug page work with keyboard/controller, mouse, and touch;
  responsive views keep every control and BACK reachable.
- `RESET RUN` uses the same normal initialization/cleanup boundary, clears old
  enemies/projectiles/effects, and does not duplicate rewards or settlement.
- Level changes refresh XP/level presentation and derived combat values, then
  disappear when the debug session ends; the saved player profile remains
  unchanged.
- Every toggle reports its current state, applies only to the intended owner,
  and clears on exit or new run unless explicitly designated as a preference.
- Debugging controls do not change ordinary gameplay when the menu is OFF.

## Slice C — Compact Pause rail and profile Items page

Status: implemented in source; focused runtime and visual acceptance pending.

The Pause root presents Status, Equipment, Items, Settings, optional Debug, and
Quit Title in that order. `MenuCommandList` navigates only visible and enabled
commands, and `PauseScreenPresenter` positions the visible commands on
consecutive rows. If a preference change hides the selected command, selection
advances to the next available command or wraps to the last one.

The Items page reads `PlayerProfile.inventory`, including equipped gear. The
current filters are All, Weapons, Armor (Head/Body/Arm/Shield), and Accessories;
sorting toggles between Name A-Z and Rarity. Functionally identical gear
instances are grouped into a displayed quantity. Details show item name, slot,
rarity, owned count, enhancement, equipped state, stat bonuses, and authored
effects. This page is read-only.

The current data model supports equipment only. Consumables and Key Items are
reserved for later typed definitions and profile/run storage work, so the page
does not show empty tabs for them. Add those filters when their definitions and
authoritative storage paths exist.

Acceptance:

- The pause smoke confirms hidden Debug leaves no rail gap, skips stale hidden
  selections, and preserves Settings and Quit Title order.
- The Items smoke confirms profile inventory, grouped counts, filters, sorting,
  and the shared framed page.
- At 240x160 and the responsive wide surface, labels and details fit without
  crossing the frame or footer; keyboard/controller navigation and touch targets
  remain clear.
- Runtime visual acceptance is recorded only after an in-editor playtest.

## Implementation sequence

1. [x] Implement and characterize the shared four-update popup hold, including
   the separate gold path.
2. [x] Add a default-off persisted Settings opt-in, responsive seven-row panel,
   and hidden-by-default pause command.
3. [x] Add a separate pause DEBUG page, transient state owner, confirmed R# run
   reset, and player-level override.
4. [x] Add initial toggles for invulnerability, unlimited Chroma, enemy pause,
   and geometry guides.
5. [ ] Run the focused popup/settings and Pause rail/Items checks plus the
   Debug-page/touch playtest, then the curated release gate when the editor is
   not already running.
6. [ ] Record runtime proof and remaining limitations in `KNOWN_ISSUES.md` and
   refresh the generated script index.

## Risks to resolve during the slices

- A four-update hold lengthens visible popup lifetime; confirm that overlapping
  damage numbers in busy fights remain readable under the existing cap.
- The settings screen is already row-dense; responsive overflow must be solved
  before adding the new option.
- Run reset and player level changes touch durable progression boundaries;
  test against a disposable profile and prove ordinary saves are unchanged.
- The pause screen is in a large mixed owner. Keep the debug page in a separate
  presentation owner and keep cheat logic out of the screen controller.
