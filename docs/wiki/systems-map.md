# Systems map

This page is a design index. It does not restate all rules: each topic links to
the document that owns its current details.

| Topic | Start with | Implementation / truth source |
| --- | --- | --- |
| Core loop, pillars, shipped vs target design | [Game design document](../game-design-document.md) | [Audit](../AUDIT.md), [roadmap](../ROADMAP.md) |
| Combat, focus, combos, impact | [Combat and dungeon principles](../combat-and-dungeon-design-principles.md) | [Gameplay tuning](../GAMEPLAY_TUNING.md), [architecture](../ARCHITECTURE.md) |
| Elements, binding, fusion | [Element binding and fusion](../elemental-binding-and-fusion-design.md) | [Element catalog](../../scripts/element_catalog.gd), [tuning](../GAMEPLAY_TUNING.md) |
| Spells and statuses | [Elemental ability and status system](../elemental-ability-and-status-system.md) | [Status implementation plan](../elemental-status-implementation-plan.md), [architecture](../ARCHITECTURE.md) |
| Enemy roles and encounters | [Elemental slimes and combat](../elemental-slimes-and-combat-plan.md) | [Content authoring guide](../CONTENT_AUTHORING.md), [enemy definitions](../../resources/definitions/) |
| Dungeon routes and room generation | [Procedural dungeon design](../procedural-dungeon-design.md) | [Runtime map](../runtime-map.md), [dungeon definitions](../../resources/definitions/) |
| Gear, drops, and economy | [Gear catalogue spec](../gear-catalogue-spec.md) | [Gear catalogue](../gear-catalogue.md), [drop tables](../gear-drop-tables.md) |
| Meta progression | [Meta progression design](../meta_progression_design.md) | [Gameplay tuning](../GAMEPLAY_TUNING.md), [known issues](../KNOWN_ISSUES.md) |
| Touch and responsive menus | [Mobile touch plan](../mobile-touch-button-and-haptics-plan.md) | [Architecture](../ARCHITECTURE.md), [web port plan](../web-port-implementation-plan.md) |
| Sound and music | [SFX production toolchain](../sfx_analysis_to_production_toolchain.md) | [Sound reference atlas](../kh_system_sfx_reference_atlas.md), [asset provenance](../asset-provenance.md) |

## How to read a feature page

For a feature, identify four things before proposing a change:

1. The player-facing promise and intended feeling.
2. The rules and constraints that define it.
3. The code/content owners named by the architecture or authoring guide.
4. What evidence would show the behavior works at gameplay scale.

If a row's linked sources disagree, the source that explicitly owns that topic
takes precedence. Update this map when ownership moves.
