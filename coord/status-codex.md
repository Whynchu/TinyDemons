# codex â€” status

_Only codex writes this file._

**Focus:** Stage 3.1 legacy Hub item data/render and scroll boundary mapping
**Updated:** 2026-10-04

## Completed: MCP startup-error repair and runtime verification

Fixed the Settings overlay argument order and HubFlow fusion-cache calls that
prevented dependent scripts from compiling. Updated two smoke-test scripts to
match the typed status API and explicitly type a dynamic room-entry result.
MCP file checks pass for both gameplay scripts, the two test scripts, and the
slime/status runtime controllers. The main scene launched through MCP and is
currently in active room combat; the editor error buffer is empty and the game
log contains only runtime-server startup messages. No smoke suite was run.

The whole-project LSP diagnostic tool was advertised by discovery but is not
callable through this MCP bridge. Per-file checks of GameplayState also produce
false-positive self-type errors under the temporary `gdscript://` URI, so the
main-scene runtime launch is the project-level compile evidence for that path.

## Completed: Stage 2.5 combat status and feedback helpers

Moved the typed actor-status pipeline into `ActorStatusRuntimeController` and
damage/healing number presentation into `CombatFeedbackPresenter`. The combat
controller facade and existing GameplayState/actor/frame-schedule call sites
remain stable. Corrected the plan's stale boundaries and call-site count. The
composition audit passes at 241 scripts; Godot runtime verification remains
pending because this session has no editor diagnostics access and must not start
a second editor.

## Completed: Stage 3.1 title particles

Moved particle creation, cleanup, and frame updates into the 97-line
`TitleParticleController`. ScreenStateController remains the facade for
GameplayState. The composition regression audit passes with 242 scripts and
zero unclassified files; UID pairing is 242:242.

## Completed: Stage 3.1 menu widget factories

Moved the root-free shared menu widget and retro style methods into the
250-line `MenuWidgetFactory`. ScreenStateController retains its prior method
names; direct callers in GameplayState and CloudSavePanel still resolve. The
composition regression audit passes with 243 scripts and zero unclassified
files.

## Completed: Stage 3.1 cursor motion

Moved cursor positioning, movement, bob, and tween cleanup into the 61-line
`MenuCursorAnimator`. The ScreenStateController remains the tween owner, and
its public methods/constants stay available to SaveFlowController and menu
screens. Composition audit passes with 244 scripts and zero unclassified
files.

## Completed: Stage 3.1 positioning audit

Corrected the low-risk estimate: hub positioning is coupled to 81 screen-owned
fields (67 hub and 14 pause), so it needs a typed layout owner before moving.
The loading fade also owns cross-screen completion effects; extract its visual
work while keeping that transaction in ScreenStateController.

## Completed: Stage 3.1 loading presenter

Moved loading overlay construction, label animation, and fade visuals into the
30-line `LoadingScreenPresenter`, using `MenuWidgetFactory`. The existing
ScreenStateController build/update facade remains intact and owns the final
cross-screen overlay and gameplay-state transition. The composition regression
audit passes with 245 scripts, 13 directories, and zero unclassified files;
UID sidecars pair 245:245 with no duplicates.

## Completed: Stage 3.1 next screen boundary audit

Mapped title/archetype and settings ownership. GameplayState writes ten settings
control fields from the build result, and frame/input/reflow paths read the
settings overlay directly, so moving the screen needs a typed state owner.
Shared face-button prompt composition is a safer seam: it is used across seven
screen groups and can move with an explicit pixel-text callback and no root or
screen-state dependency.

## Completed: Stage 3.1 shared menu prompt factory

Moved shared face-button glyph lookup, texture composition/cache, and icon
layout into the root-free 140-line `MenuPromptTextureFactory`. All existing
ScreenStateController method names remain as delegates. The composition audit
passes at 246 scripts with zero unclassified files.

## Completed: Stage 3.1 navigation banners

Added 25 one-line section banners across ScreenStateController without moving
methods or changing behavior. Regenerated the index and refreshed the
composition baseline; the screen controller now measures 5,086 lines.

## Completed: Stage 3.1 next screen owner audit

Confirmed the screen wiring boundaries. GameplayState copies ten settings UI
references out of a dictionary; frame/input routing and display reflow observe
the overlay. SaveFlowController copies eleven name-entry node references and
later mutates the pending-slot/owner lifecycle fields, while frame/input routing
only need the overlay. Recorded these corrections in the composition plan.

## Current work: Stage 3.1 screen composition

Completed the Name Entry owner in two slices. The 94-line `NameEntryWidgetPresenter`
owns construction/layout; the 251-line `NameEntryScreenController` owns text,
selection, input, visual refresh, callbacks, and pending-slot lifecycle.
ScreenStateController keeps compatibility accessors and screen transitions;
SaveFlowController now uses explicit pending-slot/completion operations.

Moved Save Select tree construction and responsive footer placement into the
75-line `SaveSelectScreenPresenter`. ScreenStateController retains its overlay
and footer accessors. SaveFlowController continues to own slot/overwrite/recovery
transactions, and GameplayFrameController continues to route input.

The composition regression audit passes at 249 scripts, 13 subdirectories, zero
unclassified files, and 249 unique script UID sidecars. ScreenStateController is
4,914 lines; its Stage 3 forward targets remain open at 800 lines / 120 seams.
The strict target audit is also open because GameplayState remains 1,726 lines,
seven above its 1,719-line target. No Godot runtime or gameplay tests were run.

Next: decompose the title/archetype screen group, keeping save/profile creation
transactions in SaveFlowController and the screen facade stable for bootstrap
and frame routing.

## Completed: Stage 2.1 context twin collapse

Collapsed all 20 measured twins: four in ScreenStateController, 14 in
RoomController, and two additional pairs in ActiveRunSnapshot and RunSettlement
that the original plan omitted. Updated callers to typed contexts and refreshed
the script index and plan.

The composition regression and strict target audits pass with zero live twins;
the composition self-test, UID validator, test-manifest validator, literal
script-path scan, and `git diff --check` pass. Godot-backed gameplay checks were
not run because the shared editor session is active and no MCP controls are
available in this session.

## Stage 1 script role-folder migration

Moved all 235 scripts with their UID sidecars into the approved role folders,
updated live script paths, enabled recursive index generation, and regenerated
the 235-entry script index. The composition regression gate, self-test, and
manifest checks pass, and all script UIDs now resolve. A pre-existing stale UID
in four room-prefab resources was corrected. No gameplay behavior changed.

The Godot definition validator and curated gameplay gate remain pending because
the active editor restriction prevents launching a second Godot process; no
editor MCP controls are exposed in this session. See
`coord/script-role-reference-audit.md` for the migration record.

## Completed: Stage 0 composition guardrail

Starting with `tools/validate_composition.ps1` and
`tools/composition-baseline.json`: separate regression floors from forward
targets, record per-file seam baselines, add the new architecture metrics and
checks, and give each new check a rejecting self-test fixture. The smoke-runner
preflight now checks definition-manifest freshness before inventory and smoke
execution. This additive runner edit was made on the owner's instruction to
finish Stage 0 while opencode's older claim remained listed.

## Stage 0 progress

Re-based the validator with separate regression ceilings and forward targets,
per-file seam floors, stable architecture-rule snapshots, controller dependency
cycle detection, and repo/per-file counts for root reach-through, untyped root
parameters, context twins, string call forms, and script organization. Added
rejecting `-SelfTest` fixtures for all eight new architecture checks. The
GameplayState field ceiling is 287 (286 current) to provide one field of
headroom, with the reason recorded in the baseline.

The self-test, regression-floor mode, strict mode, and `git diff --check` pass.
The plan's parameter audit reported 560 while the new typed signature scanner
currently measures 556; the displayed difference is retained for review rather
than rounded or hidden. The CI coverage decision is recorded on the runner
claim in `coord/BOARD.md`: Pages CI stays focused on validation and web-export
smoke; the full gameplay smoke matrix remains an explicit local verification
task.

## Completed: browsable design wiki site

Added `docs/wiki/` as the content source and `wiki-site/` as a responsive,
searchable Markdown-rendering website. `tools/build_design_wiki.ps1` assembles
the site at `dist/wiki/` for the existing Pages domain's `/wiki/` path. Linked
the wiki from the README, contributor map, and documentation map. The local
static build succeeds, all source Markdown links resolve, and JavaScript syntax
is clean. Publishing integration remains pending until opencode releases the
Pages workflow claim.

## Completed this pass: room remains locked with no enemies alive

Found that invalid-position recovery can hide an enemy and set its combat state
dead without invoking the normal death callback, while room clear was checked
only from that callback. CombatRuntimeController now treats missing runtime
slots as unavailable and reconciles empty combat, treasure, special-enemy, and
downstairs encounters during the scheduled gameplay tick. Existing special
room color and respawn rules remain authoritative. Scoped `git diff --check`
passes. No Godot process or tests were run while the editor is active.

## Completed this pass: contact transmission and spell palette inheritance

Contact transmission no longer rolls per-status proc chances; immunity,
special-defense, eligibility, and per-pair cooldown checks remain, and direct-hit
proc rates are unchanged. Elemental spells retain their bound form and use the
active temporary flame's palette for visuals. Water bubbles already used the
captured cast palette; Ice spike crystals now use it too, with palette included
in the visual cache key. The updated transmission smoke source has a zero-proc
case and cleans up the renamed actor. Static diff checks pass. No Godot process
or tests were run while the editor is active.

## Latest implementation — source complete

Implemented the approved five-status affinity, Wet, transmission, weapon-imbue
particles, saved run themes, and healing supports. Added focused source coverage
for component lifecycle/cadence, contact cooldowns and provenance, run-theme
frequency, healer filtering, cached-definition isolation, and legacy roster
migration. Updated the plan, gameplay tuning, architecture, authoring guidance,
design addendum, audit, known issues, and smoke manifest.

Both `validate_composition.ps1` modes and `git diff --check` pass. The Godot
smokes, script/definition/catalog diagnostics, seed sweep, screenshots, runtime
combat checks, and browser acceptance remain unrun because no Godot MCP tools
are exposed in this session and the repository's recorded restriction forbids
starting another Godot process. Do not commit: the shared tree contains
pre-existing edits from other work.

## Completed

Amended the elemental plan per owner direction: runs usually select two
non-Normal elements and sometimes three, with a three-element cap across both
the run and each room. Added a provisional 20% three-element theme chance,
marked for seed-sweep tuning. All elemental support variants retain shared ally
healing. Documentation only; `git diff --check` passes.

Recorded the owner's two non-Normal enemy elements per run and room, saved run
theme with preferred synergy, and shared ally-healing behavior for every
elemental support. S7 now includes healer variants, bosses/summons/respawns,
snapshot persistence and run-union verification. Legacy snapshot treatment is
an explicit release question. Documentation only; `git diff --check` passes.

Reviewed and revised `docs/elemental-affinity-and-transmission-plan.md` at the
owner's request, including innate lifecycle and spawn reset, transmission
snapshot/cooldown rules, staged Wet activation, final-roster constraints,
cached-resource isolation, and HP-linked Chroma clarification. Roster-wide
compatibility was later superseded by the two-element run theme and synergy
preference. Runtime files were not
changed in this documentation task; static diff inspection only.

Converted both Water Triangle WAVs to OGG with the repository converter's
Vorbis quality 5 setting and updated the catalog and spell/tuning docs to use
the OGG files. Bumped the title and web build version to `0.3.27`. Offline
GDScript diagnostics, OGG decode checks, and `git diff --check` pass. No Godot
runtime or test suite was launched; rendered/mobile web playtest acceptance
remains open.

Electric Skyfall now uses a short stepped bolt aimed from above at the target
sprite's rendered top-center, with the electric sparks retained as impact
support. Stun applies a brief lock immediately on proc, repeats on its existing
stack-adjusted cadence, and gives enemies a sprite-only jolt without moving
collision geometry. Water Triangle plays the supplied `bubblesent.ogg` once at
launch and `bubbleburst.ogg` once when the bubble reaches a target; expiry
without impact stays silent. Both cues are registered in the shared catalog,
warm-loaded by `SoundManager`, and exposed in the central mix profile. Updated
spell/status plans and gameplay tuning. Offline MCP script diagnostics pass for
all changed GDScript files and `git diff --check` passes. No game or test suite
was launched; rendered and web-playtest acceptance remain open.

Fire Cinder Cone now snaps diagonal aim to horizontal left/right and uses the
player's remembered facing for vertical aim. The 90-degree hit and puzzle
sectors remain unchanged; only the fan art flares slightly wider at its far tip.
The spell plan and tuning index document the visual/hit-sector distinction.
Offline GDScript diagnostics and `git diff --check` pass. No Godot runtime or
gameplay tests were run.

Replaced the repeated Hub flame sprites with one animated cone texture that
maps each palette-recolored `Fire.png` frame across the 90-degree sector.
Delayed pixel-spark lanes flow outward through the fan and reuse the Burning
effect's fire palette and fade. Water and hit geometry are unchanged. Offline
script diagnostics and `git diff --check` pass. Gameplay was not launched under
the session restriction, so rendered acceptance remains open.


Static hookup audit is complete. All eight Triangle forms trace from Chroma acceptance through the cast frame to delivery and hit effects. Fixed puzzle-object routing, pointer-aim target resolution for Skyfall and Leechvine, and debug-unlimited form-cost selection.

Offline GDScript diagnostics and git diff --check pass. Runtime playtest and balance/readability acceptance remain open; no Godot process or suite was launched.

The elemental spell-form track was handed off from opencode after P3. P4â€“P7
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

The baseline is version 0.3.26. The Fire and Water presentation changes are
local and need an in-game visual review before a future release. Do not launch
another Godot process or test suite in this session.

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

## 2026-09-30 â€” Elemental spell-form continuation

Opencode handed off the spell-form paths after implementing P3 Electric Skyfall.
P1â€“P3 runtime acceptance remains open. Codex is implementing P4 Water Tide
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

## 2026-09-28 â€” Player status presentation

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

## 2026-09-29 â€” Generic room-prefab runtime slice

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

## 2026-09-30 â€” Elemental spell forms P4â€“P7

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

## Latest task

Grouped the source-only `Artwork/` archive by character family, environment,
items, effects, UI, and references. Moved 210 loose files and 21 stone accents,
preserving every original filename and the root `.gdignore`.

Added `Artwork/README.md` and `docs/CONTENT_FOLDERS.md`, and linked the guide
from `AGENTS.md` and `DOCUMENTATION_MAP.md`. Updated map-reference tools and
smokes for the new source paths, and corrected the HUD's direct-image fallback
to use `assets/artwork/`.

Runtime asset/resource paths and the pre-existing `project.godot` edit remain
untouched. Static filename and path checks pass; no Godot process or test suite
was launched.

## Latest task

Organized the scene library into role-based folders. The 25 movable scenes now
live under `gameplay/rooms` and `geometry`, `menus/hub` and `menus/pause`,
`ui/hud` and `ui/components`, `authoring/previews`, `guides`, and `templates`,
and `debug`. Kept `scenes/main.tscn` at the configured boot path.

Updated scene resource paths, code, tests, tools, and documentation. Added the
scene tree to `docs/CONTENT_FOLDERS.md`. Static checks resolve all 38 unique
scene-file references, find no old flat paths, and pass `git diff --check`. No
Godot process or test suite was launched.

## Latest task

Fixed the targeted-enemy outline size by matching the generated outline's displayed frame size to the source sprite. Electric status is now named `shocked` in the registered ID and resource and uses a distinct badge mark. Existing status pulses interrupt enemy actions, cancel support casts, prevent AI movement, and shake the sprite; each lock window is now 0.2 seconds on the existing one-second cadence.

Updated the status and spell documentation. Static stale-ID/resource scans and `git diff --check` pass. No tests or Godot process were launched under the repo's recorded session restriction. The pre-existing local project, room-prefab, and root scene files were preserved.

## Latest task

Ice's Frostbite Shard now uses Water's contact splash delivery: direct impact damage, reduced nearby splash damage, and six palette-colored pixel spikes that rise and hold briefly. Ice's registered status is now `chill`; its stacked slow multiplier affects movement and attack timing/animation for enemies and the player. Player Ice attunement now uses a bright cyan swatch with pale-cyan horn accents and the darker eye treatment shared by Electric and Grass, while Ice enemies retain aquamarine.

Updated gameplay, authoring, spell, status, and design docs. Static resource/ID scans and `git diff --check` pass. No Godot process or tests were run under the repo's recorded session restriction.

## Parser error follow-up

Removed a duplicate `player_status` local declaration from `GameplayFrameController.tick()`; the attack-finish branch now reuses the status reference created earlier in the function. Static inspection confirms one declaration and `git diff --check` passes. Godot was not launched under the existing session restriction, so the editor parse is not runtime-verified.

## Ice spike visual follow-up

Reshaped the impact effect into seven overlapping spikes arranged as rear, center, and front arcs around a compact circular footprint. Added pale reflective facets and bright tip glints for a glossier ice finish. Updated gameplay and spell-form documentation. Static inspection and `git diff --check` pass; no Godot process or tests were run.

## Ice AOE footprint and highlight follow-up

Expanded the Ice spike bases into a 13-spike center/inner/outer layout centered on impact; the outer ring is computed from the spell's splash radius so its footprint reaches the AOE edge. Moved Ice's gloss stripe and tip glint to the right, and shifted the Water bubble's white glint to its upper-right. Updated spell docs. Static checks pass; no Godot process or tests were run.

## Ice crystal appearance follow-up

Changed the spike generator from smooth triangular spikes to angular, stepped crystal silhouettes with a dark left facet, bright right edge, and white right-side glint. The impact crystals use the brighter cyan Ice ramp to read as ice instead of aquamarine shards. Updated spell and gameplay descriptions. Static checks pass; no Godot process or tests were run.

## Isometric Ice footprint follow-up

Compressed the Ice cluster's vertical base offsets to 52% while preserving its horizontal radius, making the ground footprint read as a broad oval in the game's isometric view. Spike height and AOE damage/radius remain unchanged. Updated the spell documentation. Static checks pass; no Godot process or tests were run.

## Web release check follow-up

Restored `renderer/rendering_method.web="gl_compatibility"`, required by `tests/web_export_smoke.ps1`, and bumped the release version to 0.3.31 for the follow-up main push. Static diff and version checks only; no Godot process or tests were run.

## Contact transmission timing

Removed the room-engaged gate from status contact transmission so an existing transmissible status can transfer as soon as physical contact occurs after room entry. Updated the controller API callers and bumped the release to 0.3.32. Static diff check passes; no Godot process or tests were run.

## Elite-room softlock follow-up

The current room clear predicate now only waits on configured actors that remain visible in the active tree, have positive health, and are not marked dead. This prevents hidden or depleted pooled actors from blocking the elite room exit. Bumped the release to 0.3.33. `git diff --check` passes; no Godot process or tests were run.

## Completed: Stage 2.2 hub flow split

Separated hub routing from economy/progression. The 340-line route controller owns
the economy module as a RefCounted subcontroller; the 1,091-line economy script
owns the moved workflows. Shared page/mode values and property transitions now
live in HubMenuState. The seam metric counts both modules together at 109 against
the 120 target. Updated the fusion presenter, focused fixture references, role
map, baseline, plan, and generated script index. `git diff --check` passes; no
Godot test or runtime verification was run.

## Completed: Stage 2.3 pixel text texture factory

Moved pixel text, name, keyboard prompt, and critical outline texture creation
into PixelTextTextureFactory with its four caches and gear-plus asset. Effects
Spawner keeps the public facade methods; particle lifecycle code stays in the
spawner. The script index and per-file composition record now include the
250-line factory. Call-site and moved-cache references were inspected. Godot
runtime checks and tests were not run while the shared editor session is active.

## Completed: Stage 2.4 typed slime geometry queries

Extracted 22 collision and walkability query methods into the 206-line
SlimeGeometryQueries helper. SlimeRuntimeController keeps the stable delegation
surface, all 57 string callback sites remain visible across the pair, direct
GameplayState access replaces dynamic get/call/set in the helper, and a shared
Firepit lookup removes duplicate child resolution. The composition audit passes
in regression-floor mode. Godot runtime checks were not run with the editor
session active.

## Completed: Stage 3.1 end-of-run screen presenters

Moved Game Over construction, responsive reflow, row state, and fade visuals into the 72-line GameOverScreenPresenter. ScreenStateController retains the death timeline, shared input-release latch, and input routing; GameplayState retains defeat grading, puzzle rotation, and run settlement.

Moved Run Complete construction and responsive layout into the 73-line RunCompleteScreenPresenter. ScreenStateController preserves the observation accessors used by frame routing and RunFlowController, while GameplayState no longer copies five UI references from a dictionary.

The strict composition audit passes at 254 scripts, 13 subdirectories, zero unclassified files, and unique UID sidecars. GameplayState is 1,709 lines / 282 fields; ScreenStateController is 4,628 lines; root reach-through is 4,337. No Godot runtime or gameplay tests were run.


## Completed: Stage 3.1 Hub/Pause construction boundaries

Replaced the positional hub callback list with the 29-action HubScreenActions record. ScreenStateController.build_hub now returns void and owns the constructed refs directly; HubFlowController builds the typed actions and keeps the debug-session wiring. Pause widget construction and node refs moved to PauseScreenPresenter, with ScreenStateController preserving typed forwarding accessors for existing callers. The touch-controls fixture now reads controller fields directly.

The strict composition audit passes at 256 scripts, 13 subdirectories, zero unclassified scripts, 2,092 root accesses, and unique UID sidecars. Reach-through is 4,258 (down from 4,337); GameplayState is 1,709 lines / 282 fields; ScreenStateController is 4,641 lines / 292 seams. HubFlowController remains under its target at 109 / 120 seams. No Godot runtime or gameplay tests were run.


## Completed: Stage 3.1 typed Hub/Pause input boundary

Typed update_pause_input, _update_pause_equipment_input, and update_hub_input against GameplayState. Replaced 222 string root.call dispatches with direct method calls after confirming every target method exists on GameplayState. No screen behavior was intentionally changed.

Strict composition audit passes: dynamic root calls fell 2,092 -> 1,870; untyped root parameters fell 516 -> 513; ScreenStateController seams fell 292 -> 70, meeting the 120-seam target. Reach-through is still 4,258; ScreenStateController is 4,641 lines. No Godot runtime or gameplay tests were run.

## Completed: Stage 3.1 hub allocation render seam

Split allocation-page rendering from `update_hub_ui` into a typed
`_update_hub_allocation_page` method. Converted its remaining-points, stats, and
snapshot access to direct `GameplayState` calls. The strict audit passes at
1,867 dynamic root calls, 513 untyped root args, and 67 ScreenStateController
seams; reach-through is 4,257. ScreenStateController remains 4,642 lines, so
this is an internal boundary rather than a completed presenter extraction.
The script index is refreshed. No Godot runtime or gameplay tests were run.

Mapping showed the stats nodes are observed by responsive layout and the
equipment, six-stat, fusion, and touch-control callers. Preserve their current
ScreenStateController property names as typed forwarding accessors when the
stat presenter takes ownership.

## Completed: Stage 3.1 Hub Stats presenter

Moved allocation/status node construction, status and allocation rendering,
marker/target positioning, and allocation preview calculation into the typed
`HubStatsScreenPresenter`. ScreenStateController preserves the existing typed
forwarding properties used by responsive layout and menu callers. Updated the
fusion fixture for the typed builder/update API and supplied its HubFlow
dependency. Regenerated the script index and tightened the composition
baseline. Strict audit passes at 257 scripts, zero unclassified files, 1,856
root call/get/set sites, 510 untyped root arguments, and 56 ScreenStateController
seams; ScreenStateController is 4,437 lines. Total reach-through is 4,258,
effectively unchanged from 4,257. No Godot runtime or gameplay tests were run.

## Completed: Stage 3.1 Hub page visibility

Moved Hub page-root lookup, title setup, legacy page-chrome hiding, and
root/active-page visibility into the typed `HubPageVisibilityPresenter`.
ScreenStateController keeps typed forwarding properties for the root page and
page-root map, and normalizes the legacy STATUS route before the presenter
applies visibility. The fusion fixture remains on the typed build/update API.
Strict audit passes at 258 scripts, zero unclassified files, and 56
ScreenStateController seams; the controller is 4,405 lines. Updated the script
index, role map, and regression baseline. No gameplay or Godot runtime tests
were run.

## Completed: Stage 3.1 Hub command shell and cursor

Moved command-button and Back-button construction, command-cursor target
calculation, responsive reanchoring, and active/dimmed cursor presentation into
the typed `HubCommandShellPresenter`. ScreenStateController preserves typed
forwarding properties for the button and cursor references. The presenter uses
`MenuCursorAnimator` for motion while the animator retains tween ownership. The
strict composition audit passes at 259 scripts with zero unclassified files;
ScreenStateController is 4,332 lines / 56 measured seams. The 800-line target
remains open. Refreshed the index, role map, and baseline. No Godot runtime or
gameplay tests were run.

Next: map Hub responsive layout responsibilities and their node owners before
extracting layout behavior.

## Completed: Stage 3.1 responsive Hub layout

Moved responsive Hub geometry for the command/resource rails, page roots,
player card, allocation/status controls, item/gear/binding panels, and legacy
cursors into `HubResponsiveLayoutPresenter`. Its typed context carries viewport
and menu state plus the page, stats, command, cursor-animation, and tween-owner
references. `HubStatsScreenPresenter` now positions its own stat cursor.
ScreenStateController keeps typed forwarding properties and delegates its
responsive layout call. The presenter separates frame/navigation, player and
footer, stats, inventory, child-menu, and cursor positioning into named steps.
The strict composition audit passes at 261 scripts
with zero unclassified files; ScreenStateController is 4,218 lines / 56
measured seams. The 800-line target remains open. Refreshed the script index and
baseline. No Godot runtime or gameplay tests were run.

Next: map the largest remaining ScreenStateController render and build methods
to identify the next extraction boundary.

## Completed: Stage 3.1 Hub stats interaction

Moved stats/allocation visibility and focus targets plus stat-cursor display
into `HubStatsInteractionPresenter`. It operates on the typed
`HubStatsScreenPresenter`, which continues to own the nodes and text rendering.
The composition guard rejected growing the stats presenter beyond 400 lines;
visibility and cursor responsibilities now sit in a separate 82-line owner.
The strict audit passes at 262 scripts, zero unclassified files, and 56
ScreenStateController seams; the controller is 4,182 lines. Its 800-line
target remains open. No Godot runtime or gameplay tests were run.

Next: map `build_hub`'s widget construction against the existing typed
presenters and separate ownership from assembly.

## Completed: Stage 3.1 Hub shell construction

Moved player-card, context/back prompt, footer, and gold/soul node creation into
`HubResponsiveLayoutPresenter`, which already owns their responsive placement
and typed references. `build_hub` now delegates shell chrome construction and
keeps the legacy currency aliases. Its length fell from 303 to 262 lines; the
presenter is 360 lines, below the 400-line declaration guard. The strict audit
passes at 262 scripts, zero unclassified, and 56 ScreenStateController seams;
the controller is 4,141 lines. No Godot runtime or gameplay tests were run.

Next: map the remaining 269-line `update_hub_ui` by page and owner.

## Completed: Stage 3.1 Hub footer presentation

Moved footer and back-prompt texture/visibility updates into
`HubResponsiveLayoutPresenter`. ScreenStateController retains prompt selection
and device-aware texture generation. `update_hub_ui` dropped from 269 to 253
lines; the responsive presenter is 392 lines, below the 400-line guard. Strict
composition audit passes at 262 scripts with zero unclassified and 56
ScreenStateController seams; the controller is 4,125 lines. No Godot runtime
or gameplay tests were run.

Next: map the remaining `update_hub_ui` routing and item-page visibility by
owner.

## Completed: Stage 3.1 authored Hub route visibility

Moved nested Fusion/Equipment/Shop visibility, Equipment page chrome handling,
and the transparent Back hit target into `HubPageVisibilityPresenter`. Fusion
is still hidden before cursor reset; ScreenStateController retains page
normalization, player-card refresh, and item rendering. The typed route method
reduces `update_hub_ui` from 253 to 223 lines. Strict audit passes at 262
scripts, zero unclassified, and 56 ScreenStateController seams; the controller
is 4,095 lines. No Godot runtime or gameplay tests were run.

## Completed: Stage 3.1 legacy Hub item visibility

Moved legacy Equipment, Shop, and Fusion widget visibility, hit filtering,
action-button state, and Shop cursor positioning into `HubItemVisibilityPresenter`.
A typed context carries page, focus, selection, and profile state; the
responsive presenter remains the owner of the controls it creates and positions.
`update_hub_ui` dropped from 223 to 158 lines, and ScreenStateController from
4,095 to 4,057 lines. The new presenter is 111 lines; its context is 13 lines.
The strict composition audit passes at 264 scripts, zero unclassified files,
and 56 ScreenStateController seams. No Godot runtime or gameplay tests were run.

## Completed: Stage 3.1 Hub input ownership

Moved the 240-line `update_hub_input` route into the typed `HubInputController`,
then split it into named Back, command-rail, and per-page handlers. Mutable page,
focus, and transaction substate now lives in `HubMenuState`; ScreenStateController
keeps typed forwarding properties for existing flow/economy callers. The router
uses typed GameplayState and presenter references plus narrow render/scroll
callbacks. ScreenStateController is 3,898 lines; `update_hub_input` is a 7-line
facade. The controller is 306 lines and HubMenuState is 93 lines. The strict
composition audit passes at 265 scripts, zero unclassified files, and 56 screen
controller seams. No Godot runtime or gameplay tests were run.

Input mapping: GameplayFrameController still enters through
GameplayState._update_hub_input, which now casts its existing Node reference and
calls the typed screen method directly. The router handles touch scroll, Back,
command-rail navigation, and status/bind/fusion/allocation/equipment/shop/item
routes in a fixed order.

Next: map `_update_hub_item_page` and `_update_hub_gear_slots` against the Hub
economy controller and their current widget owners before moving item rendering.

## Handoff: paused for owner check-in

No item-page extraction is in flight. The latest strict composition audit passes
with 265 scripts and zero unclassified files. Stage 3.1 remains open: the
ScreenStateController is 3,898 lines against an 800-line target, and the audit
counts 510 untyped root parameters repository-wide. The next code slice is a
typed Equipment-page presenter for the slot list, candidate picker, and stat
comparison, followed by the shared Shop/Fusion item renderer. Godot runtime
verification remains pending; no Godot process was launched.

## Completed: Stage 3.1 active Hub/Pause Equipment presenter

Extracted the shared authored Equipment renderer into the typed
`HubEquipmentMenuPresenter` and `HubEquipmentMenuContext`. ScreenStateController
retains its adapter and compatibility helper methods; `HubMenuState` owns
equipment mode resolution. The HubFlow compile repair now routes fusion cache
invalidation through its typed economy controller to preserve the per-file
reach-through floor. The authored view path is covered by existing smoke
sources; the legacy item/gear renderer remains a fallback for unavailable
authored views.

Strict composition audit passes at 267 scripts, zero unclassified files, 52
ScreenStateController seams, 4,253 total root reach-throughs, and 509 untyped
root parameters. The script index contains 267 scripts; UID validation passes
for 422 sidecars. No game or gameplay test was run while the shared editor is
active.

Next: map the active Shop and Fusion render-model paths against
`HubEconomyController` and existing authored view/layout models, keeping
transactions and mutable state in their current owners.

## Completed: Stage 3.1 Shop/Fusion presentation model

Extracted Shop and Fusion render-model assembly to the typed
`HubTransactionMenuPresenter` and `HubTransactionMenuContext`; added
`ShopMenuModel` and a model-based Shop renderer adapter while retaining the
existing argument-based API for preview callers. ScreenStateController gathers
RunState stock and economy-owned results, and retains menu state and
transactions. The presenter owns row formatting and shared stat comparison.

Strict composition audit passes at 270 scripts, zero unclassified files, 52
ScreenStateController seams, 4,253 root reach-throughs, and 509 untyped root
parameters. The script index contains 270 entries; UID validation passes for
425 sidecars. Offline MCP validation passes for the three new scripts and the
two changed controllers/layouts. No game or gameplay tests were run while the
shared editor restriction is active.

Next: map remaining active Hub render/build responsibilities against their
typed view owners. Keep the legacy `_update_hub_item_page` and
`_update_hub_gear_slots` fallback until its external readers have a replacement.

## Completed: Stage 3.1 authored Hub signal binding

Moved Equipment, Shop, Fusion, and Bind view signal wiring from build_hub
into HubMenuSignalBinder. The binder accepts typed authored views,
HubScreenActions, and the narrow callback that updates selected Equipment
command state. ScreenStateController still constructs the views and owns menu
state. The composition audit passes at 271 scripts, zero unclassified files,
52 screen seams, 4,253 reach-throughs, and 509 untyped root parameters; dynamic
string connect calls are now zero. UID validation and offline MCP script
checks pass. No game or gameplay tests were run while the shared editor is
active.

Next: trace remaining legacy Hub Equipment/Shop widgets built by build_hub
through rendering and input consumers before moving or deleting that cluster.

## Completed: Stage 3.1 legacy Hub widget visibility

Moved Equipment and Shop legacy-widget suppression into
`HubLegacyWidgetVisibilityPresenter`, which consumes the existing typed
`HubResponsiveLayoutPresenter` widget owner. Equipment still suppresses only
its exclusive input targets; Shop also ignores all legacy Control input and
stops the legacy cursor. Existing aliases, fallback rendering, layout, and
input readers remain intact. Removed a duplicate stat-text append from the old
Equipment suppression path.

Strict composition audit passes at 272 scripts, zero unclassified files, 52
screen seams, 4,253 reach-throughs, and 509 untyped root parameters. UID
validation and offline MCP script checks pass. No game or gameplay tests were
run while the shared editor restriction is active.

Next: map the remaining legacy Hub data/render path and its scroll consumers
to determine which typed authored view can replace each fallback reader.
