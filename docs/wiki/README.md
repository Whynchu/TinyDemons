# Tiny Demons Design Wiki

Status: current navigation and design-reference layer

Owner: design/product, with technical ownership linked to the codebase

The wiki helps people and agents understand what Tiny Demons is, how its rules
fit together, and where each decision is maintained. It is versioned with the
game in this repository so design and implementation can be reviewed together.

This is a **map and explanation layer**, not a replacement for the detailed
design, implementation, tuning, and audit documents in `docs/`. Each page links
to its authority. When a wiki summary and an owning spec disagree, follow the
owning spec and correct the summary.

The browsable static site lives in `wiki-site/` and reads the Markdown pages
below. Build it with `pwsh -NoProfile -ExecutionPolicy Bypass -File
tools/build_design_wiki.ps1`; the default output is `dist/wiki/`. When included
in the web Pages artifact, its URL is `/TinyDemons/wiki/` alongside the game.

## Start here

- [Game at a glance](game-at-a-glance.md) — premise, pillars, player loop, and
  clear links to what is shipped versus planned.
- [Systems map](systems-map.md) — gameplay systems, design questions, and the
  current authority for each.
- [Visual references and experiments](visuals-and-experiments.md) — screenshot
  standards and how browser-only feature sketches can fit beside the game.
- [Feature brief template](feature-brief-template.md) — a consistent format for
  proposing and reviewing new design work.
- [Wiki maintenance](maintenance.md) — status labels, sourcing, screenshots, and
  how to keep pages useful instead of duplicating docs.

## Design authorities

- [Whole-game design document](../game-design-document.md)
- [Design principles and combat economy](../combat-and-dungeon-design-principles.md)
- [Roadmap](../ROADMAP.md)
- [Gameplay tuning index](../GAMEPLAY_TUNING.md)
- [Documentation authority map](../DOCUMENTATION_MAP.md)
- [Architecture and script ownership](../ARCHITECTURE.md)

The repo's [authoring system plan](../authoring-system-plan.md) and
[architecture guide](../ARCHITECTURE.md) remain the implementation authorities
for content and runtime ownership.
