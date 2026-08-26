# Tiny Demons — Web Port Implementation Plan

Status: implementation complete locally; browser/device verification pending

Hosting target: GitHub Pages project site, deployed by GitHub Actions from
`main` (`https://whynchu.github.io/TinyDemons/`)

Date: 2026-08-26

This document is the design and implementation handoff for shipping TinyDemons
as a playable browser game with touch controls, gamepad peripherals (Backbone
and similar), and automatic last-input-device detection — **while desktop
development continues on the same codebase**. Treating the port as a permanent
second target rather than a one-time fork is a core requirement; §4 defines
the coexistence rules that keep web support from rotting as the game grows.

Feasibility was verified against the codebase and current platform
documentation on 2026-08-26; see §11 for the full research log. Verdict:
**feasible with no hard blockers.** The game is a strong candidate: 240×160
nearest-neighbor viewport, pure GDScript, no threads/.NET/GDExtension, full
gamepad bindings already present, and a single input polling boundary
(`input_router.poll()`, `gameplay.gd:81`).

Related docs:

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — component ownership rules
- [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) — tuning resource index
- [`gameplay-smoke-checklist.md`](gameplay-smoke-checklist.md) — manual checks

## Implementation progress

- [x] GitHub Pages project-site workflow and single-threaded Web preset
- [x] Last-input-device tracker with prompt-label API
- [x] Optional touch provider merged through `InputRouter`
- [x] Focused tracker, touch-provider, and router smoke coverage
- [x] Web-scoped occlusion fallback and repeatable OGG conversion pipeline
- [x] Audio payload/performance hardening
- [ ] Browser/device matrix and production Pages deployment verification

## 1. Goal and non-goals

### Goal

A player can open a URL in a desktop or mobile browser and play the full game:

- with keyboard/mouse, or
- with a gamepad (Xbox/PlayStation/Backbone-class devices), or
- with on-screen touch controls on phones/tablets,

and can switch between those devices mid-session, with control prompts and
on-screen UI following the **last device that produced deliberate input**.

### Non-goals for this slice

- Native mobile apps (Android/iOS store builds). The browser build is the
  mobile story.
- Threaded web export. Single-threaded is the target (§3); threads are a
  later optimization if profiling demands them.
- Touch gestures (pinch, pan, double-tap). They are flaky on mobile browsers
  (§11) and nothing in the game needs them.
- Mouse-driven gameplay changes. Desktop mouse behavior is unchanged; menus
  already accept clicks via real `Button` nodes.
- In-game input remapping UI. The Input Map stays the binding authority.
- Backbone-specific code. A Backbone attached to a phone is a standard
  browser gamepad (§3); it must work through the generic path.

## 2. Verified starting position

Codebase audit results (evidence in §11):

| Area | State | Port impact |
| --- | --- | --- |
| Renderer | `mobile` (`project.godot:109`) | Must be `gl_compatibility` on web — override per-platform (§4) |
| Viewport | 240×160, `canvas_items` stretch, nearest filter (`project.godot:20-24,107`) | Ideal; trivially cheap to rasterize |
| Input map | 10 actions, all with joypad bindings (`project.godot:26-103`) | Gamepad ready today |
| Input polling | Single seam: `input_router.poll()` (`input_router.gd:19-28`, `gameplay.gd:81`); sticks/D-pad/triggers polled in code (`input_router.gd:27-28,64-111`) | Touch layer merges at exactly one place |
| `_input()` handlers | None anywhere in `scripts/` | Device detection adds the first one, isolated in its own node |
| Mouse/touch gameplay | None (no `InputEventMouse*`, no `InputEventScreenTouch`) | Clean slate |
| Menus/dialogue | Real `Button` nodes driven by focus + `.pressed.emit()` (`gameplay.gd:91-101`, `gameplay_frame_controller.gd:87-101`, `screen_state_controller.gd:1090-1172`) | Taps work via Godot's default emulate-mouse-from-touch; focus flows need touch affordances (Phase 3) |
| Export presets | Stub only (`export_presets.cfg`) | Real Web preset must be authored |
| Saves | `user://` JSON (`profile_save_service.gd:4-7`) | Maps to IndexedDB on web; verify flush timing |
| Platform-specific code | None in runtime scripts | Nothing to stub out |
| Shaders | One simple `canvas_item` shader (`shaders/mp_desaturation.gdshader`) | Compatibility-safe |
| Audio | 268 `.wav` (~70 MB) + 1 `.mp3` via `sound_manager.gd` | Works; re-encode to OGG for download weight |
| Runtime perf risk | Per-frame per-pixel occlusion rebuild (`occlusion_renderer.gd:386-415`); startup recolors cached (`slime_visual_component.gd`, `player_animation_component.gd`) | Main thing to profile on weak devices; loading screen absorbs startup cost |
| Dependencies | No C#, GDExtension, autoloads, threads | Nothing blocks single-threaded export |

## 3. Platform facts that shape the plan

Researched 2026-08-26 (sources in §11):

- **Renderer**: Godot 4 web exports can only use the Compatibility
  (WebGL 2) renderer. Forward+/Mobile are unsupported. Safari has WebGL 2
  quirks but works; Chromium/Firefox are the reliable targets.
- **Threading and headers**: since Godot 4.3, a **single-threaded web export
  requires no special server headers** and runs on static hosts such as GitHub
  Pages with the best iOS/macOS compatibility. Threaded exports require
  `Cross-Origin-Opener-Policy: same-origin` +
  `Cross-Origin-Embedder-Policy: require-corp` on the top-level response. This
  project uses no threads, so the GitHub Pages deployment is explicitly
  single-threaded. If profiling ever justifies threads, move that build to a
  host where those headers can be controlled (or separately validate Godot's
  PWA workaround) rather than silently changing the Pages target. Trade-off:
  audio plays as Sample (not low-latency Stream) — fine for this game's
  SFX/music usage.
- **Gamepads on web**: a gamepad is invisible to the browser **until the
  player presses a button on it** (privacy restriction). Mapping quality
  varies by browser; Godot uses its own controller database on web (SDL
  covers only desktop), so per-browser testing is required. The Gamepad API
  is supported on iOS Safari 10.3+, Chrome/Firefox/Samsung Internet on
  Android, and all desktop browsers; recognized devices (Backbone included)
  are exposed with the standard Xbox-style mapping.
- **Touch**: `InputEventScreenTouch`/`InputEventScreenDrag` work in web
  exports. Gestures (`InputEventPanGesture`, `MagnifyGesture`, double-tap)
  are unreliable on mobile browsers — do not use them. Emulated mouse events
  from touch carry `device == -1` (`DEVICE_ID_EMULATION`), which lets the
  device classifier distinguish a real touch from its emulated echo.
- **Audio autoplay**: browsers unlock audio only after a user gesture. The
  title screen's first press covers this; no code change expected, but the
  manual checklist verifies no console autoplay warnings.
- **Fullscreen**: browsers allow entering fullscreen only from within an
  input-event callback (`_input`/`_unhandled_input`), never from polling.
- **Saves**: `user://` persists to IndexedDB. Writes flush asynchronously —
  a tab closed in the same instant as a save can lose it. Verify timing; add
  a flush-on-visibility-change later only if testing shows real loss.

## 4. Coexistence rules (the "still in development" contract)

These rules keep one codebase serving desktop and web without forking:

1. **No per-platform gameplay branches.** Platform differences live in
   project-settings platform overrides (e.g.
   `renderer/rendering_method.web="gl_compatibility"`) and Godot feature tags
   (`OS.has_feature("web")` is allowed only at the seams this plan defines:
   export/presentation glue, never gameplay math).
2. **Desktop behavior is the default.** Every web accommodation must be
   inert on desktop: touch UI hidden, device tracker passive, renderer
   override scoped to the web feature tag.
3. **All input flows through `InputRouter`.** New gameplay actions join the
   Input Map and the router snapshot; nothing new polls `Input` directly.
   Touch and gamepad support for any future feature then come for free.
4. **UI must remain operable without a pointer.** New menus/overlays use the
   existing focus-and-`pressed.emit()` pattern so keyboard, gamepad, and
   touch all reach them.
5. **The smoke suite stays the gate.** New web-related tests are registered
   in `tests/run_all_smoke.ps1` (hard-coded list — registration is a required
   step, not optional). A headless web export check joins the verification
   commands (§9).
6. **Performance budget awareness.** The occlusion rebuild
   (`occlusion_renderer.gd:386-415`) is the known hotspot; any new per-frame
   per-pixel work must be justified against weak mobile CPUs.

## 5. New components and ownership

Per the extension rules, behavior goes to the narrowest new owner; nothing
below enlarges `gameplay.gd` beyond orchestrator calls.

| Concern | Owner | Notes |
| --- | --- | --- |
| Last-input classification + `device_changed` signal | `scripts/input_device_tracker.gd` (new `Node`, created by `gameplay_bootstrap.gd`) | Uses its own `_input`; the only `_input` handler in the project |
| Touch state (virtual stick vector + button states) | `scripts/touch_controls_layer.gd` (new `CanvasLayer`) | Pure provider; renders its own UI |
| Merging touch state into the input snapshot | `scripts/input_router.gd` | Gains an optional typed `touch_provider`; merges after `Input` polling |
| Device-aware prompt labels | Existing HUD/dialogue builders + a small label helper on the tracker | Strings only; no glyph atlas this slice |
| Touch visibility + web presentation toggles | `touch_controls_layer` driven by the tracker's signal | Hidden unless last device is touch |
| Web export preset and platform overrides | `export_presets.cfg`, `project.godot` | Authored once, kept in repo |
| Audio re-encode pipeline | `tools/` script + `assets/sounds/` content change | WAV → OGG, one-time with re-run capability |

When these land, update `AGENTS.md` (ownership table) and
`docs/ARCHITECTURE.md` (scripts-by-responsibility) in the same commit.

## 6. Device auto-detect design

Device kinds: `KEYBOARD_MOUSE`, `GAMEPAD`, `TOUCH`.

`InputDeviceTracker` rules (the threshold detail is the documented trap in
this pattern — see §11):

- `InputEventKey` (pressed, not echo), `InputEventMouseButton`,
  `InputEventMouseMotion` → `KEYBOARD_MOUSE`.
- `InputEventJoypadButton` → `GAMEPAD`.
- `InputEventJoypadMotion` → `GAMEPAD` **only when `abs(axis_value) > 0.5`**.
  Resting sticks emit constant sub-deadzone motion events; without a
  deliberately conservative threshold the device flips to gamepad on frame
  one and never comes back. This 0.5 classifier threshold is intentionally
  stricter than any action deadzone.
- `InputEventScreenTouch` with `device != -1` → `TOUCH` (the emulated mouse
  echo of a tap arrives with `DEVICE_ID_EMULATION` and must not classify as
  mouse, or taps would bounce the device to `KEYBOARD_MOUSE`).
- Unclassified events leave the last device alone. State changes emit
  `device_changed(device)`; consumers subscribe instead of polling.
- First-frame default: `KEYBOARD_MOUSE` on desktop, `TOUCH` when
  `DisplayServer.is_touchscreen_available()` (and on web, when the browser
  reports a coarse pointer — acceptable heuristic: touchscreen availability).

Consumers in this slice:

- `touch_controls_layer` visibility (visible ⇔ last device is `TOUCH`).
- Control-prompt labels in HUD/interaction/dialogue text (e.g. "Press E" vs
  "Press Ⓑ" vs "Tap"). Implementation: the tracker exposes
  `prompt_label(action) -> String`; text builders ask it when composing.
  Plain-text labels only — a glyph atlas is later work.

## 7. Touch controls design

Layout (240×160 logical pixels, `CanvasLayer` so it follows stretch):

- **Left half**: virtual stick — touch-down sets origin, drag sets vector
  (clamped radius), release resets. Emits a normalized `Vector2`.
- **Right side**: buttons for `attack`, `roll`, `magic`, `guard`, `target`,
  `interact`. `pause` gets a small corner button. Sizes target ≥ 14×14
  logical px (≈ 56 px at 4× integer scale) with the existing palette art
  style.
- Buttons feed `Input.action_press`/`action_release` equivalents through the
  router merge; the stick provides the move vector. No gestures, no
  multitouch-dependent combos — each finger is tracked by its touch index.

Router merge (the only gameplay-adjacent change):

```text
InputRouter.poll():
    snapshot = Input.is_action_pressed(...)   # existing behavior
    if touch_provider != null and touch_provider.active:
        snapshot.merge(touch_provider.state())  # touch wins per-action
```

- `InputRouter` gains `set_touch_provider(provider)`; `gameplay_bootstrap`
  wires it. Desktop never sets a provider, so desktop behavior is provably
  unchanged (assert in tests).
- The layer only produces state while visible (i.e., while touch is the last
  device), which prevents stray emulated events from leaking into gameplay.

Menu/dialogue touch path: real `Button` nodes already receive taps via
Godot's default emulate-mouse-from-touch. Focus-driven flows (hub buttons
with `FOCUS_NONE`, `screen_state_controller.gd:533-591`) need a verify pass:
where a flow is focus-only, add tap-to-activate on the `Button` itself rather
than reworking navigation. Expected small; flagged as an explicit task.

## 8. Ordered implementation plan

One testable milestone per commit. Run
`pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1` before every
commit; register every new test file in `tests/run_all_smoke.ps1:5`.

### Phase 0 — Decisions (no code)

- Hosting target: **GitHub Pages** for the `Whynchu/TinyDemons` project site,
  with the stable URL `https://whynchu.github.io/TinyDemons/`.
- Publish the generated Web export through GitHub Actions' Pages artifact
  deployment. Do not commit `dist/`, generated `.wasm`, `.pck`, or HTML files
  to `main`, and do not maintain a separate `gh-pages` branch.
- Enable Pages with **GitHub Actions** as the source and use the repository's
  `github-pages` environment for deployment protection and status reporting.
- Keep this release single-threaded. GitHub Pages is the simple static target;
  threaded/COOP/COEP hosting is a separate future decision, not part of the
  first public web build.
- Confirm single-threaded export is the baseline for this slice.
- Confirm audio re-encode to OGG is accepted as a content change.

Exit condition: the Pages repository, deployment source, public URL, and
single-threaded policy are recorded with no hosting ambiguity remaining.

### Phase 1 — Web build baseline

- Add `renderer/rendering_method.web="gl_compatibility"` override; keep
  `mobile` for desktop. Verify desktop visuals unchanged (screenshot compare
  of the first room against `docs/game-screenshot.png` expectations).
- Author the real Web preset in `export_presets.cfg`: single-threaded, PWA
  off, `index.html` output, and the default HTML shell unless a custom shell
  is required by the loading screen. Install matching export templates (the
  Godot 4.7.1 single-threaded release file is `web_nothreads_release.zip`).
- Add `.github/workflows/web-pages.yml`. On `pull_request`, it checks out the
  repository, installs a pinned Godot 4.7.x editor plus Web export template,
  runs the headless export into `dist/`, and uploads the build as a CI
  artifact without deploying. On `push` to `main` and `workflow_dispatch`,
  the same build uploads a GitHub Pages artifact and a dependent deploy job
  publishes it to the `github-pages` environment.
- Give only the deploy job `contents: read`, `pages: write`, and
  `id-token: write`; keep the deployment job dependent on the build job and
  expose the Pages URL as the deployment output.
- Use the official Pages action sequence: `configure-pages`,
  `upload-pages-artifact`, then `deploy-pages`. Keep action versions pinned
  and review them as part of dependency maintenance.
- Ensure all generated asset references are relative to `index.html`; test
  from the repository project path `/TinyDemons/`, not only from `/`, so the
  `.wasm`, `.pck`, audio, and imported asset requests cannot accidentally
  point at the domain root. Add `.nojekyll` to the artifact if the export
  contains paths that could otherwise be interpreted by a static-site build.
- Export and run in Chrome desktop and Firefox; fix only true blockers.
- Add `tests/web_export_smoke.ps1` (or extend the smoke runner) performing a
  headless web export (`--headless --export-release "Web" <dir>`), checking
  that `index.html`, the `.wasm`, and the `.pck` exist, so a broken preset
  fails fast. Register it. The Pages workflow must call the same export
  command used by this check.

Exit condition: a web build loads at the GitHub Pages project URL, reaches the
title screen, and starts a run controlled by keyboard in two desktop browsers;
the same artifact passes the headless export check.

### Phase 2 — Last-input device detection

- Add `input_device_tracker.gd` per §6; wire in `gameplay_bootstrap`.
- New `tests/input_device_tracker_smoke.gd`: classifier unit coverage —
  joypad motion below 0.5 ignored, emulated touch echo (`device == -1`) does
  not classify as mouse, real touch classifies as TOUCH, signal fires only on
  change, desktop default is `KEYBOARD_MOUSE`.
- Add `prompt_label(action)` and route existing control-hint strings through
  it (interact prompt, NPC tutorial text such as the hub attunement hint in
  `npc_controller.gd:92-94`, pause/controls listing).
- Verify prompt swap live on desktop: keyboard ↔ gamepad.

Exit condition: prompts follow the last device on desktop with zero gameplay
behavior change; touch layer not yet present.

### Phase 3 — Touch controls

- Add `touch_controls_layer.gd` per §7 (stick + six buttons + pause), its
  state provider, and the `InputRouter` merge. Wire visibility to the
  tracker.
- New `tests/touch_controls_smoke.gd`: stick vector math (origin, clamp,
  release), button press/release state reaches the router snapshot, provider
  inert when hidden, desktop poll snapshot identical with no provider.
- Menu/dialogue tap audit: verify every overlay (title, hub, dialogue,
  pause, settlement) is completable by taps; add tap-to-activate only where
  focus-only flows block it.
- Device-check on a phone browser: touch UI appears on first tap, hides when
  a gamepad button is pressed, reappears on next tap.

Exit condition: the full loop — title → hub → dive → combat → chest →
settlement — is completable touch-only in Chrome Android/Safari iOS.

### Phase 4 — Web hardening and performance

- Re-encode `assets/sounds/*.wav` → OGG via a repeatable `tools/` script;
  keep sources in `Artwork/`/sfx folders as the masters. Update
  `sound_manager.gd` loading if extensions are referenced literally.
- Profile crowded-room frame time on a mid-range phone; if the occlusion
  rebuild dominates, add a `web`/quality fallback (e.g. half-rate rebuilds or
  simpler occluded shading) behind the feature tag.
- Verify save persistence across reloads, including save-then-close timing;
  document the outcome in this file.
- Confirm the audio-unlock gesture path is silent in console logs; add a
  fullscreen button triggered from an input-event callback if wanted.
- Measure first-load weight after OGG; record the number here.

Implementation note: `tools/convert_audio_to_ogg.ps1` is repeatable and keeps
WAV masters by default. The Pages workflow runs it against its ephemeral
checkout with `-DeleteWavSources`, and `SoundManager` prefers a same-name OGG
when present while retaining the WAV fallback for desktop development.

Exit condition: stable frame rate in multi-slime rooms on a mid-range phone;
saves survive reloads; no console warnings on the happy path.

### Phase 5 — Gamepad-on-web validation (Backbone and peers)

- Test matrix: Chrome desktop, Firefox desktop, Chrome Android, Safari iOS;
  devices: Xbox-class, PlayStation-class, Backbone One on phone.
- Verify: detection-after-first-press expectation is handled (a "press any
  controller button" affordance in the title/pause UI if the matrix shows
  confusion), triggers/stick/D-pad behave, no double-input with touch layer
  hidden.
- Document any browser-specific mapping failures in this file with a
  "try a different browser" fallback note for players.

Exit condition: the matrix is filled in; Backbone on a phone browser plays
the full loop with prompts swapping to gamepad.

### Phase 6 — Documentation and guardrails

- Update `README.md` (controls + web build section), `AGENTS.md` (ownership
  table: tracker, touch layer), `ARCHITECTURE.md` (scripts list),
  `GAMEPLAY_TUNING.md` (any new tuning exports).
- Add the GitHub Pages URL and the `web-pages.yml` release/deployment command
  to `README.md`; document that PRs build without publishing and only `main`
  updates the public game.
- Add the manual web checklist (browsers × devices) to
  `gameplay-smoke-checklist.md` or as its own section here.
- Record final decisions and measurements in §11.

## 9. Verification checklist

### Automated (per commit)

- `tests/run_all_smoke.ps1` green, including new tracker/touch tests.
- Headless web export succeeds (Phase 1 check).
- The GitHub Actions Pages build succeeds on a pull request without deploying.
- A `main` or manual Pages workflow run publishes the same artifact and
  reports the project URL from the `github-pages` environment.
- Desktop: no behavioral diff when no touch provider is wired (router test).
- Renderer override does not alter desktop rendering (visual spot-check).

### Manual web checklist (per release)

- Open `https://whynchu.github.io/TinyDemons/` from a clean browser profile;
  verify the project-path URL loads every generated asset.
- Chrome desktop: keyboard play; plug in gamepad mid-run, prompts swap.
- Firefox desktop: title → dive → first combat.
- Chrome Android: touch-only full loop; Backbone attached → touch UI hides,
  gamepad prompts show; unplug → touch returns on next tap.
- Safari iOS: same loop; note any WebGL/audio warnings.
- Reload mid-run: profile persists.
- First load on hotel-class Wi-Fi: loading completes; record total payload.

## 10. Risks and mitigations

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Project Pages subpath breaks generated asset URLs | Medium | Require relative export references and test the exact `/TinyDemons/` URL in the workflow/release checklist |
| Occlusion per-pixel rebuild too slow on phones | Medium | Phase 4 profiling; quality fallback behind `web` feature tag |
| Gamepad mapping wrong in some browser | Medium | Test matrix (Phase 5); standard-mapping devices (Backbone/Xbox/PS) first; document fallback |
| Gamepad invisible until first button press | Certain (platform rule) | "Press a controller button" affordance; prompt defaults to touch/keyboard until then |
| 70 MB WAV first load | Certain unless addressed | OGG re-encode (Phase 4); measure and record |
| IndexedDB save lost on instant tab-close | Low | Verify timing; flush-on-hide only if observed |
| Emulated mouse echo misclassifies touch as mouse | Certain if unhandled | Ignore emulated mouse plus active/recent touch echoes in the classifier; covered by tests |
| Joypad drift flips device to gamepad | Certain if unhandled | 0.5 classifier threshold; covered by tests |
| Focus-only menus untappable | Medium | Phase 3 tap audit; tap-to-activate on the Button, no navigation rework |
| Safari WebGL2 quirks | Low-Medium | Single-threaded export (best iOS compat); test early in Phase 1 |
| Future threaded export needs COOP/COEP headers that the simple GitHub Pages path does not provide | Medium | Keep Pages single-threaded; use a header-configurable host if threads become necessary |

## 11. Research verification log

### Codebase audit (2026-08-26)

Full audit of `project.godot`, `scripts/` (95 files), `export_presets.cfg`,
`shaders/`, `assets/sounds/`: the summary table in §2 reflects its findings.
Key evidence: renderer `project.godot:109`; input map `project.godot:26-103`;
single poll seam `gameplay.gd:81` + `input_router.gd:19-28`; no `_input`
handlers, no mouse/touch usage in `scripts/`; saves `user://`-only
(`profile_save_service.gd:4-7`); occlusion hotspot
`occlusion_renderer.gd:386-415`; startup recolors cached
(`slime_visual_component.gd:38-48,121-133`,
`actor_presentation_runtime_controller.gd:64-106`); ~70 MB WAV under
`assets/sounds/`; single simple shader `shaders/mp_desaturation.gdshader`.

### Platform research (2026-08-26)

- [Godot docs, *Exporting for the Web*](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): Compatibility renderer only;
  single-threaded export since 4.3 without COOP/COEP; threaded requires
  `Cross-Origin-Opener-Policy: same-origin` +
  `Cross-Origin-Embedder-Policy: require-corp` (PWA service-worker workaround
  for header-less hosts); gamepads undetectable until first button press;
  fullscreen only from input-event callbacks; Safari WebGL 2 caveats. The
  single-threaded mode is the reason GitHub Pages is suitable for this port.
- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages): Pages deployments use
  `configure-pages`, `upload-pages-artifact`, and `deploy-pages`; the deploy
  job needs `pages: write` and `id-token: write`, should depend on the build
  job, and uses the `github-pages` environment. This is the selected hosting
  path for `Whynchu/TinyDemons`.
- Godot docs, *Controllers, gamepads, and joysticks*: SDL 3 covers desktop;
  web/mobile use Godot's own controller code — "less reliable", varies by
  browser; SDL for web planned later.
- MDN / W3C Gamepad API: baseline widely available (≈96% global); standard
  Xbox-style mapping for recognized devices; `mapping == "standard"` check;
  secure-context and user-gesture requirements in Chrome.
- Backbone product documentation: Backbone One (USB-C) supports iPhone iOS 15+
  and Android 10+ and works with any controller-compatible content — on the
  web that means it arrives as a standard Gamepad API device.
- Godot `InputEvent` docs: `DEVICE_ID_EMULATION = -1` distinguishes emulated
  mouse-from-touch events; `Input.parse_input_event` exists for synthetic
  injection (not needed — the router merge is cleaner).
- Established last-input-device pattern (independent write-ups): classify the
  event stream once, ignore `InputEventJoypadMotion` below a conservative
  threshold (0.5), emit a change signal, consumers subscribe — matches §6.
- Godot forum/issue history: mobile-browser gesture events (pan/magnify/
  double-tap) unreliable → excluded from scope; basic touch and multitouch
  drags work.

### Open items to record here as implementation lands

- Confirmed Pages URL and workflow definition; a hosted workflow run and the
  real public browser matrix remain release checks. Whether a separate
  threaded host is ever needed remains a future performance decision.
- The local Windows checkout does not currently have the Godot 4.7.1 Web
  template installed, so the export smoke reports a deliberate skip locally;
  CI installs `web_nothreads_release.zip` and treats export failure as fatal.
- Post-OGG payload size and crowded-room phone frame times.
- Per-browser gamepad mapping failures (if any) and player-facing guidance.

### Landed since the plan (2026-08-26, phone sizing pass)

- **Integer content scaling** (`window/stretch/scale_mode="integer"` in
  `project.godot`) fixes the nearest-neighbor tile seams seen at fractional
  phone scales; the engine now letterboxes and centers the 240x160 content on
  every platform. Desktop's 960x640 window is exactly 4x, so it is unchanged;
  free desktop resizing to non-multiples may now show thin bars. On hiDPI
  phones (DPR >= 2) portrait typically lands on a 3x integer scale, so the
  game still fills most of the screen width.
- **Mobile page CSS** is injected through the Web preset's
  `html/head_include` (fixed positioning, `overflow: hidden`,
  `touch-action: none`, `user-scalable=no`, `overscroll-behavior: none`) so
  URL-bar bounce, page scroll, and double-tap zoom cannot shift the canvas or
  hijack control drags.
- **`touch_controls_layer.gd` adaptive layout**: the overlay lays out all
  gameplay targets in logical viewport space, so visuals and
  `InputEventScreenTouch` hit positions stay aligned through integer scaling
  and letterboxing. The stick anchors where the finger lands; buttons release
  on slide-off. Menu and dialogue touches are handled separately: visible
  native `Button` nodes activate on a screen-touch tap, while dialogue and
  focus-based menus retain a tap-to-accept fallback. Layout and menu hit
  testing are asserted in `tests/touch_controls_smoke.gd`.
- **Touch-device handoff protection**: `input_device_tracker.gd` tracks active
  screen touches and a short post-release grace window, filtering browser
  mouse-motion echoes even when a platform labels them as a physical mouse.
  This prevents the virtual stick from being cleared mid-drag and keeps touch
  prompts visible. The behavior is covered in
  `tests/input_device_tracker_smoke.gd`.
