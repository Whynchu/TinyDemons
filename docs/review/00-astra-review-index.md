# Tiny Demons — Astra Review Package

Status: prepared for external agent review  
Purpose: give Astra a compact, source-backed understanding of the game before critique

## Read order

0. `07-astra-gameplay-brief.md` — compact, source-backed presentation of the
   current player loop, feature state, pickup/reward gaps, and review questions.
1. `01-current-game-reality.md` — what exists now.
2. `02-design-intent-and-interview-contract.md` — what the creator wants the game to become.
3. `03-production-and-architecture-state.md` — what is safe to extend and what is not.
4. `04-presentation-and-player-experience-brief.md` — the critique rubric.
5. `05-astra-review-instructions.md` — the staged review task.
6. `06-feature-status-matrix.md` — implementation evidence and gaps.

## Authority rules

- The ratified interview record is the design authority: `../design-interview-record-2026-09-18.md`.
- The current runtime and tests are the implementation authority.
- Feature-specific implementation plans describe intended sequencing, not shipped behavior.
- Older directional documents may contain superseded ideas; do not treat them as current without checking the interview record and current implementation.
- When evidence conflicts, report the conflict instead of silently resolving it.

## Review objective

Assess whether Tiny Demons is becoming a coherent, distinctive, production-ready minimalist action dungeon game—and identify the smallest high-impact improvements that validate the vision without creating uncontrolled scope.

## Expected deliverable from Astra

- Five strongest existing differentiators.
- Five largest player-facing weaknesses.
- Three most important implementation gaps.
- Three features to defer or constrain.
- One smallest compelling vertical slice.
- Highest production and performance risks.
- Prioritized 30/60/90-day recommendations.
