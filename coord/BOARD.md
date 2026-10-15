# Claims

Active claims only. Remove your row when the work lands. Read this before
touching anything under another agent's claim.

| Agent | Paths / scenes | Intent | Since |
| --- | --- | --- | --- |
| codex persisted undo | scripts/content/enemy_catalog.gd, scripts/content/item_catalog_data.gd, tests/enemy_definition_catalog_lifecycle_smoke.gd, tests/item_preview_workbench_smoke.gd | Characterize dirty in-memory undo and UID-directory blockers; preserve persisted ownership snapshots across cache refresh | 2026-10-15 |
| codex recovery proof | tests/active_run_recovery_contract_smoke.gd, tests/enemy_preview_lifecycle_smoke.gd, scripts/services/profile_save_service.gd, P1 evidence docs and manifest rows | Recover and harden file/live restore and preview characterization; preserve real profiles and settings | 2026-10-15 |
| codex enemy CLI | tools/dev.ps1, tools/create_enemy_definition.gd, tools/preview_enemy.gd, scripts/content/enemy_catalog.gd, tests/enemy_definition_catalog_lifecycle_smoke.gd, reserved enemy fixture paths, resources/definitions/slime_variant_catalog.tres and generated manifests during focused checks | Characterize stale variant template/discovery and make documented creation immediately previewable with collision protection | 2026-10-15 |
| codex usability | resources/definitions/items/agent_probe_*.tres and matching UID, resources/generated/*definition_manifest.tres, temporary project.godot isolation, authoring evidence docs/status | Independent LOW item create/edit/preview/cleanup exercise; parent owns isolation and verification | 2026-10-15 |
| opencode | tests/run_all_smoke.ps1, .github/workflows/web-pages.yml | Fix release-gate integrity: optional sfx-lab venv must not red the gate; portability. CI coverage decision recorded by codex: keep Pages CI focused on validation plus web-export smoke; full gameplay smoke matrix remains an explicit local `tools/dev.ps1 verify` task. | 2026-09-27 |
