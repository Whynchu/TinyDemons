# Script Role Migration: Reference Audit

**Status:** Migration executed; static validation passed. Godot-backed definition
and gameplay gates remain pending while the editor session is active.
**Baseline:** 2026-10-04, composition plan Stage 1.

## Baseline inventory

- `scripts/` contained 235 tracked `.gd` files and 235 matching `.gd.uid`
  sidecars in one flat directory.
- The pre-migration search found 572 literal `res://scripts/` references across
  260 files. This included live references, generated indexes, and documentation.
- UID sidecars were moved with their scripts, preserving all 235 UID values.

## Migration outcome

- All 235 scripts were moved according to `docs/script-role-map-2026.md`; no
  scripts remain directly under `scripts/`.
- 566 live literal script-path references across 256 files were rewritten.
  Historical documentation and the role map's original-path column retain old
  paths intentionally.
- `tools/generate_script_index.ps1` now scans recursively, and
  `docs/SCRIPT_INDEX.md` was regenerated with 235 script entries.
- The composition baseline paths and role allowlist now match the migrated
  structure. `services/` is the role for boot-instantiated shared services;
  runtime scripts are divided into five responsibility folders.
- UID validation exposed a pre-existing stale UID in the four room-prefab
  resources. Their script paths were already correct; their UID fields now
  match the preserved sidecar UID for `room_prefab_definition.gd`.
- No gameplay behavior changes were made.

## Static verification

- Map reconciliation: 235 of 235 sources assigned, 0 duplicate assignments,
  0 duplicate destinations, 0 missing targets, 0 root-level scripts, and 235
  matching UID sidecars.
- Composition validator: default and strict modes pass; 235 scripts across 13
  directories, 0 unclassified scripts, and no flat root directory.
- Composition validator self-test passes.
- Godot UID validator passes with 390 script/test sidecars total, including
  235 under `scripts/`, and no duplicate or mismatched script IDs.
- Test-manifest validator passes: 155 rows, 153 runnable entries, and 2 report
  entries.
- The generated index contains 235 scripts; `git diff --check` passes.

The Godot definition validator and curated gameplay gate have not been run.
The repository's active-editor restriction forbids starting another Godot
process, and no editor MCP controls are available in this session. Run these
checks after the active editor session is available for verification.

## Scope and coordination

The approved role map and Stage 1 plan define the assignment rules and migration
acceptance bar. The migration was performed as a single-writer slice, as
required because references cross the repository. This audit records path and
UID reconciliation; it does not authorize behavioral refactoring.
