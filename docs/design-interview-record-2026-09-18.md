# Tiny Demons — Design Interview Decision Record (2026-09-18)

Status: ratified decision record (Round 12 reflections)

Source: design interview with DeepSeek V4 Flash, closing notes 2026-09-18.
This file is the authoritative record of firm principles, player-facing
contracts, approved directions, rejected/deferred items, and evidence still
needed. It supersedes no content documents; it freezes the design contract so
later product work has a stable target.

Related docs: [`ROADMAP.md`](ROADMAP.md), [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md),
[`mobile-touch-button-and-haptics-plan.md`](mobile-touch-button-and-haptics-plan.md)

## Vertical slice (ratified §7)

- Slimey Depths, 3 starters, Biter/Spitter/Healer/Bat enemies.
- Single-role and mixed encounters.
- One optional elemental interaction.
- One non-elemental solution.
- One orb section.
- One key/switch interaction.
- One reward choice.
- One elite/boss.

## Scope model

- **Scope by construction, not cutting.** Features ship as they go; the
  mechanism for shrinking scope is deferral, not deletion.
- **Never-cut (identity) items**: elemental classes, plus the roster and
  biomes. These define the game and cannot be removed.

## Firm principles

- Fighter-first fantasy; exploration second; "massively tiny" = variety per
  rule.
- Cozy + mysterious tone; death stings lightly ("there was a way"); wins
  delight.
- No pay-to-win, ever (contract-level monetization boundary).
- Every room asks a timing/position question; starters differ in feel, not
  power.
- Resistances are learned by attempting — enemy reactions are the tutorial.
- Ailments stack only when physically sensible (no burn+freeze).

## Player-facing contracts

- **Loadout** = regular magic + held magic + held attack, all slots filled,
  plus one passive per element (28 abilities at 7 elements).
- **Floors**: 5 authored + generated 6–10 per biome; biome-choice unlocks at
  R10; infinite dive with 5/10-floor rewards.
- **Mastery economy**: no cross-element blocker once mastered — mastery is the
  whole loadout economy.
- **Enemies**:
  - First enemy = melee slime (attack + avoid chomp).
  - Spitter = shield-deflect counter + optional ground-pull ability.
  - Healer = priority kill.
  - Bat = 3 counters; dive = punish window.
- **Rooms**: normal room ~6 enemies; congested ceiling 8–9; boss rooms
  breathe.
- **Sessions**: 2–5 min; occasional 10–20 min challenge runs.
- **Elites** = optional hyper-stat + feints; **bosses** = scripted phases,
  main-line.
- **Currencies**: Souls → bind + skill tree; Chroma = run-local resource;
  Gold = market TBD.

## Approved directions

- **Hand-feel**: Fire heavy/expensive, Water light/cheap, Electric fast/stun;
  Grass regen, Shadow assassin, Ground sturdy, Ice freeze.
- **Ailments**: Fire = higher burn proc; Grass = lifedrain DOT; Shadow =
  poison; non-ailment elements are fine.
- **Stub gear** = Gold→fusion flexibility, rarity-only identity (price TBD vs
  Gold curve).
- **Mobile UX**: remove the mobile USE button + press haptics — implemented in
  `docs/mobile-touch-button-and-haptics-plan.md` (v0.2.50).

## Rejected / deferred

- Pay-to-win: **rejected**.
- Multiplayer / servers / base-building: **deferred dream**.
- Ailments on every element: **rejected**.

## Contradictions resolved

- "~10 runs" vs "5 authored + R6+" → 5 authored + generated 6–10.
- "Enemies react specifically" vs "not every reaction for every enemy" →
  per-enemy resistance + discoverability.

## Evidence still needed

- Gold/Souls market split (needs play data).
- Stub-gear price vs Gold curve.
- Mastery time-to-master.
- 8–9 actor readability playtest.
- Reaction-distinctness check at 240×160.