# Documentation Audit

Status: current classification policy; inventory refresh pending

Audit date: 2026-09-11

Current baseline: version `0.2.00`; see [`AUDIT.md`](AUDIT.md) for the source
audit and preservation contract.

## Purpose

The repository contains a large amount of useful design and implementation
history. It also contains multiple plans for the same systems. This audit
identifies which documents should guide current work and which should be
treated as historical context.

The goal is not to delete documentation immediately. Historical decisions can
be valuable, especially for save compatibility, balance rationale, and visual
contracts. The goal is to prevent an engineer from following an obsolete plan
by accident.

## Canonical Reading Order

These documents should remain the primary navigation and decision surface:

1. `README.md` - project entry point and verification.
2. `AGENTS.md` - contributor rules, ownership, and safety constraints.
3. `docs/production-boundary.md` - project boundary and baseline.
4. `docs/runtime-map.md` - current runtime and repository map.
5. `docs/FEATURE_MAP.md` - feature ownership index.
6. `docs/ARCHITECTURE.md` - runtime ownership and extension guide.
7. `docs/AUDIT.md` - current findings and phase register.
8. `docs/refactor-route.md` - accepted refactor execution route.
9. `docs/GAMEPLAY_TUNING.md` - designer-facing balance index.
10. `docs/vertical-slice-analysis.md` - traced runtime/save flows.
11. `docs/asset-reference-audit.md` - asset classification.
12. `docs/dynamic-dependency-audit.md` - hidden dependency measurements.
13. `docs/ROADMAP.md` - active product and infrastructure sequence.
14. `docs/KNOWN_ISSUES.md` - current behavior and verification register.
15. `docs/CONTENT_AUTHORING.md` - repeatable content workflows.
16. `docs/engineering-friction-audit.md` - prioritized engineering findings.

If another document conflicts with this set, the conflict should be resolved in
the canonical set before implementation proceeds.

The current canonical set is:

- `README.md`, `AGENTS.md`, and `docs/DOCUMENTATION_MAP.md` for navigation and
  contributor rules;
- `docs/AUDIT.md`, `docs/ROADMAP.md`, and `docs/KNOWN_ISSUES.md` for baseline,
  sequence, and live verification state;
- `docs/CONTENT_AUTHORING.md`, `docs/ARCHITECTURE.md`,
  `docs/FEATURE_MAP.md`, and `docs/runtime-map.md` for ownership and extension;
- `docs/GAMEPLAY_TUNING.md` and `docs/project_direction.md` for design-facing
  intent; and
- `docs/production-boundary.md`, `docs/VERSIONING.md`, and the web/save plans
  for shipping and compatibility constraints.

These names are case-sensitive in links and exports. Use the existing
lowercase `project_direction.md` filename; do not introduce an uppercase
case-only duplicate.

## Classification Rules

### Current authority

Documents that describe the current implementation, ownership, or accepted
engineering process. These should be kept accurate.

Examples:

- `AUDIT.md`
- `ARCHITECTURE.md`
- `refactor-route.md`
- `GAMEPLAY_TUNING.md`
- `gear-system-rework.md`
- `elemental-binding-and-fusion-design.md`
- `generated-r7-route-validation.md`
- `production-boundary.md`
- `runtime-map.md`

### Active implementation plan

Documents describing work that is approved but not necessarily complete. They
must have an explicit owner, status, and verification section.

Examples:

- `web-run-recovery-plan.md`
- `web-port-implementation-plan.md`
- `r7-compact-roguelike-puzzle-generator-plan.md`
- `responsive-menus-touch-and-progression-safety-plan.md`
- `demon-hub-menu-navigation-plan.md`

### Completed implementation handoff

Documents whose code is substantially implemented but whose design rationale or
verification history remains useful.

Examples:

- `elemental-slimes-and-combat-plan.md`
- `elemental-binding-and-fusion-implementation-plan.md`
- `composition-root-r1-checkpoint.md`
- `generated-r7-route-validation.md`

These should be relabeled clearly as `implemented`, with a link to the current
owner and current tests.

### Historical or superseded

Documents that explicitly say their route is superseded or describe a prior
branch/baseline.

Examples:

- `script-consolidation-plan.md`
- `composition-root-r0-inventory.md`
- `composition-root-2000-milestone.md`
- `composition-root-reduction-plan.md` once its remaining route is folded into
  `AUDIT.md` and `refactor-route.md`.

These should remain available for rationale, but should not appear in the first
three documents an engineer reads for current work.

### Reference/provenance

Documents that explain source material, licensing, visual references, or
external research rather than runtime authority.

Examples:

- `asset-provenance.md`
- `kh_system_sfx_reference_atlas.md`
- `sfx_analysis_to_production_toolchain.md`
- `procedural_sfx_reconstruction_plan.md`
- `Tiny Demons — Elemental Chroma System Design.md`

These should be linked from the relevant current design but not treated as
implementation ownership documents.

## Current inventory

### Canonical and maintained

`AUDIT.md`, `ARCHITECTURE.md`, `CONTENT_AUTHORING.md`,
`DOCUMENTATION_MAP.md`, `FEATURE_MAP.md`, `GAMEPLAY_TUNING.md`,
`KNOWN_ISSUES.md`, `ROADMAP.md`, `VERSIONING.md`, `documentation-audit.md`,
`dynamic-dependency-audit.md`, `engineering-friction-audit.md`,
`production-boundary.md`, `runtime-map.md`, `test-target-audit.md`, and
`vertical-slice-analysis.md`.

### Active plans or open implementation handoffs

`current-issues-and-resolution-plan.md`, `durable-save-and-cloud-sync-plan.md`,
`elemental-chroma-implementation-plan.md`,
`generated-route-audit.md`, `repo-analysis-plan.md`,
`responsive-menus-touch-and-progression-safety-plan.md`,
`web-port-implementation-plan.md`, and any implemented handoff that still has
an open runtime, browser, touch, or performance verification item.

### Implemented feature references

`boss-slime-implementation-plan.md`, `demon-hub-menu-navigation-plan.md`,
`elemental-binding-and-fusion-design.md`,
`elemental-binding-and-fusion-implementation-plan.md`,
`elemental-slimes-and-combat-plan.md`, `equipment-menu-rework-plan.md`,
`ffiii-inspired-stats-and-menu-implementation-plan.md`,
`generated-fusion-gate-inspection.md`,
`generated-r7-route-validation.md`, `gear-catalogue-implementation-plan.md`,
`modular-display-and-settings-plan.md`, `r7-compact-roguelike-puzzle-generator-plan.md`,
`r8-origin-aware-progression-implementation-plan.md`,
`run-results-screen-plan.md`, `run1-dungeon-map-implementation-plan.md`, and
`spin-and-charge-attacks-plan.md`.

These documents should retain their rationale but should identify the current
owner and verification path when reopened. An “implemented” label does not
erase remaining device or runtime evidence gaps.

### Historical or superseded

`composition-root-2000-milestone.md`, `composition-root-r0-inventory.md`,
`composition-root-r1-checkpoint.md`, `composition-root-reduction-plan.md`,
`meta_progression_implementation_plan.md`, `next-phase-plan.md`,
`script-consolidation-plan.md`, and `speed_stat_design.md`.

The authored R1–R5 design and implementation documents remain useful content
contracts even when their implementation stage is complete. The R3/R4/R5
documents should carry explicit run scope before future edits.

### Design, proposal, or reference material

`asset-provenance.md`, `asset-reference-audit.md`,
`combat-economy-overhaul.md`, `dialogue_shop_concept.md`,
`enemy-matchup-progression-plan.md`, `gear-catalogue.md`,
`gear-catalogue-spec.md`, `gear-drop-tables.md`, `gear-effect-contracts.md`,
`gear-economy-progression-implementation-plan.md`, `gear-system-rework.md`,
`hub-menu-visual-display-contract.md`, `meta_progression_design.md`,
`procedural-dungeon-design.md`, `procedural_sfx_reconstruction_plan.md`,
`project_direction.md`, `r3-puzzle-map-generator-plan.md`,
`r4-puzzle-map-implementation-plan.md`, `run1-dungeon-map-design.md`,
`soul-economy-and-fire-exchanges.md`, `Tiny Demons — Elemental Chroma System Design.md`,
`cloud-save-deployment.md`, `fusion-bind-menu-handoff.md`,
`menu-ui-migration-plan.md`, and the SFX/reference documents.

These documents are not automatically inactive. Their status must be decided
from the current product direction and linked implementation owner before
they guide new work.

## Overlap Clusters

### Composition/refactor cluster

Documents:

- `AUDIT.md`
- `ARCHITECTURE.md`
- `refactor-route.md`
- `script-consolidation-plan.md`
- `composition-root-reduction-plan.md`
- `composition-root-r0-inventory.md`
- `composition-root-r1-checkpoint.md`
- `composition-root-2000-milestone.md`

Decision: `AUDIT.md` and `refactor-route.md` are current authority. Keep
architecture ownership in `ARCHITECTURE.md`. Mark the remaining composition
documents historical/checkpoint material and link forward to the canonical
route.

### Elemental/Chroma cluster

Documents:

- `elemental-binding-and-fusion-design.md`
- `elemental-binding-and-fusion-implementation-plan.md`
- `elemental-chroma-implementation-plan.md`
- `elemental-chroma-handoff.md`
- `Tiny Demons — Elemental Chroma System Design.md`
- `soul-economy-and-fire-exchanges.md`

Decision: the binding/fusion design is the player-facing contract. The
implementation plans and handoff should point to current owners/tests and be
marked implemented or historical where appropriate.

### Dungeon/puzzle cluster

Documents:

- `procedural-dungeon-design.md`
- `run1-dungeon-map-design.md`
- `run1-dungeon-map-implementation-plan.md`
- `r3-puzzle-map-generator-plan.md`
- `r4-puzzle-map-implementation-plan.md`
- `r7-compact-roguelike-puzzle-generator-plan.md`
- `generated-r7-route-validation.md`
- `generated-fusion-gate-inspection.md`
- `r8-origin-aware-progression-implementation-plan.md`

Decision: preserve authored-run design documents as historical/content
contracts. Current generated-route authority is `puzzle_route_generator.gd`
and the R7 validation document. Add explicit run/version scope to each plan so
R3/R4/R5 authored contracts are not confused with R7+ generation.

### Gear/progression cluster

Documents:

- `gear-system-rework.md`
- `gear-catalogue.md`
- `gear-catalogue-spec.md`
- `gear-catalogue-implementation-plan.md`
- `gear-economy-progression-implementation-plan.md`
- `gear-drop-tables.md`
- `gear-effect-contracts.md`
- `combat-economy-overhaul.md`

Decision: `gear-system-rework.md` and `gear-effect-contracts.md` describe the
current simplified model. Older catalogue plans should be compatibility and
design history unless they are explicitly reopened.

### Menu/display cluster

Documents:

- `menu-ui-migration-plan.md`
- `demon-hub-menu-navigation-plan.md`
- `hub-menu-visual-display-contract.md`
- `equipment-menu-rework-plan.md`
- `fusion-bind-menu-implementation-plan.md`
- `modular-display-and-settings-plan.md`
- `responsive-menus-touch-and-progression-safety-plan.md`

Decision: keep visual contracts and active platform requirements. Mark plans
whose implementation is complete and link to the owning scripts/tests.

## Conflicts To Resolve

1. Some older plans describe systems as missing even though current scripts and
   tests implement them. Example: older elemental and combat plans should not
   be used as current gap lists without checking `AUDIT.md`.
2. Composition documents use different historical line-count baselines and
   branch names. Current measurements belong in `AUDIT.md`.
3. Puzzle documents span authored pixel contracts and procedural generation.
   Their run scope must be explicit.
4. Several implementation plans have no clear owner or completion date. An
   unowned plan should not be treated as approved work.
5. Design documents sometimes identify images as the source of truth while the
   runtime has moved to typed catalogs or compiled layouts. The current data
   owner must be named.

## Recommended Consolidation Work

Do not merge documents by copying content immediately. Use this sequence:

1. Add a standard header to active plans:

   ```text
   Status:
   Scope:
   Owner:
   Current code:
   Verification:
   Supersedes:
   ```

2. Add a one-paragraph current-state note to implemented plans.
3. Add forward links from historical documents to the canonical authority.
4. Move only genuinely obsolete drafts to `docs/history/` in a separate cleanup
   change after references are checked.
5. Do not delete design rationale that explains shipped save or gameplay
   compatibility.

## Safe Immediate Actions

- Keep the current canonical reading order in `AGENTS.md` and `runtime-map.md`.
- Add status/scope headers to new plans.
- Mark `script-consolidation-plan.md` explicitly historical, as it already
  states its route is superseded.
- Add run scope to R3/R4/R5/R7/R8 puzzle documents.
- Record implementation status and current tests on active handoff documents.
- Avoid broad documentation moves until runtime ownership and active worktree
  changes are stable.
