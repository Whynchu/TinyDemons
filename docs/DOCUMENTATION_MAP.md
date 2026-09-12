# Tiny Demons Documentation Map

Status: current navigation guide for the `0.2.x` cycle

Updated: 2026-09-11

The repository contains design history, implementation handoffs, audits, and
active plans. Use this page to choose the right authority before changing code.
The baseline being preserved is version `0.2.00`; the measured state and
preservation rules are in [`AUDIT.md`](AUDIT.md).

## Start here

1. [`README.md`](../README.md) — project entry point and verification commands.
2. [`AGENTS.md`](../AGENTS.md) — contributor rules and feature ownership.
3. [`AUDIT.md`](AUDIT.md) — current codebase measurements, risks, and the
   `0.2.x` infrastructure sequence.
4. [`ROADMAP.md`](ROADMAP.md) — active product and infrastructure sequence.
5. [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — open findings and verification state.
6. [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) — current content workflows.
7. [`engineering-friction-audit.md`](engineering-friction-audit.md) — evidence-backed
   engineering priorities.
8. [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime boundaries and extension
   rules.
9. [`FEATURE_MAP.md`](FEATURE_MAP.md) — first owner to inspect for each feature.

## Authority by question

| Question | Authority | Use supporting material for |
|---|---|---|
| What exists right now? | [`AUDIT.md`](AUDIT.md) | traced flows and source files |
| Where should a feature go? | [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`FEATURE_MAP.md`](FEATURE_MAP.md) | implementation details |
| What is the accepted refactor route? | [`refactor-route.md`](refactor-route.md) | historical checkpoints |
| What is the player-facing direction? | [`project_direction.md`](project_direction.md) and the current feature design | proposals and rationale |
| Where are balance values? | [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) | tuning plans and design notes |
| What is the current dungeon/content contract? | [`runtime-map.md`](runtime-map.md) and the relevant generator or layout definition | run-specific history |
| What must remain compatible in saves and exports? | [`production-boundary.md`](production-boundary.md), save plans, and [`VERSIONING.md`](VERSIONING.md) | migration history |
| How is a change verified? | [`README.md`](../README.md), [`gameplay-smoke-checklist.md`](gameplay-smoke-checklist.md), and test scripts | focused test reports |
| What work is next? | [`ROADMAP.md`](ROADMAP.md) | feature plans and design proposals |
| What is currently unresolved? | [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | the detailed issue tracker |
| How do I add content? | [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) | feature-specific contracts |
| What makes a change difficult? | [`engineering-friction-audit.md`](engineering-friction-audit.md) | source files and detailed audits |

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

- Add lifecycle headers to active implementation plans as they are reopened.
- Mark composition and menu plans that describe completed or superseded work.
- Add explicit run scope to R3/R4/R5/R7/R8 dungeon documents.
- Reconcile the tuning index with the eventual move from code-instantiated
  tuning objects to external resources.
- Keep this map and the canonical documents linked from `AGENTS.md`.
- Move or archive documents only after links and code ownership have been
  checked; broad file moves are a separate cleanup change.
