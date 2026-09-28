# codex — status

_Only codex writes this file._

**Focus:** General game-development workbench foundation, with M1 enemy proof, pixel-art preview styling, and M4 room-prefab path
**Updated:** 2026-09-28

## In flight

Implemented explicitly disabled processing for all factory-created design-preview actors, plus `enemy_preview_lifecycle_smoke` for death-effect particle determinism, refresh cleanup, actor restoration, and preview close cleanup. Updated the authoring plan and current guide to define one shared workbench with content-kind adapters and to map room prefabs onto the actual runtime seam. The interactive preview contract now uses a separate process and unique temporary user-data directory because profile paths are static and web storage is shared. Roadmap calls out room-prefab loading as a composition goal. The custom enemy-preview canvas and geometry overlay now use the game's pixel-text renderer, nearest-neighbor filtering, a hard-edged palette frame, and crisp guide strokes. Corrected preview placement so all enemy families receive the configured position and scale. Preparing this slice for main with the required 0.3.10 version bump; manifest, UID, composition, script, and Web configuration preflights pass. The new smoke and live browser/export acceptance remain unverified.

## Blockers

The focused Godot runner did not reach the smoke: editor startup attempted restricted `user://` registry writes, emitted missing Healer animation-frame errors, and stalled; a direct standalone retry crashed when Godot could not open its user log. Per the repository rule, do not launch another Godot process after this crash in the current session. The smoke remains `unverified`; death-effect playback and editor save/refresh/geometry interactions remain visually unverified. The built-in Godot Inspector controls remain editor-native; pixel styling covers the custom preview surface and its overlays. Do not open a second editor or claim editor acceptance from script diagnostics.

## Handoff / next

After the Godot environment is safe again, run `enemy_preview_lifecycle_smoke`, inspect `Preview Death Effect`, and verify catalog refresh, save/reopen/refresh, geometry editing, and undo/redo. Next, implement the shared process-isolated `PreviewSession` boundary and one enemy launch payload; preserve that service for the M4 room-preview adapter. M4 must stage `RoomPrefabDefinition`/`RoomFactory` integration; the current main-scene shell, global `RoomDefinition` tuning, and four enum-derived socket IDs are not that system.
