# codex — status

_Only codex writes this file._

**Focus:** Composition floor restored after 0.3.19 status integration; prepare the 0.3.20 correction release
**Updated:** 2026-09-28

## In flight

The elemental status source pass now includes four catalog-backed definitions,
actor-local status state, player/enemy proc and tick paths, slow/stun behavior,
HUD marks, and a typed-configured `ElementAuraComponent` shared with weapon
imbue overlays. Player death entry restores opaque modulation and the animation
component checks the configured `player_dead_get` callback before exposing the
player or attack sprite. Focused checks are registered but unrun.

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

The user redirected the active task to finish the elemental status plan and
implement its four statuses, while removing the chest and grayscale acceptance
premises. Source and docs now reflect current behavior; catalog validation,
registered owner checks, native-resolution readability, cloak/death rendering,
and web playtesting remain open. The user confirmed no magenta capture is
available. The editor is connected but no playtest is running; do not launch
another Godot process in this session.

## Current work

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
