# Tiny Demons Gameplay Smoke Checklist

Purpose: establish a repeatable behavior baseline before extracting gameplay
components. Run this checklist against the current branch before and after each
consolidation milestone.

The checklist covers the landed runtime baseline, including six-slot Head/Arm
coverage, Body migration, catalogue source rules, and effect read-model tests.
The focused catalogue tests are also included by `tests/run_all_smoke.ps1`.

> Active gameplay balance changes (gear value, base stats 3/2/2, enemy/boss
> difficulty) are tracked in
> [`combat-economy-overhaul.md`](combat-economy-overhaul.md). Update the
> expected results below whenever that overhaul changes a stat or difficulty
> knob.

Baseline reference: `main` at `15a2832`

Consolidation branch: `agent/script-consolidation`

Current behavior checkpoint: `84e7a61`

## Test environment

- Date:
- Commit tested:
- Platform:
- Display scale/window mode:
- Input device: keyboard / controller
- Tester:
- Godot version:

Record a short note or capture for any failed or noticeably changed behavior.
The goal is behavior parity, not subjective perfection of timing or visuals.

## Startup and menus

### M0-01 Title screen

- [ ] Launch the main scene.
- [ ] Title screen appears without errors or visible construction artifacts.
- [ ] Start button is visible and its retro bob is stable.
- [ ] Pressing start transitions to archetype selection.
- [ ] Title text/button breakup particles rise vertically with varied upward
  speeds and fade out.

Expected result: no input is lost, the transition completes once, and no title
particle remains after its lifetime.

### M0-02 Archetype selection

- [ ] Move between archetype choices with keyboard.
- [ ] Move between archetype choices with controller, if available.
- [ ] Change palette/type selection.
- [ ] Confirm a selection and reach the playable room.

Expected result: selection highlight, preview, and transition remain aligned;
the selected palette is applied to the player.

## Player and combat

### M0-03 Movement and collision

- [ ] Move horizontally and vertically through the start room.
- [ ] Test diagonal/isometric movement.
- [ ] Push against the room boundary and static guides.
- [ ] Walk through each available doorway/entrance trigger.

Expected result: the player remains within walkable geometry, movement uses the
configured controller deadzone, and no position jump occurs at boundaries.

### M0-04 Roll

- [ ] Roll in each cardinal and diagonal input direction.
- [ ] Confirm roll distance and duration are consistent.
- [ ] Roll against static geometry and actors.
- [ ] Confirm roll dust appears once per roll and follows the player direction.

Expected result: roll input cannot create a second roll while locked, collision
does not tunnel the player through walls, and dust does not duplicate.

### M0-05 Player attacks and damage

- [ ] Perform attack 1 facing both directions.
- [ ] Buffer attack 2 inside and outside the combo window.
- [ ] Confirm attack lunge and hitbox direction.
- [ ] Complete a fast circular stick gesture and confirm Spin Attack starts on
      the next Attack press.
- [ ] Select `SpinAttackHitboxShape` in Godot, preview frames 0–7, and edit
      `HitboxFrame0`–`HitboxFrame7` independently.
- [ ] Hold Attack through Attack 1, confirm the charge pose, then release after
      the threshold and confirm the stronger/slower charged Attack 2.
- [ ] Hit a slime and observe damage number/flash/knockback.
- [ ] Receive a slime hit and observe hit flash, hit-stop, knockback, and stun.

Expected result: hit timing, combo buffering, critical presentation, knockback,
and hit-stop remain consistent with the current checkpoint.

### M0-06 Health and healing bars

- [ ] Take damage to the player and each visible slime.
- [ ] Observe the darker current fill and brighter trailing loss.
- [ ] Stand safely in the start room until player regeneration begins.
- [ ] Repeat healing in a rest/fire room.
- [ ] Observe the brighter leading gain and slower darker catch-up fill.
- [ ] Check the targeted enemy bar and every overhead enemy bar.

Expected result: all health bars use the same damage/healing inversion, delayed
fills do not jump backward, and health text matches logical health.

## Rooms and interactions

### M0-07 Chest and reward

- [ ] Clear a combat room.
- [ ] Confirm the chest unlocks and interaction prompt appears.
- [ ] Collect the chest reward once.
- [ ] Confirm chest particles, flash, evaporation, gold count, and prompt state.

Expected result: reward cannot be collected twice and the exit state updates.

### M0-08 NPC dialogue

- [ ] Enter the start/NPC room and approach the cloaked demon.
- [ ] Trigger dialogue and observe typewriter text.
- [ ] Confirm the continue circle appears only after text completes.
- [ ] Confirm its slow half-pixel bob, one-pixel total range, and shadow alignment.
- [ ] Advance dialogue and confirm the player remains input-locked while active.

Expected result: the dialogue box, text, shadow, and circle render in the order
box → text → shadow → button, with the button visibly in front.

### M0-09 Dungeon traversal and persistence

- [ ] Enter each available door/entrance socket direction.
- [ ] Revisit a previous room.
- [ ] Confirm cleared rooms, chest state, enemy state, and player arrival
  position persist as expected.
- [ ] Confirm room number/type indicators update.

Expected result: traversal is deterministic and no socket leaves the player
locked or in invalid walkable geometry.

## Death and recovery

### M0-10 Player death and restart

- [ ] Reduce player health to zero.
- [ ] Observe hit reaction, death particles, fade, and game-over screen.
- [ ] Confirm enemies and UI settle during the death sequence.
- [ ] Restart the scene.
- [ ] Return to title and start another run.

Expected result: death occurs once, particles clean up, restart restores initial
state, and title/start flow remains usable after a prior death.

## Rendering and presentation

### M0-11 Visual systems

- [ ] Check depth sorting while actors cross in front of/behind objects.
- [ ] Check player and NPC shadows.
- [ ] Check actor occlusion against walls/occluders.
- [ ] Check slime directional frames and attack frames.
- [ ] Check pixel snapping and absence of unwanted subpixel shimmer.

Expected result: visual effects remain aligned with their owning actor and no
new effect appears above the intended UI/world layer.

## Web port release checks

Run `pwsh -ExecutionPolicy Bypass -File tests/web_export_smoke.ps1 -RequireExport`
with the matching Web template installed before a Pages
release. The GitHub Actions workflow runs the same check for every pull
request and deploys only from `main`.

- [ ] Open `https://whynchu.github.io/TinyDemons/` from a clean browser profile.
- [ ] Chrome desktop: keyboard play, then connect a gamepad and confirm prompts swap.
- [ ] Firefox desktop: title → dive → first combat with keyboard.
- [ ] Chrome Android: touch-only title → hub → dive → combat → settlement loop.
- [ ] Safari iOS: repeat the touch loop and record any WebGL/audio warnings.
- [ ] Touch controls appear after touch input and disappear after a gamepad or keyboard event.
- [ ] Reload mid-run and confirm the profile persists.

## Results

| Test | Result | Evidence/notes |
| --- | --- | --- |
| M0-01 Title | Not run | |
| M0-02 Archetype | Not run | |
| M0-03 Movement | Not run | |
| M0-04 Roll | Not run | |
| M0-05 Combat | Not run | |
| M0-06 Health bars | Not run | |
| M0-07 Chest | Not run | |
| M0-08 Dialogue | Not run | |
| M0-09 Rooms | Not run | |
| M0-10 Death | Not run | |
| M0-11 Rendering | Not run | |

## Automated checks

- `git diff --check`: available and required for each change.
- Godot headless validation: available (v4.7.1 console build). Command:
  ```
  & "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Development\Tiny-Demons\TinyDemons"
  ```
- Headless main-scene load (`--quit-after 30`): passes with no script/runtime errors.
- Automated smoke tests (all exit 0):
  - `-s res://tests/run_grade_smoke.gd` -> `RUN_GRADE_SMOKE_OK`
  - `-s res://tests/progression_smoke.gd` -> `PROGRESSION_SMOKE_OK`
  - `-s res://tests/item_economy_smoke.gd` -> `ITEM_ECONOMY_SMOKE_OK`
- One-shot runner (all three + main-scene headless check):
  `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`
- Smoke tests use a watchdog: if any assertion fails mid-script the process
  aborts with a `TEST_ABORTED` error and exit code 1 instead of hanging.
- Post-overhaul expectations: player base 3/2/2 (archetypes sum to 7), gear
  primary stats 25%/point with a 1-point floor, enhancement +0.1 tier-stat
  point/level (+1.0 at +10), and
  enemies `max(1, ceil(depth/4))` (cap `999 if rank>10 else 2+rank`, +rank-8
bonus from R9+).
- Fusion (target-centric) expectations: FUSE tab lists upgrade targets (any
  item with capacity + an eligible unequipped material, plus mythic +10
  overflow), targets may be equipped, materials must be unequipped and share
  definition + rarity, batch count is set with left/right, cost starts at 1
  Soul for common +0->+1 and rises by 1 per enhancement tier, with each
  rarity adding 10 Souls (common +10->rare costs 10; rare +0->+1 costs 11),
  and insufficient Souls shows `NEED nS` with the action disabled.
