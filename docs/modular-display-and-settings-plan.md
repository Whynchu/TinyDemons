# Tiny Demons — Modular Display and Settings Plan

Status: implementation complete locally; responsive presentation and closed-
entrance seam correction implemented; automated verification green through
2026-08-29; physical browser/device matrix pending

Date: 2026-08-27

This document is the design and implementation handoff for making the game's
display modular — aspect-ratio support beyond the native 240×160 (3:2), with
fixed 16:10 and 16:9 presets plus an adaptive `FULL` mode — plus a settings
panel on the title screen and in the pause menu (fullscreen, aspect,
pixel-perfect scaling, music/SFX volume), and a quit-to-title pause option.
The look must be preserved: the void background and the decorative black bars
expand to fill the wider view rather than letterboxing the game in plain black.

Design decisions were locked with the team on 2026-08-27 (§9). Current-state
facts below were audited against the tree on 2026-08-26/27 (§10).

Related docs:

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — component ownership rules
- [`web-port-implementation-plan.md`](web-port-implementation-plan.md) — the
  integer-scaling and touch-layout work this builds on
- [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) — tuning resource index

## 1. Goal and non-goals

### Goal

- The game renders at a fixed logical height of 160 px. `FULL` derives its
  logical width from the live window/browser viewport; fixed 3:2 (240×160),
  16:10 (256×160), and 16:9 (284×160) presets remain available. All modes
  preserve the pixel-art look: nearest-neighbor, optional integer scaling,
  the void background, and decorative top/bottom bars fill the view.
- A settings panel reachable from the title screen and the pause menu offers:
  fullscreen toggle, aspect ratio, pixel-perfect (integer) toggle, one music
  slider, one SFX slider.
- The pause menu gains RESUME and QUIT TO TITLE alongside SETTINGS.
- Everything works identically on desktop and web (fullscreen on web is
  browser-gated — see §4).

### Non-goals for this slice

- Additional fixed presets such as 4:3, 21:9, or device-specific ratios. The
  adaptive `FULL` mode is intentionally the way to use a landscape viewport
  that does not match one of the fixed presets.
- Per-profile display settings (settings are device-wide).
- A glyph/icon atlas for the settings UI; the existing pixel-text style is
  reused.
- A freeform window-size picker; desktop aspect changes retain the current
  window height and adjust its width to the selected supported ratio.
- Rebinding, language, or accessibility settings.

## 2. Verified current state

The bullets below preserve the original audit snapshot for context; the
implemented behavior and corrections are recorded in §§3–6 and §11.

The full audit evidence is in §10. The load-bearing facts:

- **Three bar/background layers exist, all hardcoded to 240×160:**
  1. Decorative in-game frame: `BlackBars.png` (opaque near-black RGB(6,6,6)
     bars y 0–15 and y 145–159, transparent middle; HUD text sits on them;
     `scenes/main.tscn:559-562`).
  2. Void background: `BG.png`, flat RGB(17,19,24), exactly 240×160,
     screen-fixed on CanvasLayer −10 (`scenes/main.tscn:108-113`). Beyond
     x=240 there is nothing — the engine default clear color.
  3. Engine letterbox bars from integer scaling (pure black).
- **All UI is absolute 240×160 pixel coordinates** — no anchors or
  containers anywhere: HUD (`scenes/player_hud.tscn`,
  `scripts/hud_controller.gd:279-400`), minimap
  (`scripts/dungeon_minimap_controller.gd:9-11`), overlays and menus
  (`scripts/screen_state_controller.gd:501-1395`), title screen
  (`screen_state_controller.gd:1265-1278` with hardcoded button bob at
  `:176-177`).
- **Rooms** are 8×8 isometric diamonds (~128 px wide) centered at
  `Map/FloorTiles/FloorLayer` position (120, 64) (`scenes/main.tscn:119-125`),
  surrounded by void; only the boss room is larger than the screen and uses a
  player-following camera with no limits
  (`scripts/room_controller.gd:1371-1394`).
- **No settings infrastructure**: no ConfigFile, no fullscreen code; the
  profile is per-slot run data (`scripts/player_profile.gd:15-45`) and is the
  wrong home for device-wide display prefs.
- **Pause is the hub overlay in pause mode**
  (`scripts/hub_flow_controller.gd:72-76`); no RESUME/SETTINGS/QUIT items.
- **Volumes are compile-time constants** (`scripts/sound_manager.gd:22-25`)
  with one Master bus; a per-play runtime volume field exists but is not
  persisted (`sound_manager.gd:73`).
- **The touch overlay** adapts to the visible rect already
  (`scripts/touch_controls_layer.gd`), but its `BASE_CONTENT_SIZE` fallback
  assumes 240×160 and must follow the active view size.
- Wide modes only add **width**; height stays 160 in every mode. Top/bottom
  bar thickness and all bottom-row HUD positions are unaffected vertically.

## 3. Display model

The lever is `Window.content_scale_size`. The canvas-items pipeline keeps the
native vertical scale with `keep_height` and preserves integer scaling when
pixel-perfect mode is enabled. This is important because `keep` would fit a
wide logical base into a narrower 3:2 target by shrinking the entire view,
making menus look shorter instead of adding horizontal space.

On desktop windowed mode, the display controller keeps the current window
height and updates only the width for the selected supported ratio. Web and
mobile builds cannot resize the browser/device viewport, so they use the same
height-preserving canvas behavior inside the available viewport.

| Mode | Base size | Ratio | Notes |
| --- | --- | --- | --- |
| Adaptive FULL | live width×160 | browser/window ratio (minimum 3:2) | Default; reads the current landscape viewport |
| Native 3:2 | 240×160 | 1.500 | Fixed compatibility preset |
| Wide 16:10 | 256×160 | 1.600 | Fixed preset; +16 px of width |
| Wide 16:9 | 284×160 | 1.775 | Fixed preset; +44 px of width (0.16% off exact 16:9 — imperceptible) |

Reference integer scales: 1920×1080 desktop renders 6× in all three modes
(1440×960 / 1536×960 / 1704×960). A hiDPI phone in portrait (780×1688 device
px) renders 3× / 3× / 2× — the known trade-off: 16:9 mode renders smaller on
portrait phones. Accepted; the touch overlay compensates with physical-size
targets.

Settings (device-wide):

| Key | Values | Default |
| --- | --- | --- |
| `fullscreen` | on/off | off |
| `aspect` | `FULL` / `3:2` / `16:10` / `16:9` | `FULL` |
| `pixel_perfect` | on (integer) / off (fractional fill) | on |
| `music_volume` | 0–100, step 10 | 100 |
| `sfx_volume` | 0–100, step 10 | 100 |

Pixel-perfect off switches `Window.content_scale_stretch` back to fractional
(fill the window, seams may appear — the setting exists for players who
prefer a full screen over crisp pixels). Aspect and pixel-perfect compose
freely.

## 4. Component design and ownership

| Concern | Owner | Change |
| --- | --- | --- |
| Settings load/save/apply | `scripts/settings_service.gd` (new, stateless-ish helper over a `user://settings.cfg` ConfigFile) | Device-wide store; applied once at bootstrap and live on every change; IndexedDB flush caveat from the web plan applies |
| Display application | `scripts/display_controller.gd` (new node, created by `gameplay_bootstrap.gd`) | Owns `content_scale_size`, `content_scale_stretch`, fullscreen (`DisplayServer.window_set_mode`); emits `view_size_changed(size)` |
| Layout truth | `scripts/display_layout.gd` (new, stateless) | `view_size()`, edge anchors (`left_x`, `right_x(w)`, `center_x(w)`, `top_y`, `bottom_y(h)`), and the per-element HUD classification (left / center / right) |
| HUD re-homing | `hud_controller.gd`, `player_hud.tscn` positions via layout offsets | Right-cluster (gold/soul/run timer/cooldowns/input prompts) anchors to the right edge; centered clusters (HP/MP, target name) shift by half the extra width; left/bottom items unchanged |
| Overlays and menus | `screen_state_controller.gd` | `create_overlay` sizes to the view; manual `(240 − w)/2` centering math becomes view-relative; title text/button bob keeps absolute y, x recenters |
| Void + frame | `main.tscn` Background sprite, `BlackBars.png` | Engine `default_clear_color` set to the void RGB(17,19,24); BG extended to cover the view (flat color — a ColorRect sized to the view is acceptable); decorative bars become runtime-drawn strips (top 16 px, bottom 15 px, RGB(6,6,6)) sized to view width. The static PNG is retired so all modes share one code path |
| Room centering | `display_controller.gd`, `room_controller.gd` | Keep Map/Actors, walkable polygons, collision shapes, and saved positions in stable world space; a display-owned camera centers normal rooms while the existing boss camera remains authoritative |
| Touch overlay | `touch_controls_layer.gd` | Read the live logical view size from the display controller; park gameplay controls in safe corners, scope menu taps to the active overlay, and expose direct native-button targets for menu actions |
| Volumes | `sound_manager.gd` | `set_music_volume(0-100)` / `set_sfx_volume(0-100)`: linear value → dB offset applied when (re)building players and live to existing players; stays on the Master bus — no bus split in this slice |
| Settings UI | `screen_state_controller.gd` (title + panel), `hub_flow_controller.gd` (pause) | Title gets a SETTINGS button under CONTINUE; pause-mode hub panel gets RESUME / SETTINGS / QUIT TO TITLE |
| Web page backdrop | `export_presets.cfg` `html/head_include` | Change page CSS background from `#000` to the void `#111318` so out-of-canvas page pixels match |

When these land, update `AGENTS.md` (ownership table) and
`docs/ARCHITECTURE.md` (scripts list) in the same commit.

### Fullscreen rules

- Desktop: `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN /
  WINDOW_MODE_WINDOWED)`; remember the windowed rect implicitly via the
  existing 960×640 override.
- Web: browsers allow fullscreen only inside an input-event dispatch. The
  settings panel's `Button.pressed` signal qualifies, so the toggle works on
  web — but it must be flipped directly from the signal handler, not from a
  deferred call.

### Settings panel behavior

- Rows: FULLSCREEN (ON/OFF), ASPECT (FULL / 3:2 / 16:10 / 16:9), PIXEL PERFECT
  (ON/OFF), MUSIC (0–100), SFX (0–100).
- Up/down moves a cursor; left/right adjusts the value (keyboard, gamepad,
  and touch all reach this — no drag-only controls); Circle/Xbox B confirms,
  Cross/Xbox A backs out, and the footer reflects the active device.
- Every change applies immediately (live preview) and persists immediately.
- The title version and pause version are the same panel built by one helper;
  pause wraps it with the hub's pause-mode chrome.

### Quit to title

QUIT TO TITLE abandons the current run (no settlement screen) and returns to
the title state through the existing `save_flow_controller` title flow.
Anything already persisted to the profile (souls, unlocks, prior settlements)
is untouched. Implementation must verify the run-state teardown path used by
game-over → title is reused, not duplicated.

## 5. HUD re-homing map

Classification to implement in `display_layout.gd` (verify each element
against the live scene during Phase 2 — this list comes from the audit):

- **Left-anchored (no move)**: player status/level/XP cluster
  (`player_hud.tscn:182-216`), minimap (`dungeon_minimap_controller.gd:9-11`),
  room number / dungeon run (`hud_controller.gd:321,382`).
- **Right-anchored (shift +extra width)**: gold display
  (`player_hud.tscn:280`), soul display (`hud_controller.gd:346-349`),
  cooldown rows (`hud_controller.gd:279-280`), run timer
  (`hud_controller.gd:374`, `player_hud.tscn:312`), input-prompt buttons
  (`hud_controller.gd:394-400`).
- **Center-anchored (shift +half extra width)**: HP/MP bar row
  (`player_hud.tscn:218,249`), target name/focus labels
  (`hud_controller.gd:46,418,426`), enemy HP bar (`main.tscn:564-578`).
- **Unchanged**: world-anchored interact prompt (follows the world marker).

## 6. Ordered implementation plan

One testable milestone per commit. Run
`pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1` before every
commit; register new tests in `tests/run_all_smoke.ps1`.

### Phase 1 — Settings store and display application (native 3:2 only)

- Add `settings_service.gd` (ConfigFile at `user://settings.cfg`, round-trip
  with defaults) and `display_controller.gd` (fullscreen, pixel-perfect
  toggle, `view_size_changed` signal; aspect writes but stays 3:2 until
  Phase 4).
- Add `sound_manager.set_music_volume/set_sfx_volume` (linear → dB offset,
  live-applied) and persist through the settings store.
- New `tests/settings_service_smoke.gd`: defaults, round-trip, corrupt-file
  fallback, clamping.

Exit condition: settings persist and apply at 3:2; zero visual change by
default.

### Phase 2 — Layout owner and HUD re-homing

- Add `display_layout.gd` with the classification map (§5); HUD call sites
  read offsets from it (behavior identical at 240 width).
- Update `ui_layout_guide.gd` preview math to match the layout owner's
  formulas so the editor preview stays honest.
- New `tests/display_layout_smoke.gd`: at 240 width every offset is zero; at
  284 width right-anchored elements shift +44, center +22, left unchanged;
  minimap and room number fixed.

Exit condition: full suite green with no visual diff at 3:2 (screenshot
compare against `docs/game-screenshot.png` expectations).

### Phase 3 — Settings panel on the title screen

- Title screen gains SETTINGS (third button; extend the cursor/bob logic at
  `screen_state_controller.gd:176-177`).
- Build the panel (§4) with the five rows; wire to the settings store and
  display controller; fullscreen flips from the button-press handler.
- New `tests/settings_panel_scene_smoke.gd`: panel opens from title, rows
  adjust values, store persists, closing returns focus to the title cursor.

Exit condition: fullscreen, pixel-perfect, and both volumes are changeable
from the title screen on desktop and web.

### Phase 4 — Wide aspects: background, frame, rooms, touch

- Set `default_clear_color` to RGB(17,19,24); extend the void background to
  the view; replace `BlackBars.png` with runtime-drawn bars at view width.
- Center normal rooms through the display-owned camera; do not translate Map,
  Actors, cached walkability, collision shapes, or saved positions. Update the
  touch layer to read the live logical view size and use safe corner parking.
- Enable `FULL`, 16:10, and 16:9 in the ASPECT row while retaining 3:2.
- Tests: overlays and decorative bars cover the full view at fixed widths and
  live `FULL`; the room remains centered without collider drift; touch layout
  math runs at all fixed sizes and a wide live viewport.

Exit condition: fixed widescreen modes and adaptive `FULL` look correct — void
and frame fill the view, HUD spreads to the edges, no raw clear-color strip,
and mobile landscape controls remain inside the safe area.

### Phase 5 — Pause menu items

- Pause owns a separate opaque route with RESUME, STATUS, EQUIPMENT, SETTINGS,
  and QUIT TO TITLE (§4), keyboard/gamepad/touch navigable. Status and
  Equipment replace the pause command page; Settings replaces Pause and returns
  only to Pause.
- New `tests/pause_menu_scene_smoke.gd`: items exist, RESUME returns to the
  run, QUIT TO TITLE reaches the title state with the run abandoned and the
  profile intact.

Exit condition: the pause flow is self-sufficient on all three input types.

### Phase 6 — Verification matrix and docs

- Visual matrix: desktop (fixed aspects plus `FULL` × integer on/off ×
  windowed/fullscreen), web (Chrome/Firefox), and a borderless iPhone
  home-screen launch in landscape (including a non-16:9 surface), with
  screenshots recorded in this file's log.
- Update `README.md` (controls/settings), `AGENTS.md` and `ARCHITECTURE.md`
  (new owners), `GAMEPLAY_TUNING.md` (no tuning exports expected — confirm).

## 7. Verification checklist

- Settings persist across restarts and corrupt-file recovery (automated).
- At 240 width, zero visual diff vs the pre-feature baseline (automated
  offsets + manual screenshot).
- Every overlay covers the full view at 240/256/284; no 240-wide black
  overlay leaks at wide modes.
- Decorative bars are exactly 16 px top / 15 px bottom at every width; HUD
  text still sits on them.
- Room diamond is horizontally centered in all modes; boss room camera
  unchanged.
- Fullscreen toggles on desktop and from the web settings panel (input-event
  rule respected).
- Volumes apply live and persist; no clipping at 100.
- Touch controls park correctly in all modes; QUIT TO TITLE then NEW GAME
  starts cleanly (state teardown).
- Full `tests/run_all_smoke.ps1` green.

## 8. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| A missed hardcoded 240/160 position leaks in wide mode | Phase 2 grep pass over `scripts/` and `scenes/` for `240`/`160` UI constants; layout tests assert zero offset at 240 so regressions fail loudly |
| Extra void looks empty at 16:9 | Void-colored clear color + extended BG make it read as intentional; HUD spreads to edges so the space is used; room stays centered |
| Portrait phone shrink in 16:9 (3× → 2×) | Accepted trade-off; touch targets keep physical size; pixel-perfect setting lets players choose |
| Fullscreen silently failing on web | Apply from the `Button.pressed` handler only; manual matrix verifies |
| Quit-to-title leaking run state | Reuse the game-over → title teardown path; scene test asserts clean re-entry |
| Pause menu crowding (hub panel is 156×116) | Settings opens as its own panel over the hub chrome rather than stuffing rows into the hub grid |

## 9. Resolved decisions (2026-08-27)

1. **Preserve the look by expansion**: the void background and decorative
   black bars extend to fill wider ratios — no plain-black letterbox strips
   inside the presentation. Residual engine bars are void-colored via the
   clear color.
2. **Ratio list**: `FULL` (adaptive default), 3:2 (native), 16:10, and 16:9.
   Additional fixed presets such as 4:3 and ultrawide are excluded from this
   slice; `FULL` remains available for arbitrary landscape browser surfaces.
3. **HUD spreads to the new edges** in wide modes (left/center/right
   classification in §5).
4. **Settings live on the title screen AND in the pause menu**; the pause
   menu also gains RESUME and QUIT TO TITLE.
5. **Volumes**: one music slider and one SFX slider, 0–100 step 10, applied
   live and persisted device-wide.
6. Settings storage is a device-wide `user://settings.cfg`, not the per-slot
   profile (audit finding: profile schema is run data only).
7. Pixel-perfect (integer scaling) stays ON by default with an opt-out
   toggle, and `FULL` stays the default aspect so web/mobile launches use the
   actual landscape viewport rather than a guessed phone ratio.

## 10. Research verification log

Audited 2026-08-26/27 against the live tree:

- Frame/background/void: `BlackBars.png` measured 240×160, opaque bars y 0–15
  and y 145–159, RGB(6,6,6), no script references; `BG.png` 240×160 flat
  RGB(17,19,24) on CanvasLayer −10 (`main.tscn:108-113,559-562`);
  `project.godot` sets no `default_clear_color`.
- Fixed-position UI: HUD `player_hud.tscn` + `hud_controller.gd:279-400`;
  minimap `dungeon_minimap_controller.gd:9-11`; overlays
  `screen_state_controller.gd:501-1395` (title `:1265-1278`, bob `:176-177`,
  RunComplete `:524-526`, Hub `:546-548`); transition
  `gameplay_state.gd:713`. Editor HUD preview `ui_layout_guide.gd` mirrors the
  same constants and must stay in sync.
- Rooms: 8×8 diamond, 16×8 tiles, FloorLayer at (120, 64)
  (`main.tscn:119-125`, `isometric_room_layer.gd:52-54`); boss camera
  `room_controller.gd:1371-1394`.
- No settings/fullscreen/ConfigFile code; profile is per-slot run data
  (`player_profile.gd:15-45`); pause is the hub overlay
  (`hub_flow_controller.gd:72-76`); volume constants
  `sound_manager.gd:22-25,73`.
- Touch overlay adapts to the visible rect but has 240×160 fallbacks to
  replace (`touch_controls_layer.gd`).
- Platform rules (from the web plan research): web fullscreen only inside an
  input-event dispatch; `user://` persists to IndexedDB on web.

## 11. Implementation record

The six phases are implemented on `feature/ffiii-stats-menu-rework`:

1. `SettingsService` owns device-wide `user://settings.cfg` preferences;
   `DisplayController` applies logical size/scaling/fullscreen; and
   `SoundManager` applies live persisted music/SFX volume offsets.
2. `DisplayLayout` is the shared left/center/right offset source for HUD,
   overlays, menus, and touch layout. `FULL` resolves the live viewport width
   while fixed presets remain deterministic.
3. Title SETTINGS and the shared five-row settings panel support keyboard,
   gamepad, and touch/button activation with immediate persistence.
4. `FULL`, 3:2, 16:10, and 16:9 expand the runtime void/frame, HUD, overlays,
   and touch layout while preserving the fixed 160 px height. Normal rooms use
   a display-owned camera, so aspect changes do not move collision geometry or
   saved actor positions; the boss camera remains authoritative.
5. Pause mode owns an opaque route with RESUME, STATUS, EQUIPMENT, SETTINGS,
   and QUIT TO TITLE; child pages replace the command page and Settings returns
   only to Pause. Hub pages follow the same exclusive-route rule.
6. README, contributor ownership, architecture, tuning, export CSS, and the
   smoke-suite registration are updated with the implementation boundaries.

Automated evidence: the focused display, touch, settings, pause, hub, dialogue,
menu-route, web-export, and main-scene checks pass. The remaining verification
item is the manual visual matrix on physical desktop, browser, and phone
targets (especially fullscreen and portrait integer-scale trade-offs); it does
not block the code implementation.

## 12. Regression follow-up — 2026-08-27

The completed follow-up pass covers four boundary regressions found while using
the new wide-display and menu work:

| Symptom | Contract and fix | Automated coverage |
| --- | --- | --- |
| Charge hold shows the prior attack frame | `charge` owns the single authored between-attacks pose; the shared attack overlay stays hidden while it is held, including after palette changes | `spin_charge_scene_smoke` |
| Spin ends in a between/after pose | Spin's authored final frames are its complete recovery; both the frame-controller fallback and equipment transition hold are skipped/cleared | `spin_charge_scene_smoke` |
| Settings BACK confirm starts New Game | A title-settings close arms a release lock; the title dispatcher waits for the confirm/cancel edge to be released | `settings_panel_scene_smoke` |
| 16:9 enemies appear shifted or outside the room | Spawn solving and saved spawn positions use world space; actor placement goes through `global_position`, and saved positions rebase when Map/Actors move | `enemy_room_entrance_scene_smoke` at 16:9 |
| Hub/Pause child pages overlap their source page or accept hidden input | Each route owns an opaque full-screen overlay; child pages hide the command rail and only the active route is polled | `menu_route_scene_smoke`, `pause_menu_scene_smoke`, `demon_hub_menu_scene_smoke` |
| Mobile landscape is not centered or controls drift with aspect ratio | `FULL` derives logical width from the live browser viewport; world centering uses a camera and touch layout uses the active logical size | `display_responsive_scene_smoke`, `touch_controls_smoke` |
| Dialogue choice taps do not activate YES/NO | Touch hit-testing searches the dialogue CanvasLayer parent so sibling choice buttons are included | `dialogue_choice_smoke` |

The shared hub overlay also explicitly hides pause-only action buttons whenever
it is opened from the cloaked demon. This prevents stale RESUME/SETTINGS/QUIT
controls from appearing underneath the normal Demon Hub, with a regression
assertion in `hub_binding_smoke`.

All exit criteria are met: the focused smoke tests for each row pass,
`git diff --check` is clean, and the complete `tests/run_all_smoke.ps1` suite
passes through web export and the headless main-scene boot. Manual wide-mode
visual checks remain useful after the code gate, particularly on a physical
16:9 phone where integer scaling can choose a smaller vertical scale.

## 14. Responsive presentation and entrance-seam follow-up — 2026-08-29

Testing the browser-style landscape surface exposed two integration gaps that
belong to this plan rather than to individual menus:

- A fixed aspect frame could remain at logical x=0 while the engine exposed a
  wider logical viewport. The map camera was centered correctly, so the stage
  and UI appeared to disagree about the device center. Physical resize events
  also did not always cause the menus to reflow.
- Hidden lower entrance art left a narrow walkability seam. Because player
  movement previously validated only the foot point, the actor could scrub a
  body edge into that seam or briefly stand on the unrendered placeholder.

The correction contract is:

1. `DisplayController` measures the visible logical surface on every resize,
   selects `KEEP_HEIGHT` only when the surface can preserve the selected frame's
   height, and centers the active fixed frame through the interface
   `CanvasLayer` offset. `FULL` remains adaptive; fixed desktop presets restore
   the pre-preset window when returning to `FULL`; web/mobile never resize the
   device surface.
2. The void background follows the measured visible logical width, while bars,
   HUD, menus, transitions, and loading overlays remain sized to the active
   frame. The world camera and all collision/saved-position data remain in
   authored coordinates. Web CSS now gives the canvas and its containing page
   the full landscape surface without a competing viewport size.
3. Both lower authored sockets declare their return trigger as part of the
   closed blocker fence. Walkability keeps the actor's existing foot-path
   contract so room edges and diagonal doorway approaches remain smooth; the
   closed entrance polygons provide the localized seam guard. Open connection
   state still removes the corresponding blocker before traversal.

Coverage is in `display_layout_smoke`, `display_responsive_scene_smoke`, and
`wall_socket_geometry_smoke`, including an open lower-entrance movement test;
the remaining verification item is the manual
desktop/browser/iPhone landscape matrix at 4:3, 16:10, 16:9, and `FULL`.

## 13. Charge-pose Chroma regression — 2026-08-27

### Symptom

The held attack/charge pose could look ghosted or appear to change frames as
the player's Chroma fell. Charge displays the player base sprite while hiding
the attack overlay, but the shared MP desaturation bridge was still treating
`charge` as an attack-layer animation. Its grey reference texture therefore
landed on the hidden attack material, while the visible base sprite retained
the previous attack frame as its grey sample. The stale sample became visible
as the desaturation mix increased.

### Correction

Charge now uses the base player's desaturation material. Attack and spin
animations continue to use the attack overlay material. Chroma amount changes
only the material's grey mix; it cannot select or expose a different charge
frame.

### Verification

`spin_charge_scene_smoke.gd` now verifies that the visible base layer samples
the authored `between` grey frame and remains on that same pose at 100, 50, 10,
and 0 Chroma. The focused scene test and complete smoke suite both pass.

## 14. Player HUD authoring follow-up — 2026-08-29

### Symptom

Moving the first visible layer in `scenes/player_hud.tscn` does not always
produce an obvious change in the live HUD. The editor preview backdrop can be
the selected/visible layer instead of the authored HUD group, while the actual
HUD is instanced under `main.tscn`. Runtime layout code can then reposition
the same groups again for the current display mode.

### Current sources of confusion

- `PlayerHud` owns an editor-only `PreviewContext` containing the backdrop and
  black bars; the actual status, currency, room, and timer groups are siblings
  outside that preview context.
- `player_hud.gd` regenerates example/static text and currently applies a
  level-label offset as part of that setup, which can override an intentional
  editor position.
- `HudController` reapplies responsive positions for health, mana, gold, souls,
  and the run timer. `DisplayLayout` adds the aspect-ratio offset at runtime,
  so authored positions need to remain the stable base positions rather than
  being replaced by hard-coded screen coordinates.

### Follow-up

Make the source HUD scene authoritative and easier to author: expose the
movable groups and their base anchors clearly in the editor, preserve those
authored bases when responsive offsets are applied, avoid unconditional text
setup from resetting layout positions, and make the preview backdrop visually
helpful without intercepting selection of the real HUD nodes. Add an editor/
runtime smoke check so a deliberate scene movement is reflected in the
assembled HUD at native, 4:3, 16:9, and 16:10 layouts. The existing
`scenes/player_hud.tscn` working-tree edit must be reviewed and preserved while
this follow-up is implemented.

Currency visual note: use `#A73BA7` as the Souls base colour so the HUD and
world pickup match the Square-button icon. Derive the lighter soul outline /
highlight from that base while preserving the authored black eyes and grey
source-art details that are not part of the recolour.
