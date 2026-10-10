# Tiny Demons Documentation Map

Status: current navigation guide for the `0.3.x` cycle

Updated: 2026-10-10

The repository contains design history, implementation handoffs, audits, and
active plans. Use this page to choose the right authority before changing code.
The baseline being preserved is version `0.2.00`; the current measured audit
snapshot is version `0.3.82` (see `README.md` and `AUDIT.md`). Historical documents
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
16. [`composition-plan-2026.md`](composition-plan-2026.md) — **active plan** for
    full composition: measured baseline, guardrail re-base, script role folders,
    executable composition rules, and the decomposition sequence.
17. [`SCRIPT_INDEX.md`](SCRIPT_INDEX.md) — generated script, class, signal,
    export, and function location index.
18. [`combat-and-dungeon-design-principles.md`](combat-and-dungeon-design-principles.md)
    — current combat roles, elemental identity, dungeon interaction, and
    minimalist content principles.
19. [`design-philosophy-interview-questionnaire.md`](design-philosophy-interview-questionnaire.md)
    — exhaustive producer interview for resolving open product and design
    decisions.
20. [`design-interview-record-2026-09-18.md`](design-interview-record-2026-09-18.md)
    — ratified decision record: firm principles, player-facing contracts,
    approved/rejected directions, and evidence still needed.
21. [`agent-workflow.md`](agent-workflow.md) — project-scoped Codex advisor roles
    and the workflow for asking Pip, Thorn, and Hexley for input.
22. [`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
    — approved direction for one reusable elemental ability/status/presentation
    pipeline shared by the player and enemies. Decision log:
    [`elemental-ability-and-status-system-addendum.md`](elemental-ability-and-status-system-addendum.md).
    Execution: [`elemental-status-implementation-plan.md`](elemental-status-implementation-plan.md).
23. [`game-design-document.md`](game-design-document.md) — whole-game design
    authority: concept, pillars, systems, shipped content inventory, and 1.0
    direction. `S`/`T`/`O` tags mark shipped, target, and open items; subsystem
    design docs remain the detail authority.
24. [`elemental-spell-forms-plan.md`](elemental-spell-forms-plan.md) — active
    plan for the player's Triangle spell: one form per element plus a neutral
    stub, binding-selects-form / current-element-selects-payload, the delivery
    model, and the build sequence.
25. [`repo-review-2026-10-01.md`](repo-review-2026-10-01.md) — scored repository
    review at `0.3.25`, with a 2026-10-10 measured reconciliation against the
    `0.3.82` composition audit and current menu work.
26. [`elemental-affinity-and-transmission-plan.md`](elemental-affinity-and-transmission-plan.md)
    — active plan for the weapon imbue's per-element look, the `wet` status,
    innate element affinity with presentation-only suppression, bidirectional
    contact transmission, and synergy-constrained room generation.
27. [`script-role-map-2026.md`](script-role-map-2026.md) — Current role-folder locations and the completed Stage 1 assignment for all 235 scripts.
28. [`elemental-theme-progression-separation-design.md`](elemental-theme-progression-separation-design.md) — implemented contract separating campaign run content from difficulty pressure.
29. [`freeze-status-design.md`](freeze-status-design.md) — implemented WATER + ICE mixture producing the Freeze status.
30. [`elemental-status-interaction-plan.md`](elemental-status-interaction-plan.md) — accepted status-reaction tree and bounded implementation sequence for heat/cold producing Wet and the Shocked damage tick.
31. [`idle-mode-and-equipment-quality-plan.md`](idle-mode-and-equipment-quality-plan.md) — input-driven autoplay, human override, puzzle-free route policy, simple combat behavior, and numerical equipment sorting/best-stat-pool action. Lifecycle decisions settled 2026-10-07 (explicit Hub start, separate loop opt-in, puzzle-avoiding routing, equal six-lane scoring, best equip in Pause Equipment only, manual starter attunement); implementation has not started.
32. [`anchored-stat-allocation-proposals.md`](anchored-stat-allocation-proposals.md) — selected Model C stat cap, legacy migration rules, and the Hub's ticked allocation-bar contract.
33. [`mixed-encounter-performance-correction-plan.md`](mixed-encounter-performance-correction-plan.md) — active Run 30 mixed-enemy frame-rate incident, corrected interpretation of the current capture, implementation order, and 60/200 FPS acceptance gates.
34. [`performance-cost-guide.md`](performance-cost-guide.md) — source-backed cost map for editor gameplay workloads, measured Run 30 scopes, unmeasured suspects, and Godot performance practices.

## Authority by question

| Question | Authority | Use supporting material for |
|---|---|---|
| What is the player-facing feel and feedback direction? | [`../JUICE.md`](../JUICE.md) | pickup delivery, HUD reactions, menu motion, touch response, and audio hierarchy |
| How healthy is the codebase (composition, efficiency, practicality, folder flow)? | [`repo-review-2026-10-01.md`](repo-review-2026-10-01.md) for the scored review and its current reconciliation | [`AUDIT.md`](AUDIT.md) for current source measurements |
| What exists right now? | [`AUDIT.md`](AUDIT.md) | traced flows and source files |
| Where should a feature go? | [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`FEATURE_MAP.md`](FEATURE_MAP.md) | implementation details |
| What is the accepted refactor route? | [`refactor-route.md`](refactor-route.md) | historical checkpoints |
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
| How is the composition refactor progressing? | [`composition-refactor-analysis.md`](composition-refactor-analysis.md) | historical completion record; the strict scorecard is 100% and the regression floor is re-baselined |
| What is the component contract for reusable entity behavior? | [`component-composition-design.md`](component-composition-design.md) | wiring rules, adapter refinement, and the interchangeable-entity proof |
| What is the plan for full composition, script hierarchy, and enforced rules? | [`composition-plan-2026.md`](composition-plan-2026.md) | measured baseline, guardrail re-base, role folders, executable rules, decomposition sequence |
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
