# Tiny Demons Documentation Map

Status: current navigation guide for the `0.2.x` cycle

Updated: 2026-09-22

The repository contains design history, implementation handoffs, audits, and
active plans. Use this page to choose the right authority before changing code.
The baseline being preserved is version `0.2.00`; the latest measured current
state is version `0.2.72` (see `README.md` and `AUDIT.md`). Historical documents
remain useful for compatibility and design rationale, but they must link
forward to the current authority.

## Start here

For an external product/design review, use the curated [`review/00-astra-review-index.md`](review/00-astra-review-index.md) package. It consolidates current reality, the ratified interview contract, production state, presentation rubric, and staged agent instructions.

1. [`README.md`](../README.md) — project entry point and verification commands.
2. [`AGENTS.md`](../AGENTS.md) — contributor rules and feature ownership.
3. [`authoring-system-plan.md`](authoring-system-plan.md) — active plan for
   typed definitions, single-source registries, factories, previews,
   verification reform, and truthful docs. Read its trap register before
   touching authored content data.
4. [`AUDIT.md`](AUDIT.md) — current codebase measurements, risks, and the
   `0.2.x` infrastructure sequence.
5. [`ROADMAP.md`](ROADMAP.md) — active product and infrastructure sequence.
6. [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — open findings and verification state.
7. [`verification-surface-audit.md`](verification-surface-audit.md) — test/report
   roles, release-gate scope, and verification-surface cleanup.
8. [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) — current content workflows,
   including the data paths that currently do nothing.
9. [`engineering-friction-audit.md`](engineering-friction-audit.md) — evidence-backed
   engineering priorities.
10. [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime boundaries and extension
    rules.
11. [`FEATURE_MAP.md`](FEATURE_MAP.md) — first owner to inspect for each feature.
12. [`composition-refactor-analysis.md`](composition-refactor-analysis.md) —
    historical record of the completed legacy-coupling cleanup and agent handoff.
13. [`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md) —
    long-term content composition, authoring, and performance direction; the
    authoring plan operationalizes its T2 track.
14. [`peak-performance-plan.md`](peak-performance-plan.md) —
    active end-to-end performance plan and release budgets for boot, menus,
    browser runtime, and Samsung A17 verification.
15. [`component-composition-design.md`](component-composition-design.md) —
    approved component contract, wiring rules, and the interchangeable-entity
    proof sequence.
16. [`SCRIPT_INDEX.md`](SCRIPT_INDEX.md) — generated script, class, signal,
    export, and function location index.
17. [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md)
    — current combat roles, elemental identity, dungeon interaction, and
    minimalist content principles.
18. [`design-philosophy-interview-questionnaire.md`](design-philosophy-interview-questionnaire.md)
    — exhaustive producer interview for resolving open product and design
    decisions.
19. [`design-interview-record-2026-09-18.md`](design-interview-record-2026-09-18.md)
    — ratified decision record: firm principles, player-facing contracts,
    approved/rejected directions, and evidence still needed.

## Authority by question

| Question | Authority | Use supporting material for |
|---|---|---|
| What is the player-facing feel and feedback direction? | [`../JUICE.md`](../JUICE.md) | pickup delivery, HUD reactions, menu motion, touch response, and audio hierarchy |
| What exists right now? | [`AUDIT.md`](AUDIT.md) | traced flows and source files |
| Where should a feature go? | [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`FEATURE_MAP.md`](FEATURE_MAP.md) | implementation details |
| What is the accepted refactor route? | [`refactor-route.md`](refactor-route.md) | historical checkpoints |
| What is the player-facing direction? | [`project_direction.md`](project_direction.md) and the current feature design | proposals and rationale |
| Where are balance values? | [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) | tuning plans and design notes |
| What is the current dungeon/content contract? | [`runtime-map.md`](runtime-map.md) and the relevant generator or layout definition | run-specific history |
| What is the approved R6+ generation direction? | [`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md) | compact-generator implementation history and tuning evidence |
| What must remain compatible in saves and exports? | [`production-boundary.md`](production-boundary.md), save plans, and [`VERSIONING.md`](VERSIONING.md) | migration history |
| How is a change verified? | [`README.md`](../README.md), [`gameplay-smoke-checklist.md`](gameplay-smoke-checklist.md), and `tests/manifest.csv` | focused test reports |
| What work is next? | [`ROADMAP.md`](ROADMAP.md) | [`authoring-system-plan.md`](authoring-system-plan.md) and feature plans |
| What is currently unresolved? | [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | the detailed issue tracker |
| Should a test exist or block release? | [`verification-surface-audit.md`](verification-surface-audit.md) | target and runtime evidence |
| How do I add content? | [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) | the trap register in [`authoring-system-plan.md`](authoring-system-plan.md) |
| How do I make content and feature work cheap? | [`authoring-system-plan.md`](authoring-system-plan.md) | source-backed audits in this map |
| What makes a change difficult? | [`engineering-friction-audit.md`](engineering-friction-audit.md) | source files and detailed audits |
| How is the composition refactor progressing? | [`composition-refactor-analysis.md`](composition-refactor-analysis.md) | historical completion record; the strict scorecard is 100% and the regression floor is re-baselined |
| What is the component contract for reusable entity behavior? | [`component-composition-design.md`](component-composition-design.md) | wiring rules, adapter refinement, and the interchangeable-entity proof |
| What is the long-term modularity and performance direction? | [`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md) | content definitions, runtime composition, authoring workflows, and device-backed performance work |
| What is the end-to-end performance execution plan? | [`peak-performance-plan.md`](peak-performance-plan.md) | boot/menu gates, capture scenarios, lifecycle separation, runtime budgets, and A17 verification |
| What is the current target HUD and touch-polish contract? | [`ui-consistency-and-touch-polish-plan.md`](ui-consistency-and-touch-polish-plan.md) | target health geometry, map footer anchoring, and shop row hitboxes |
| What are the current combat and dungeon design principles? | [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md) | feature-specific plans and tuning values |
| Which product and design questions remain unresolved? | [`design-philosophy-interview-questionnaire.md`](design-philosophy-interview-questionnaire.md) | current design authorities and interview decision records |
| What is the ratified design contract? | [`design-interview-record-2026-09-18.md`](design-interview-record-2026-09-18.md) | feature-specific plans and tuning values |

## Document lifecycle

Every new plan should begin with these fields:

```text
Status:
Scope:
Owner:
Current code:
Verification:
Supersedes:
```

Use `current` for documents that describe the implementation or accepted
rules, `active plan` for approved work that is not complete, `implemented` for
handoffs that document shipped behavior, and `historical` for superseded plans.
Historical documents remain useful when they explain compatibility or design
rationale, but they must link forward to the current authority.

## Current cleanup queue

- Refresh `SCRIPT_INDEX.md` with `tools/generate_script_index.ps1` whenever
  runtime scripts are added, moved, or materially split.
- Add lifecycle headers to active implementation plans as they are reopened.
- Mark composition and menu plans that describe completed or superseded work.
- Add explicit run scope to R3/R4/R5/R7/R8 dungeon documents.
- Keep the tuning index aligned with the external default resources under
  `resources/tuning/`; add newly surfaced hardcoded knobs to its gap list.
- Keep this map and the canonical documents linked from `AGENTS.md`.
- Keep test/report role and state decisions in
  [`verification-surface-audit.md`](verification-surface-audit.md); keep target
  correctness findings in [`test-target-audit.md`](test-target-audit.md). The
  executable classification lives in `tests/manifest.csv`; the smoke runner
  derives its groups from that file, so update it when adding or retiring a
  test.
- Move or archive documents only after links and code ownership have been
  checked; broad file moves are a separate cleanup change.
- Track the generated content index, metric blocks, and the link-checked
  `docs/history/` archive in Slice 0 and Slice 6 of
  [`authoring-system-plan.md`](authoring-system-plan.md).
