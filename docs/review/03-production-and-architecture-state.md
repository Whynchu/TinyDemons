# Production and Architecture State

## What the refactor achieved

The legacy-coupling refactor is complete under the repository’s strict scorecard. Components own focused state and behavior, controllers coordinate feature boundaries, and the explicit frame schedule remains centralized. Typed contexts and results replaced the most dangerous transitional seams.

The project is therefore ready to move from structural cleanup toward content composition and production throughput.

## Remaining production bottlenecks

- Some large coordinators still combine presentation, workflow, and compatibility responsibilities.
- Enemy content now has a typed catalog/factory path, but room and the other
  content kinds are not yet fully definition/factory driven.
- Content authoring is improving but still requires technical coordination in places.
- Performance budgets are documented but not yet proven on a Samsung A17.
- The curated smoke gate is meaningful, but full behavioral confidence still depends on focused tests and supervised release verification.

## Best next engineering proof

Finish the enemy proof's preview and fresh data-only acceptance with one
additional enemy sharing the existing component architecture and requiring zero
central-runtime edits. Then apply the same pattern to room and dungeon
definitions.

## Review boundaries

Astra should not recommend another broad rewrite merely because some files are large. Judge architecture by feature ownership, authoring speed, testability, and risk. Line count is evidence, not an objective.

## Performance review boundary

Do not prescribe renderer or pooling changes without identifying a measured scenario. Prioritize measurement of title, Hub, ordinary rooms, dense combat, boss combat, transitions, effects, menus, web export, and touch input on modest hardware.
