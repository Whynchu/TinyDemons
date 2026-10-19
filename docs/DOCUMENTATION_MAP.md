# Tiny Demons documentation map

Status: current navigation and document lifecycle guide

Updated: 2026-10-17

## Start with the task

Read [AGENTS.md](../AGENTS.md) for contributor rules and
[FEATURE_MAP.md](FEATURE_MAP.md) for the feature owner. Inspect that source,
then consult the relevant authority below. This is a lookup page, not a reading list.

| Task | Start here |
| --- | --- |
| Understand or extend runtime behavior | [Architecture](ARCHITECTURE.md), [symbol index](SCRIPT_INDEX.md) |
| Understand composition status or remaining exceptions | [Composition status](COMPOSITION_STATUS.md) |
| Add or edit content | [Content authoring](CONTENT_AUTHORING.md); read the linked data traps |
| Run or verify a change | [Contributor commands](CONTRIBUTOR_README.md), [verification roles](verification-surface-audit.md), `tests/manifest.csv` |
| Choose product work or inspect a known failure | [Roadmap](ROADMAP.md), [known issues](KNOWN_ISSUES.md) |
| Understand design or balance | [Design wiki](wiki/README.md), [tuning](GAMEPLAY_TUNING.md) |

## Composition records

[COMPOSITION_STATUS.md](COMPOSITION_STATUS.md) is the execution entry point.
The [component contract](component-composition-design.md) defines reusable
behavior. Older plans, inventories, and extraction histories are supporting
records linked from the status page; their unchecked boxes do not automatically
schedule work. Source and dated verification evidence take precedence over
stale summaries and proxy scores.

## Authority by question

| Question | Authority | Use supporting material for |
|---|---|---|
| What is the player-facing feel and feedback direction? | [`../JUICE.md`](../JUICE.md) | pickup delivery, HUD reactions, menu motion, touch response, and audio hierarchy |
| How healthy is the codebase (composition, efficiency, practicality, folder flow)? | [`repo-review-2026-10-01.md`](repo-review-2026-10-01.md) for the scored review and its current reconciliation | [`AUDIT.md`](AUDIT.md) for current source measurements |
| What exists right now? | [`AUDIT.md`](AUDIT.md) | traced flows and source files |
| Where should a feature go? | [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`FEATURE_MAP.md`](FEATURE_MAP.md) | implementation details |
| What is the current composition direction? | [`COMPOSITION_STATUS.md`](COMPOSITION_STATUS.md) | historical checkpoints in [`refactor-route.md`](refactor-route.md) |
| What is the player-facing direction? | [`project_direction.md`](project_direction.md) and the current feature design | proposals and rationale |
| What is the whole-game design (concept, pillars, systems, 1.0 direction)? | [`game-design-document.md`](game-design-document.md) | subsystem design docs and [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) for numbers |
| Where are balance values? | [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) | tuning plans and design notes |
| What is the current dungeon/content contract? | The relevant generator or layout definition ([`procedural-dungeon-design.md`](procedural-dungeon-design.md), [`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md)) | [`runtime-map.md`](runtime-map.md) — historical map only |
| What is the approved R6+ generation direction? | [`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md) | compact-generator implementation history and tuning evidence |
| What must remain compatible in saves and exports? | [`production-boundary.md`](production-boundary.md), save plans, and [`VERSIONING.md`](VERSIONING.md) | migration history |
| How is a change verified? | [`README.md`](../README.md), [`gameplay-smoke-checklist.md`](gameplay-smoke-checklist.md), and `tests/manifest.csv` | focused test reports |
| What work is next? | [`ROADMAP.md`](ROADMAP.md) | [`authoring-system-plan.md`](authoring-system-plan.md) and feature plans |
| What is currently unresolved? | [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | the detailed issue tracker |
| Should a test exist or block release? | [`verification-surface-audit.md`](verification-surface-audit.md) | target and runtime evidence |
| How do I add content? | [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) | the trap register in [`authoring-system-plan.md`](authoring-system-plan.md) |
| Where do source art, runtime assets, and authored resources live? | [`CONTENT_FOLDERS.md`](CONTENT_FOLDERS.md) | [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) for editing workflow |
| How do I make content and feature work cheap? | [`authoring-system-plan.md`](authoring-system-plan.md) | source-backed audits in this map |
| What makes a change difficult? | [`engineering-friction-audit.md`](engineering-friction-audit.md) | source files and detailed audits |

| What is the component contract for reusable entity behavior? | [`component-composition-design.md`](component-composition-design.md) | wiring rules, adapter refinement, and the interchangeable-entity proof |

| Where are scripts organized by role? | [`script-role-map-2026.md`](script-role-map-2026.md) | per-file destination, role definitions, resolved assignment decisions |
| What is the long-term modularity and performance direction? | [`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md) | content definitions, runtime composition, authoring workflows, and device-backed performance work |
| What is the end-to-end performance execution plan? | [`peak-performance-plan.md`](peak-performance-plan.md) | boot/menu gates, capture scenarios, lifecycle separation, runtime budgets, and A17 verification |
| How do we fix 2–5 FPS in a dense mixed-enemy room? | [`mixed-encounter-performance-correction-plan.md`](mixed-encounter-performance-correction-plan.md) | Run 30 reproduction, timing caveats, ordered source changes, and whole-scene acceptance gates |
| Which gameplay and rendering systems currently cost time, and what practices reduce their work? | [`performance-cost-guide.md`](performance-cost-guide.md) | measured editor scopes, source-based suspects, subsystem owners, and cost-preserving approaches |
| What is the current target HUD and touch-polish contract? | [`ui-consistency-and-touch-polish-plan.md`](ui-consistency-and-touch-polish-plan.md) | target health geometry, map footer anchoring, and shop row hitboxes |
| What is the popup hold and pause Debug menu plan? | [`popup-and-debug-menu-plan.md`](popup-and-debug-menu-plan.md) | four-update floating-text hold, Settings opt-in, run/player cheats, and safe debug-session boundaries |
| What are the current combat and dungeon design principles? | [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md) | feature-specific plans and tuning values |
| Which product and design questions remain unresolved? | [`design-philosophy-interview-questionnaire.md`](design-philosophy-interview-questionnaire.md) | current design authorities and interview decision records |
| What is the ratified design contract? | [`design-interview-record-2026-09-18.md`](design-interview-record-2026-09-18.md) | feature-specific plans and tuning values |
| How should elemental abilities, statuses, and auras be built? | [`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md) | component contract, design principles, and the authoring plan |
| What is the player's Triangle spell (forms, binding, per-element behavior)? | [`elemental-spell-forms-plan.md`](elemental-spell-forms-plan.md) | [`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md) for the shared status pipeline |
| How do innate element affinity, status suppression, contact transmission, and synergy room generation work? | [`elemental-affinity-and-transmission-plan.md`](elemental-affinity-and-transmission-plan.md) | [`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md) for the existing status pipeline |
| Which elements spawn as the campaign advances? | [`elemental-theme-progression-separation-design.md`](elemental-theme-progression-separation-design.md) | difficulty rank controls pressure, while run number controls elemental content |
| What happens when Wet and Chill are on the same actor? | [`freeze-status-design.md`](freeze-status-design.md) | the single authored WATER + ICE status mixture |
| What is the proposed Idle Mode and equipment-quality feature? | [`idle-mode-and-equipment-quality-plan.md`](idle-mode-and-equipment-quality-plan.md) | source-backed feasibility, ownership, acceptance slices, and open design decisions |
| What are the stat allocation limits and how do its bars work? | [`anchored-stat-allocation-proposals.md`](anchored-stat-allocation-proposals.md) | selected Model C, legacy repair, shared anchor feedback, and acceptance evidence |

## Document lifecycle

- **Current guide/contract:** describes ownership, behavior, or rules. Update it
  when those change; prefer updating an existing authority to adding another.
- **Active plan:** approved, bounded work with an owner and acceptance criteria.
- **Supporting record/backlog:** evidence and candidate work; not a standing task.
- **Historical:** completed or superseded work, retained for decisions and compatibility.

Plans should state status, scope, owner, current code, verification, and what
they supersede. Date measurements and distinguish implemented, accepted, tested,
and committed. Do not copy live status into several documents.

Before retiring a document, preserve unique decisions in the relevant authority
and check inbound links. Historical records can stay at stable paths; moving a
file is useful only if navigation improves. Generated indexes and evidence
inventories are lookup tools, not required reading. Refresh the script index
when scripts move; ordinary documentation changes need no Graphify rebuild.

## Specialist references

- [Agent advisors](agent-workflow.md): use a specialist for a bounded question.
- [Review package](review/00-astra-review-index.md): external product/design review.
- [Graphify integration](graphify-godot-integration-plan.md) and
  [language completion record](graphify-gdscript-completion-plan.md): tooling work.
- [Content folders](CONTENT_FOLDERS.md): source art, runtime assets, and resources.
