# Journal

Append-only. Newest at the bottom. One entry per `claim` / `handoff` / `blocker`
/ `done`. Do not edit prior entries.

## 2026-09-27T00:00Z — opencode — note
Initialized the coordination board. Protocol in `coord/README.md`. Agents:
read both status files and `BOARD.md` at task start; claim before editing.

## 2026-09-27T15:00Z — codex — claim
Claimed the enemy design-preview death-effect acceptance slice. Recording the
latest user playtest status and leaving the interactive workbench for follow-up.

## 2026-09-27T15:20Z — codex — blocker
Implemented the deterministic death-effect preview and passed the focused
headless enemy preview. Editor MCP repeatedly disconnected, leaving visual
playback and lifecycle acceptance open; the single editor remains on the enemy
preview scene for reconnection and manual verification.

## 2026-09-27T16:00Z — opencode — claim
Release-gate integrity. Touching tests/run_all_smoke.ps1 and (pending decision)
.github/workflows/web-pages.yml. Not touching docs/KNOWN_ISSUES.md or
docs/authoring-system-plan.md (codex claim).

## 2026-09-27T16:05Z — opencode — note
Repo-wide read-only audit delivered: architecture seams, verification surface,
content/player state, plus Thorn/Hexley/Pip advisories. Manifest re-check shows
the nine 2026-09-27 gate failures are now all state=verified; the live gate
defects are the optional sfx-lab venv hard-fail and hardcoded paths.

## 2026-09-27T16:30Z — opencode — done
Fixed `tests/run_all_smoke.ps1`: optional sfx-lab venv skip (opt-in
`-RequireSfxLab`), project-relative paths, missing-test failure flag, UID
preflight. Verified via PS parser + pure-PowerShell preflights (all green).
Curated gate execution still pending (editor peer held by codex).

## 2026-09-27T17:10Z — opencode — handoff
Wrote `docs/healer-slime-cast-plan.md` (Healer Slime cast: 2s interruptible
channel, frame-1 single-ally heal, green charge aura + rising "+" particles,
below-caster cast bar, behind-allies/keep-gap AI). Handing to codex for
implementation. Codex owns `scripts/enemy_preview_workbench.gd`,
`docs/authoring-system-plan.md`, `docs/KNOWN_ISSUES.md`; Phase 6 preview work
and the stale gate paragraph are codex's. No board row claimed by opencode.

## 2026-09-27T17:40Z — opencode — note
Wrote `docs/timed-floor-hazard-plan.md` (randomized room-edge spike tiles,
door-adjacent excluded; ~5s raise/retract; one hit per actor per cycle for player
and enemies; AI avoids via a steering danger term but knockback can still push
enemies on; no i-frames exist so a per-cycle fired-set is required). Verified the
asset blocker: the two spike PNGs (16x16, 128x16) live in the `.gdignore`d
`Artwork/` folder with no `.import`, and nothing is in `assets/artwork/` yet.
No board row claimed by opencode.

## 2026-09-28T00:00Z — codex — blocker
M1 preview lifecycle slice: made all design-preview factory actors explicitly inert and added a focused lifecycle smoke plus manifest row. Script diagnostics and manifest validation pass. Godot runner was blocked by restricted user:// writes and editor startup; a direct standalone retry crashed before the test ran, so runtime and editor acceptance remain unverified. Do not start another Godot process in this session.

## 2026-09-28T00:20Z — codex — note
Workbench direction expanded from the enemy M1 proof to one shared platform with content-kind adapters. Source audit found ordinary room transitions keep the room shell authored in main.tscn and mutate geometry in place; basic_room/orb_room are not runtime definition-driven prefabs. RoomDefinition is global tuning, and DungeonSocket IDs derive from four fixed edge kinds. Updated authoring plan, content guide, and roadmap to establish a staged RoomPrefabDefinition/RoomFactory/RoomHost path with separate topology, prefab composition, per-run state, and explicit socket-ID migration.

## 2026-09-28T00:35Z — codex — note
Preview-session isolation design: ProfileSaveService is static over user:// slot paths and web builds write profile state to shared local storage. An in-process temporary slot is not safe. M1 interactive previews should launch a child game process with a unique temporary --user-data-dir, a versioned launch payload, and child-scoped stop/cleanup. Updated authoring-system-plan and Codex handoff accordingly.

## 2026-09-28T00:45Z — codex — claim
Pixel-art theme pass for the enemy preview canvas and geometry overlay in
`scripts/enemy_preview_workbench.gd`; using the existing runtime bitmap text
renderer and crisp pixel UI surfaces.

## 2026-09-28T14:26Z — codex — done
Replaced all fallback-font text on the enemy preview canvas and geometry overlay
with the shared pixel-text renderer, added a hard-edged pixel palette frame,
and made geometry strokes crisp. Corrected enemy preview transform setup for
all actor families. Offline script diagnostics and `git diff --check` pass;
visual/editor acceptance remains unverified because Godot must not be launched
again in this session after the earlier crash.

## 2026-09-28T14:27Z — codex — claim
Preparing the authorized main push: reviewing only Codex-owned workbench files,
incrementing the required game version, and running no-Godot web/export
preflights. `.mcp.json` and `docs/timed-floor-hazard-plan.md` remain outside the
claim and will not be included.

## 2026-09-28T14:44Z — codex — blocker
The static Web export preflight found the required
`renderer/rendering_method.web="gl_compatibility"` override removed from the
working `project.godot` after initial status review. Restoring the exact
documented setting before rerunning Web configuration validation.

## 2026-09-28T14:45Z — codex — done
Restored the Web renderer override to match `main`; the working tree now has no
`project.godot` change. The Web configuration smoke passes in no-Godot mode,
and the script reports export skipped because its executable was intentionally
unavailable. The Pages workflow remains responsible for the actual export.

## 2026-09-28T14:50Z — codex — claim
Adjust support healer cast-bar vertical offset and healing potency, with full
direct self-heals and unchanged 25% caster reflection when healing an ally;
update gameplay and authoring tuning docs. No Godot process will be launched.

## 2026-09-28T15:52Z — codex — done
Moved the healer cast bar 2px up, reduced healing to 9 HP + 1.8 HP per healer
INT, made direct self-target healing full potency, and retained 25% caster
reflection on ally-target casts. Updated tuning/authoring docs. MCP offline
script checks and `git diff --check` pass; no test suite or Godot process ran.

## 2026-09-28T16:25Z — codex — claim
Prepare a 0.3.11 release containing the healer adjustment, update the in-game
and README version, and push to `main` to trigger GitHub Pages deployment for
mobile browser playtesting. Keep `.mcp.json` and the timed-floor plan out.

## 2026-09-28T16:32Z — codex — done
Released version 0.3.11 in commit `72c47db` and pushed `main` to origin;
GitHub Actions is configured to build and deploy Pages for the mobile browser
playtest. The staged commit excluded `.mcp.json` and the timed-floor plan.

## 2026-09-28T16:32Z — codex — claim
Continue M1 offline: inspect and finish the enemy preview authoring lifecycle
and isolated interactive PreviewSession boundary. Do not launch Godot after
the recorded standalone crash.

## 2026-09-28T16:49Z — codex — claim
Add registered enemy design/play/stop dock actions, deterministic isolated
sessions, refresh hooks, and focused contract coverage; reconcile live inventory
counts in the authoring and verification docs. Godot execution remains deferred.

## 2026-09-28T16:55Z — codex — blocker
The M1 source slice and offline diagnostics are in place, but dock/session smokes
and live profile isolation remain unverified because the repo records a Godot
startup crash and forbids another process launch in this session.

## 2026-09-28T17:05Z — codex — claim
Source audit for healer arc anchors/boss jump, cast-bar position, Fusion inventory
scans, and Shop BUY/SELL gear comparisons. Document findings in KNOWN_ISSUES
before implementation; preserve unfinished M1 and user-owned working changes.

## 2026-09-28T17:11Z — codex — done
Recorded the healer, Fusion, and Shop findings before implementation. Top-center
sprite-following cast anchors, the extra bar pixel, one-pass Fusion eligibility
aggregation, and equipped-versus-highlighted Shop stat columns are implemented.
Offline diagnostics and diff hygiene pass; in-game and performance evidence remain open.

## 2026-09-28T17:52Z — codex — claim
Resume M1 with a source audit of the enemy registry validation path. Keep the
0.3.12 release and unrelated user changes untouched; do not launch Godot after
the recorded crash.

## 2026-09-28T17:54Z — codex — done
Fixed the registry validator's duplicate-ID blind spot: validation now sees each
distinct embedded or standalone source and reports the conflicting stable ID
with both paths, while runtime lookup keeps its existing order. Updated the
authoring issue register and workflow docs. Offline script diagnostics and
diff hygiene pass; runtime validator acceptance remains open.

## 2026-09-28T17:57Z — codex — claim
Expose the shared enemy registry validator in the authoring dock and make the
existing placement-only validation action explicit in its label.

## 2026-09-28T17:58Z — codex — done
Added `Validate Enemies` to the dock, backed by the same catalog validator used
by definition preflight, and renamed the placement action `Validate Scene`.
Offline script diagnostics pass; editor interaction remains unverified.

## 2026-09-28T18:02Z — codex — claim
Make healing floating-number text consistently green and prepare the 0.3.13
mobile web playtest release; keep the uncommitted M1 work isolated.

## 2026-09-28T18:04Z — codex — done
All healing floating numbers now use the established pale-green feedback color.
The 0.3.13 release metadata is prepared; the combat script's offline diagnostic
and `git diff --check` pass. Runtime behavior was not launched in this session.

## 2026-09-28T18:07Z — codex — claim
Adjust the healer cast arc so both endpoints attach to the visible silhouette
outline rather than the sprite rectangle; release as 0.3.14 for mobile web.

## 2026-09-28T18:10Z — codex — done
Healer arc endpoints now select actual outline pixels nearest to the sprite's
top-center on both caster and target. Released 0.3.14 in `de41e15`; offline
script diagnostics and diff hygiene pass. No runtime was launched.

## 2026-09-28T18:11Z — codex — claim
Continue M1 with deterministic manifest generation for current and future
content roots, shared by editor refresh and CLI, and stale-manifest validation.
## 2026-09-28T00:00Z — codex — claim
Interrupting M1 for the requested 0.3.15 healer cast-anchor refinement and push. M1 manifest edits remain local and unstaged.

## 2026-09-28T18:25Z — codex — done
Healer arc endpoints now use the top-center pixel of each generated silhouette
contour; the target contact shares the exact outline pixels used by its ring.
Released version 0.3.15 in `dd19520` and pushed `main` to origin. Offline
GDScript diagnostics and `git diff --check` pass. No Godot runtime or tests ran.

## 2026-09-28T18:42Z — codex — claim
Temporarily interrupt local M1 to align Fusion's `EQUIP`/`ITEM` comparison and
header positions, enhance healer plus-particle visibility, and document the
loot-progression request pending the player's progression preference. No Godot
runtime or suite execution is allowed in this session.

## 2026-09-28T18:47Z — codex — done
Fusion now uses the Shop equipped-piece/item stat comparison with headers above
its rows; healing bursts use a dedicated 9x9 high-contrast pixel plus. The loot
progression request is source-audited and documented but awaits the player's
choice of completed-run progression, current-run depth, or both. Offline script
diagnostics and `git diff --check` pass; no tests or Godot runtime ran.

## 2026-09-28T18:56Z — codex — claim
The player selected strict completed-run progression for gear rewards, excluding
current-run depth. Updating reward-definition curves and all run chest/clear
rarity call paths, plus the tuning and issue records. No Godot process or tests.

## 2026-09-28T19:09Z — codex — done
Implemented completed-run-only gear progression across standard/risk chest
chance, chest item count, clear reward chance, and rarity. The clear reward
includes the just-completed run and leaves room for all 20 progression steps
even at maximum score; vaults remain guaranteed one item. Updated the tuning
index and issue record. Offline diagnostics pass for all three changed scripts,
the reward resource explicitly assigns all 37 exported fields, and diff hygiene
passes. No tests or Godot runtime ran; M1 work resumes.

## 2026-09-28T19:11Z — codex — claim
Replace enemy and item catalog directory scans with typed resources from the
generated content manifest so exported builds retain authored definitions.
Keep manifest freshness and exported-load acceptance open until the connected
editor/export can verify them. No Godot process or tests.

## 2026-09-28T19:16Z — codex — done
Enemy and item catalog data now source authored resources from the generated
manifest; typed filtering covers both supported roots, preserves explicit item
references, and keeps duplicate validation across roots. A static preload pins
the manifest dependency into exported builds, while editor loads replace the
cached copy after refresh. Offline diagnostics pass for the two catalog data
scripts and manifest service; diff hygiene passes. Export and lifecycle evidence
remain open; no tests or Godot runtime ran.

## 2026-09-28T19:22Z — codex — claim
Split runtime export references into enemy- and item-specific manifests so a
catalog does not load every authored resource when resolving its own kind.
Wire dock refresh to invalidate both catalog data caches. No Godot process or
tests.

## 2026-09-28T19:23Z — codex — done
Generated and checked in kind-specific dependency manifests alongside the
all-resource preflight index. Enemy and item catalogs preload only their typed
manifest; editor refresh replaces that manifest and invalidates the enemy and
item resource caches. Static source comparison confirms 28 total resources, 10
standalone enemies, and 2 items are represented. Runtime/export and lifecycle
acceptance remain open; no tests or Godot runtime ran.

## 2026-09-28T19:24Z — codex — claim
Refresh M1 registries and previews after editor filesystem add/move/delete
events as well as resource save/reimport, coalescing repeated editor signals.
Keep rendered and exported acceptance open; no Godot process or tests.

## 2026-09-28T19:26Z — codex — done
The authoring plugin now coalesces resource-save, reimport, and
`EditorFileSystem.filesystem_changed` events into one deferred manifest/cache
refresh. Offline diagnostics pass for the plugin, dock, both catalog data
scripts, and manifest service; `git diff --check` passes. Filesystem lifecycle
behavior remains unverified in Godot; no tests or runtime ran.

## 2026-09-28T19:34Z — codex — handoff
The 0.3.16 release packages the current M1 source progress with the Fusion
comparison, healing visibility, and completed-run gear progression updates.
Editor/export acceptance remains open. Preserve `.mcp.json` and
`docs/timed-floor-hazard-plan.md`; they are outside this release.

## 2026-09-28T20:18Z — codex — done
The healer regression traced to both authored animation PNGs missing import
sidecars. Added import metadata and static texture dependencies; the animation
assignment now falls back when a sheet is empty, the release waits until heal
impact before finishing, and the target-line endpoint crosshair is removed.
MCP script diagnostics pass. No gameplay or test suite was run; web playtest
acceptance remains open.

## 2026-09-28T20:30Z — codex — claim
Refining the healer burst art after player feedback. Touching
`scripts/effects_spawner.gd`, `docs/KNOWN_ISSUES.md`, and
`docs/healer-slime-cast-plan.md`; the active M1 claim already covers these paths.

## 2026-09-28T20:45Z — codex — done
Replaced the repetitive fractional-scaled healing crosses with crisp outlined
crosses and smaller sparkle accents using pixel-aligned scale and controlled
upward motion. Updated the issue and healer plan; runtime visual acceptance
remains open under the recorded Godot process restriction.

## 2026-09-28T21:00Z — codex — handoff
The user redirected the elemental-status documentation into implementation and
explicitly rejected the chest proof and grayscale acceptance requirement. The
design and implementation-plan documents from the prior authoring task are now
assigned to Codex for correction and execution, alongside the reported magenta
render artifact. No playtest may be launched in this session.

## 2026-09-28T21:53Z — codex — handoff
Implemented the four status families and their catalog/runtime/presentation
documentation. Fixed the reported overhead HUD Array cast and the missing
`PlayerAnimationContext.player_dead_get` dependency; configured `ElementAura`
through typed actor/status/overlay-parent references; added the player-death
visibility guard and opaque death-entry reset. Focused MCP script diagnostics
and `git diff --check` pass. Owner checks remain unrun, no Godot process was
launched, and the magenta artifact remains unresolved without a capture.
## 2026-09-28T22:06Z — codex — claim
Increase general gear-drop volume at chest, room-treasure, clear, and vault
reward paths; change Fusion growth so each positive gear stat line advances,
while preserving fixed tradeoff penalties. Update tuning and gear documentation.
## 2026-09-28T22:06Z — codex — claim
Follow up the status playtest report: prune freed HUD status markers before
casting, fix status-aura transform ownership, and add distinct persistent
particles for Burn, Poison, Stun, and Slow. No Godot process or tests.

## 2026-09-28T22:29Z — codex — done
Fixed cached HUD marker lifetime checks; aligned status/imbue overlays and
particle sources to each sprite's current atlas/region/sheet frame; added
separate status particles. Focused offline MCP script diagnostics and diff
hygiene pass; no runtime playtest or test suite was run.

## 2026-09-28T22:29Z — codex — done
Raised room treasure/chest/clear/drop-count quantity and guaranteed two vault
items. Fusion now advances every positive authored/random attribute and shield
guard line while retaining negative tradeoffs. Focused offline MCP script
diagnostics and diff hygiene pass; no runtime or suite was run.

## 2026-09-28T22:29Z — codex — correction
Owner clarified the intended change was more gear per chest/reward, not more
chests. Restored regular combat-room treasure frequency to its original 0.50;
kept item drop odds, multi-item thresholds, run-clear gear odds, and two vault
items. Updated tuning and known-issue text.

## 2026-09-28T22:40Z — codex — claim
Prepare the 0.3.19 main release for current gameplay/status changes; preserve local MCP and timed-hazard edits.

## 2026-09-28T22:40Z — codex — done
Aligned 0.3.19 across the in-game title and release documentation, preserved
the web Compatibility renderer override, and prepared the gameplay/status and
gear changes for release. Local MCP configuration and timed-floor planning
changes remain outside the release. No Godot runtime or suite was launched.

## 2026-09-28T22:51Z — codex — claim
Composition audit after 0.3.19 regressed root dynamic access by 26 sites and
GameplayState by 20 lines. Replace status-slice reflection with typed access
and move status-marker presentation fully into HudController.

## 2026-09-28T22:53Z — codex — done
Removed all 26 root dynamic accesses added by the status slice, routed status
ticks directly through the typed combat controller, and returned GameplayState
to 1,717 lines. The regression-floor and strict composition audits pass.
MCP script checks were disconnected; no Godot process was launched.
