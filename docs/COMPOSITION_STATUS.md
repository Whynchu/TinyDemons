# Composition status and closeout

Status: current composition navigation and remaining-work summary

Updated: 2026-10-17

Scope: ownership, reusable capabilities, and the context needed to extend the game.
This page supersedes older composition plans as the execution entry point;
it preserves their decisions and evidence without renewing their entire queues.
The [component contract](component-composition-design.md) remains the design authority.

## Working foundation

- Explicit scheduling: `gameplay_frame_controller.gd` orders runtime updates.
- Typed definitions and factories: `EnemyDefinition`, `EnemyCatalog`, and
  `EnemyFactory` provide the existing enemy authoring and assembly path.
- Shared identity: Slime and Skeleton are sibling `EnemyActor` types;
  `EnemyRoster` owns ordered membership and slot identity.
- Shared decision host: `EnemyBrain` takes an injected `EnemySteeringWorld`;
  family behavior components supply range and approach rules. P3 was accepted
  by the owner on October 14. Its focused smoke evidence is separately open.
- Role folders, feature owners, typed room boundaries, and extracted menu
  presenters already exist. Do not repeat those migrations.
- Shared `MenuWindow` skin and `MenuScreen` shell compose menu rectangles;
  authored Hub/Pause-command/Equipment geometry is preserved. Status and Items
  use the complete shell; the main title screen keeps its splash. Presenters retain input
  and actions. Script diagnostics pass; rendered/input acceptance of the
  October 18 migration remains pending. See [menu authoring](CONTENT_AUTHORING.md#adding-menu-content).

These statements reflect inspected source and recorded acceptance, not a new
whole-project verification run or a claim that every component meets the contract.

## How to extend it

Start at [FEATURE_MAP](FEATURE_MAP.md), then read the owner and its callers.
Use [ARCHITECTURE](ARCHITECTURE.md) for boundaries and
[CONTENT_AUTHORING](CONTENT_AUTHORING.md) for consumed data and workflow traps.

A useful change has an obvious owner, explicit inputs, locally owned state,
and focused verification. Reusable capabilities receive typed dependencies;
family-specific behavior stays with its family. Extract only when a real
consumer or extension need demonstrates the benefit. More files, generic names,
and lower line counts are not acceptance criteria by themselves.

## Remaining exceptions and evidence

| Area | Current limitation | When to act / evidence owner |
| --- | --- | --- |
| Enemy runtime | `SlimeRuntimeController` still includes shared lifecycle and Skeleton-specific movement/projectile/render behavior; some shared components retain historical `slime_*` paths. | Narrow a concrete capability when extending it. Preserve timing and geometry. [Extraction ledger X09](composition-extraction-ledger.md) records details. |
| Shared runtime state | `GameplayState`, root access, and compatibility facades remain alongside typed boundaries. | Move behavior and state together when a feature exposes an ownership problem; avoid a replacement global context. [Architecture](ARCHITECTURE.md). |
| Catalog compatibility | `EnemyCatalog` owns the generic API; historical catalog/resource identities remain compatible. | Remove adapters only after consumers, saved resources, and exports are accounted for. [Content authoring](CONTENT_AUTHORING.md). |
| Other content kinds | Item/element/room authority is not uniformly migrated; some authored fields have no runtime consumer. | Follow the relevant content task and trap register. [Authoring plan](authoring-system-plan.md). |
| Editor lifecycle | Enemy authoring works. Saved-resource lifecycle, actual pointer drag, and reliable rendered-palette evidence remain open in the latest handoff. | Close checks when needed for editor changes or acceptance; do not describe the workflow as unimplemented. [M1 plan](authoring-system-plan.md). |
| Verification | P1/P2 current-source acceptance and rebuilt-Web runtime proof remain open; P3 acceptance does not imply its focused smokes passed. The latest recorded curated run was not clean. | Use `tests/manifest.csv`, [known issues](KNOWN_ISSUES.md), and the detailed [P1](composition-p1-characterization.md)/[P3](composition-p3-family-brain-behavior.md) evidence. Follow MCP-first rules. |

## Closeout rules

1. Keep this short summary current when an exception is resolved; put detailed
   evidence in its existing owner document or test manifest.
2. Preserve existing working-tree changes and distinguish source present,
   owner accepted, checks passed, and committed. None implies the others.
3. Do not resume broad decomposition, folder migration, or asset retirement
   from an old checklist. Select one demonstrated obstacle and define its end.
4. Preserve unique decisions and compatibility evidence when retiring docs;
   repair links before moving or deleting files.

## Supporting records ? consult only when needed

- [Cleanup review](composition-cleanup-review-plan.md): P0 inventory and P1?P7
  proposal/acceptance history. Later phases are a backlog, not an automatic sequence.
- [Extraction ledger](composition-extraction-ledger.md): dated source observations
  and candidate follow-ups, not an additional execution plan.
- [2026 composition plan](composition-plan-2026.md): guardrail, role-folder,
  helper and menu extraction history; remaining targets need a concrete task.
- [Legacy refactor analysis](composition-refactor-analysis.md),
  [refactor route](refactor-route.md), and [role migration map](script-role-map-2026.md):
  historical records retained at stable paths for existing links.

Documentation consolidation does not close outstanding runtime verification.
