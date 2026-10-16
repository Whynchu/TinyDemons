# Composition P1/P2 characterization

Status: acceptance partial; current review-branch evidence, 2026-10-15.

Owner: composition cleanup. Parent plan:
[composition cleanup](composition-cleanup-review-plan.md).

## Branch evidence boundary

The review branch previously linked to this report without containing it. This
batch recovered and hardened the stronger file-backed test from the separate
dirty primary checkout, then verified it in the review worktree. Historical
primary-worktree results do not establish acceptance here. This report records
the branch's actual evidence and remaining checks; no phase is advanced.

## Current focused evidence

| Surface | Result and limits |
| --- | --- |
| Family replacement | `encounter_definition_smoke` passes on Godot 4.7.2, 2026-10-15. It swaps Slime/Skeleton/Slime while preserving roster slot and sibling position, transform, actor caches, HUD and health callbacks, and family behavior wiring. Node names are not stable identity. |
| Shared brain | `enemy_brain_behavior_smoke` passes on 4.7.1 and 4.7.2. Authored boss Slime, directly authored Skeleton and factory actors bind their family components; shared targeting retains each preferred range. |
| Steering injection | `enemy_steering_world_smoke` passes on 4.7.1 and 4.7.2. It covers typed empty queries without a collision service, centered/non-centered actor geometry, walkability and the injected player without an ancestor search. |
| Definition persistence | `enemy_definition_slice_smoke` and `enemy_definition_roundtrip_smoke` pass on Godot 4.7.1, 2026-10-15. The latter reconstructs actors from stable IDs in memory; the separate recovery check covers disk and live restoration. |
| Room/profile recovery | `active_run_recovery_contract_smoke` passes on 4.7.1, 2026-10-15. It writes and reloads profile/checkpoint files in a unique application namespace, then drives live `RunFlowController.restore_active_run()`. It checks restored player health/Chroma and enemy position, health, Chroma budget and drops after deliberately disturbing live state. |
| Preview lifecycle | `enemy_preview_lifecycle_smoke` passes on 4.7.1, 2026-10-15, including transient actor lifecycle, unique PackedScene roundtrip, long-name first draw and bounded label widths. Enemy catalog and item workbench smokes also pass with dirty-draft undo/redo, external replacement guards and UID-directory blockers. Headless checks do not establish live editor undo history. |
| Definitions and guards | Definition validator passes 110/110 on 4.7.1. Composition self-test and strict audit, manifest validation (160 rows / 158 runnable / 45 gate), UID validation (469 sidecars), and diff checks pass. |
| Export | Fresh Web export passes with the standard Godot 4.7.1 build and installed matching template. An isolated native process launched the resulting 28,197,916-byte PCK outside the source worktree: 110 authored resources loaded, 74 item IDs were available, and Slime/Skeleton factory assembly passed. This native editor binary has the `editor` feature, so it does not prove the shipped runtime guard. Browser providers are unavailable; browser execution and exported MCP guard proof remain open. |
| Curated gate | Not run while the main MCP editor is active. R6+ elite support scaling and support-component checks now pass on 4.7.1 after an old-source failure. Elemental-binding teardown and two cloud-save presentation assertions remain open; see KNOWN_ISSUES. |

Focused processes ran in the review worktree with private logs and temporary
MCP runtime-autoload isolation; the original project configuration was restored.
The GUI editor remains attached to the primary worktree. Its runtime evidence
cannot be attributed to this branch.

## Remaining acceptance

1. Complete live editor create/edit/save/reopen and undo/redo acceptance; the
   focused headless lifecycle reruns pass but do not exercise real editor history.
2. Retain the recovery test's storage guards: desktop-only, unique resolved
   user-data directory, refusal of occupied paths, owned-slot cleanup and
   restoration of project settings and active slot. The focused run needed
   filesystem escalation for this disposable namespace. No real profile was
   used; the previously checked namespace was absent after cleanup.
3. Exercise the Web artifact in a browser and verify exported development
   tooling opens no MCP runtime socket. The packaging probe temporarily restored
   the committed Compatibility override, disabled plugins and removed the MCP
   autoload, then restored the original configuration bytes. It therefore does
   not prove the default export plugin or runtime guard. The earlier Mono build
   refused Web export; the official standard build's published SHA256 was
   checked before use.
4. Run the curated gate as a supervised standalone step with no MCP editor or
   runtime active, after relevant failures are repaired.

Mixed-encounter performance acceptance remains owner-deferred in the parent
plan. No historical Run 30 measurement is presented as current-source proof.
Human editor, input and visual acceptance remains separate from headless checks.
