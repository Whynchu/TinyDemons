# codex — status

_Only codex writes this file._

**Focus:** Spell delivery, elemental impact effects, and mobile-web release 0.3.25 — implementation complete
**Updated:** 2026-10-01

## Completed

Triangle keeps its elemental form at low Chroma, rejects casts below cost, and
can spend exactly to zero. Water now travels before it collides, deals full form
damage to its primary target, and reduced damage to nearby splash targets. Its
droplet projectile and the Shadow hex projectile have element-specific shapes.
Each elemental payload emits a different pixel impact profile; the spell plan
and gameplay tuning guide document source behavior and open runtime acceptance.

Offline GDScript diagnostics, `git diff --check`, and the strict composition
audit pass. No Godot process or test suite was launched due the session
restriction. Release metadata is aligned at 0.3.25; mobile-web playtest remains
the next acceptance step.


Static hookup audit is complete. All eight Triangle forms trace from Chroma acceptance through the cast frame to delivery and hit effects. Fixed puzzle-object routing, pointer-aim target resolution for Skyfall and Leechvine, and debug-unlimited form-cost selection.

Offline GDScript diagnostics and git diff --check pass. Runtime playtest and balance/readability acceptance remain open; no Godot process or suite was launched.

The elemental spell-form track was handed off from opencode after P3. P4–P7
source implementation is complete: each form has its delivery, first-pass
cost/cooldown and damage values, and its planned status, knockback, tether,
lifesteal, or mark behavior. Runtime balance/readability acceptance remains
open. Whether Grass should remain status-free is unratified; the catalog has no
Grass status definition, but the status authority does not explicitly classify
Grass as status-free. Do not launch Godot or the test suite in this session; use
static checks only.

The user approved the first generic room-prefab runtime slice. A typed prefab
definition, factory, host, and mount result are connected to initial room setup,
ordinary transitions, and active-run restore. Legacy room roles map explicitly
to `basic`; room identity and state stay in their existing owners. Static shell,
socket, geometry, accent, and Orb presentation references were audited and
rebound where needed. Source and documentation review is in progress; no Godot
runtime or test suite has been launched.

Two user-reported runtime errors in this source pass were corrected: HUD status
marker registration no longer casts a stored Array to `Array[Sprite2D]`, and
`PlayerAnimationContext` now declares and receives the death-state callback.
Offline MCP script diagnostics pass for the corrected HUD, aura/context owners,
animation component, setup owners, and death visibility check. No game or test
suite was launched. The transient magenta rectangle has no capture or confirmed
source cause and remains open; the death/cloak appearance also needs runtime
acceptance.

Version 0.3.16 updates the web README and in-game title. This release includes
the current M1 source work plus the Fusion comparison, healing visibility, and
completed-run gear progression changes. M1 editor/export acceptance remains
open and no Godot process or test suite was run for this release.

Post-release report: heals stopped resolving and the healer animation looked
wrong. The connected editor log showed zero frames from both authored healer
sheets; those two PNGs were the only artwork files missing `.import` metadata.
They now have import metadata and static dependencies. Empty animation sets
fall back to actor frames, release timing waits through heal impact, and the
healer arc endpoint crosshair is removed. MCP script diagnostics pass for the
three changed scripts; no gameplay or test suite was run. Web playtest evidence
remains open.

Follow-up player feedback: the generated healing plus glyphs looked poor. The
burst now uses crisp outlined crosses, smaller sparkle accents, integer pixel
scaling, and a tighter controlled rise instead of repeating large crosses with
fractional scales and noisy spread. Runtime visual acceptance remains open;
the Godot process restriction still applies.

This M1 step closes the enemy registry validator's duplicate-ID blind spot:
the catalog now validates every distinct embedded and standalone source before
runtime lookup deduplicates by stable ID, and duplicate diagnostics name both
paths. The authoring dock exposes the same catalog check as `Validate Enemies`
and labels placement-only validation `Validate Scene`. Offline `script_check`
and `git diff --check` pass. No tests or Godot runtime checks were run.

The deterministic manifest service, CLI, dock refresh, generated all-resource
and kind-specific manifests, and preflight integration are in place locally.
Offline GDScript and PowerShell parser checks pass; a static comparison confirms
the checked-in manifests cover all 28 resources. Godot-side generation,
preflight execution, and lifecycle/export proof remain open. No Godot process
may be launched in this session.

The 2026-09-28 follow-up audit found that Fusion inherited Shop's `EQUIP`/`ITEM`
labels at y=46 despite Fusion's stat rows beginning at y=41, and compared the
pre-fusion item against its projected upgrade. The Fusion/healer interlude is
now implemented locally. Fusion uses Shop's
equipped-piece versus selected-item comparison (with mastery bonuses and the
same value colors) and moves both headers to y=33 above Fusion's y=41 stat rows.
Healing uses a cached 9x9 high-contrast pixel plus and leaves the 3x5 text glyph
untouched. `KNOWN_ISSUES.md`, the menu presentation contract, tuning index, and
healer plan now record the findings and current source behavior. Offline
`script_check` passes for the three changed scripts and `git diff --check`
passes. No tests or Godot runtime checks were run.

Gear rewards now add progression from saved `completed_runs` only; current-run
room depth does not enter the new curves. Chests use the previous clear count,
while clear rewards include the run being completed. Chest chance and extra-item
thresholds progress to their 20-run cap; clear chance adds 0.25 percentage
points per completed run and can reach 100% at maximum score after 20 runs;
rarity adds 0.005 total rare-or-better probability per run, capped at 0.10.
Offline script diagnostics pass for RewardDefinition, ItemCatalog, and
RunFlowController; all 37 exported reward fields have explicit `.tres` values,
and `git diff --check` passes. No tests or Godot runtime checks were run.
No Godot process may be launched in this session.

Enemy and item runtime discovery now filters typed resources from separate
generated manifests, so each catalog loads only its own authored resource set.
The kind manifests are static export dependencies; editor loads replace each
cached manifest after refresh. The dock coalesces save, reimport, and filesystem
change events, then invalidates enemy and item definition caches. Offline
diagnostics pass for the plugin, dock, both catalog data scripts, and manifest
service; static comparison confirms 28 resources, 10 standalone enemies, and 2
items. Exported loading and create/move/delete acceptance remain open.

## Blockers

Do not launch another Godot process in this session after the recorded startup
stall and standalone crash. The authoring-dock and PreviewSession contract
smokes, editor save/reimport/undo behavior, isolated profile/settings behavior,
and rendered acceptance remain unverified.

Preserve the existing `.mcp.json` and `docs/timed-floor-hazard-plan.md`
changes. Do not stage them with M1.

## Handoff / next

Version 0.3.25 is prepared for mobile-web playtesting. Runtime visual and balance
acceptance for each Triangle form remains open. Do not launch another Godot
process or test suite in this session.

## Current work

Source wiring registers `basic`, `orb`, `treasure`, and `boss` room
definitions. Role capabilities are checked during mount; Orb and Treasure use
validated stable markers, boss geometry is authored in its own scene, and old
all-basic active-run assignments migrate by room role. The boss copy adapter
remains for debug/prewarm compatibility. I left the active elemental spell-form
files untouched under the opencode claim. Runtime, traversal, recovery, export,
and authoring-workbench acceptance remain open under the no-Godot restriction.

The gear-volume and Fusion-growth follow-up is implemented in source. Chest
frequency remains unchanged; standard/risk chests drop gear more often,
multi-item thresholds are higher, run-clear drops have a higher floor, and a
vault grants two items. Completed-run progression remains completed-runs-only.
Every positive authored/random attribute and every positive shield-guard line
improves through Fusion; negative tradeoffs stay fixed. Focused offline MCP
script diagnostics and `git diff --check` pass; no tests or runtime were run.

The playtest rendering follow-up is also implemented in source: HUD marker
arrays and cached sprites are checked before casts, status and imbue overlays
copy the actor's global transform, and both outlines and status-particle source
pixels crop the displayed atlas, region, or animation-sheet frame. Burn uses
the imbue-like upward ember trail; Poison, Stun, and Slow use distinct styles.
Focused offline MCP script diagnostics pass. Visual alignment, readability,
death/cloak behavior, and the uncaptured magenta artifact remain open for a
color playtest. Do not launch a Godot process in this session.

## 2026-09-30 — Elemental spell-form continuation

Opencode handed off the spell-form paths after implementing P3 Electric Skyfall.
P1–P3 runtime acceptance remains open. Codex is implementing P4 Water Tide
Burst, P5 Fire Cinder Cone, P6 Ground Quake / Ice Shard / Grass Leechvine /
Shadow Hex, and P7 tuning/presentation updates. No Godot process or tests may
run in this session; update the plan only to reflect source evidence and leave
runtime acceptance pending.

Version metadata is aligned at 0.3.20 for the in-game title, web README, and
release references. The web Compatibility renderer override is retained. The
release excludes the local `.mcp.json` configuration and timed-floor design
edits. Focused diagnostics were already run for the source changes; no runtime
or test suite was run for this release.

The post-release composition failure came from 26 new dynamic root accesses in
status integration and a 20-line `GameplayState` growth. Status paths now use
typed runtime access, the two status forwarding wrappers are removed, and
player status marks update through `HudController`. Both regression-floor and
strict composition audits pass: 2,202 root accesses and 1,717 `GameplayState`
lines / 286 fields. MCP script checks were unavailable (`DISCONNECTED`); no
Godot process was launched due the recorded session restriction.

The post-release death-outline and room-lock reports are addressed in source.
`ElementAuraComponent` now clears status records, outline overlays, and particle
timers on `HealthComponent.died`; room-pool cleanup clears them as well, and
status application rejects dead health/combat components. Regular combat-room
clear detection now checks only the configured `enemy_variants` slots instead
of every pooled slime. The user confirmed a regular combat room with an
immediate lock. Spawn placement validates both the sprite collision polygon
and its collision guide against the walkable area, so static review found no
unvalidated initial spawn path; a live reproduction is still needed to rule
out an in-bounds slot later moving out of bounds. `git diff --check` passes.
No tests or Godot runtime checks were run under the session restriction.

The 0.3.21 root-access regression came from three dynamic reads in the new
regular-room clear check. `CombatRuntimeController.are_all_slimes_dead` now
uses typed `GameplayState` references, preserving the configured-slot behavior
while reducing the measured count to 2,201. Both the regression-floor and
strict composition audits pass, and version metadata is aligned at 0.3.22 for
the corrective main push. Only the composition audits and `git diff --check`
were run; no Godot runtime or gameplay suite was launched.

Release 0.3.21 carries the actor-death status cleanup, dead-actor status
application guard, and regular-room configured-slot clear check. The web README,
in-game title, versioning guide, contributor guide, and roadmap are aligned.
`origin/main` matched the local 0.3.20 release before publishing. No Godot
runtime or test suite was run; the configured off-floor actor case still needs
playtest confirmation.

## 2026-09-28 — Player status presentation

The player's status outline and status particles now follow the separate attack
sprite while it is visible, then return to the base sprite. Status badges render
in a dedicated row below the player HUD and above the minimap; the minimap is
shifted down to leave that row clear. Release metadata is aligned at 0.3.23.
MCP offline script diagnostics pass for all four changed gameplay scripts, and
the editor had no new errors at release. The player later confirmed the status
outline and HUD placement looked good in playtesting.

The player confirmed the 0.3.23 status outline and HUD placement looked good in
playtesting, then reported that enemy preview looping was inconsistent and
asked to include the death breakup with other preview states. The selected-state
loop setting now applies uniformly, including to Death Effect. The separate
Inspector button restores the selected animation's pause/finished state after
the breakup. GDScript diagnostics pass and the editor has no new errors; no
interactive runtime preview was run.

The player accepted the room-prefab direction. The source audit found that
normal transitions mutate Main's shared Map shell, bind four fixed edge sockets
once at bootstrap, and apply per-instance state from RoomController.room_states.
The authoring plan and roadmap now specify separate room-instance, gameplay-role,
and prefab identities; a host/factory binding boundary; legacy assignment
recovery; and generic-room, treasure-room, Orb/puzzle, and boss parity stages.
No runtime files changed or tests launched; `git diff --check` passes.

The user approved moving into the generic room-prefab runtime slice. I have
added a typed definition/factory/host boundary and integrated it before
walkability, socket, and room-state activation. The legacy shell stays as a
fallback until a mount succeeds. No Godot process or test suite may be launched
in this session; static review only.

## 2026-09-29 — Generic room-prefab runtime slice

Mounted `basic` before room activation and on ordinary route entry. Run
checkpoints retain resolved prefab assignments; older snapshots continue
through the explicit room-role compatibility mapping. Successful mounts rebind
floor tiles, sockets, geometry, puzzle surfaces, and Hub-stone constraints,
then hide the old static shell. The static manifest comparison covers 29
resources, all 227 script UIDs are unique, `GameplayState` remains at 1,718
lines, `RoomController` is at 2,294 lines, and `git diff --check` passes. The
offline MCP parser's local class cache does not contain the new global script
classes, so it cannot provide a clean compile result without refreshing that
cache. Runtime, traversal, recovery, and exported-build acceptance remain
open; no Godot process or test suite was launched.

## 2026-09-30 — Elemental spell forms P4–P7

Completed the typed delivery paths for Water splash, Fire cone, Electric
Skyfall, Grass Leechvine, Shadow Hex, Ground Quake, and the Ice shard, with the
neutral stub retained as the low-Chroma fallback. Dynamic form costs and
cooldowns now use the selected definition; target-only forms reject casts when
their target is missing or outside Leechvine range. Hex marks only living
targets, and Leechvine removes its tether on a killing tick. The spell plan and
tuning index record the provisional source defaults and keep M1-authored
definitions plus runtime tuning/readability acceptance open. Offline diagnostics
pass for 11 changed scripts; `gameplay_state.gd:391` retains the previously
noted class-cache diagnostic. `git diff --check` passes. No Godot process or
test suite was launched.
