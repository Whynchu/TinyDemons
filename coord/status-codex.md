# codex — status

_Only codex writes this file._

**Focus:** Game-development workbench foundation, M1 enemy preview verification, and M4 room-prefab path
**Updated:** 2026-09-28

## In flight

The healer support adjustment is implemented and statically checked. Preparing its 0.3.11 release with the matching in-game, README, and version-index updates so a push to `main` triggers the Pages build/deploy. After the playtest build is published, continue the open M1 editor acceptance and isolated `PreviewSession` work. No Godot process may be launched this session after the earlier standalone crash.

## Blockers

The focused Godot runner did not reach the prior workbench smoke: editor startup attempted restricted `user://` registry writes, emitted missing Healer animation-frame errors, and stalled; a direct standalone retry crashed when Godot could not open its user log. Per the repository rule, do not launch another Godot process after this crash in the current session. Do not open a second editor or claim editor acceptance from script diagnostics.

## Handoff / next

After the release push, resume M1: editor acceptance for refresh/save/reopen/geometry/death-preview/undo-redo, then the isolated interactive `PreviewSession` and remaining lifecycle checks. Godot visual/runtime acceptance must wait until the environment is safe again.
