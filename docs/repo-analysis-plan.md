# Tiny Demons Repository Analysis Plan

Status: active working plan

## Purpose

Analyze the repository as a production game codebase. The objective is not to
produce the largest dependency graph or reorganize files for appearance. The
objective is to determine whether the project helps a small team make, test,
and ship authored game content safely.

The analysis should identify:

- what is required to build and ship the game;
- who owns each important gameplay concept;
- where state and behavior are duplicated;
- where the code slows content creation or causes regression risk; and
- which files can be removed with high confidence.

The guiding rule is:

> Improve the team's ability to make the next playable build without adding
> abstraction that does not solve a real production problem.

## Working Principles

- Treat `TinyDemons/` as the candidate production project boundary.
- Analyze player-facing features before analyzing individual files.
- Prefer one clear owner and one authoritative source of state.
- Preserve the explicit frame schedule and deterministic runtime behavior.
- Favor authored, inspectable content over speculative generalization.
- Treat static "unreferenced" results as evidence, not deletion permission.
- Refactor when ownership or iteration is painful, not merely because a file is large.
- Make one small change at a time and verify it before continuing.
- Keep this plan, `AUDIT.md`, and `ARCHITECTURE.md` aligned.

## Phase 0: Establish The Production Boundary

### Questions

- Which directory is the authoritative Godot project?
- Which platforms are supported?
- Which scenes and export presets define shipping builds?
- Which files are runtime, editor-only, debug-only, test-only, research, or generated?
- What does a clean checkout require to boot and export?

### Tasks

- [ ] Inspect Git status, tracked files, branches, ignore rules, and recent history.
- [ ] Confirm the project root and `project.godot`.
- [ ] Identify the main scene, autoloads, plugins, and export presets.
- [ ] Identify required runtime assets and external tool dependencies.
- [ ] Record desktop, web, and touch/mobile expectations.
- [ ] Run the editor/import scan.
- [ ] Run one focused smoke test.
- [ ] Record the current baseline and any environment warnings.

### Deliverable

`docs/production-boundary.md`

This document should answer: "What must exist in a clean checkout for the
game to run and ship?"

## Phase 1: Build The Feature Map

Map player-facing features rather than creating a flat inventory of every file.

Initial feature areas:

- Boot and title flow
- Input and device detection
- Player movement and combat
- Enemies and encounters
- Room progression
- Dungeon generation
- Chroma and elemental systems
- Gear and fusion
- Menus and hub
- Profile and save systems
- Audio
- Display, web, and touch support

For each feature, record:

- primary runtime owner;
- state owner;
- data authoring location;
- presentation scenes;
- supporting scripts;
- tests;
- current documentation;
- known legacy or duplicate paths; and
- current risk.

### Deliverable

`docs/FEATURE_MAP.md`

Keep this document human-readable and maintainable. Do not replace it with a
large generated report.

## Phase 2: Trace Complete Vertical Slices

Do not analyze every subsystem with equal depth. Trace complete player-visible
flows through input, orchestration, state, presentation, persistence, and tests.

### Recommended slices

1. Start a run, enter a room, fight an enemy, and receive a reward.
2. Change profile or settings, save, reload, and restore state.

### For each slice, document

- input entry point;
- coordinator path;
- state mutations;
- scene and resource loading;
- signals and string-based calls;
- persistence boundaries;
- tests that cover the behavior;
- failure points; and
- duplicate ownership.

### Deliverable

`docs/vertical-slice-analysis.md`

The purpose is to reveal the architecture's real behavior, not just its file
layout.

## Phase 3: Measure Engineering Friction

Evaluate the repository using practical production questions:

- Can a designer add a room without editing the central coordinator?
- Can an engineer change combat without understanding menus and saves?
- Can a bug be traced from player action to visible result?
- Are there multiple sources of truth for the same state?
- Are runtime and authoring data clearly separated?
- Are generated layouts deterministic and inspectable?
- Can a new contributor find the correct owner quickly?
- Can the project be tested from a clean checkout?
- Do tests protect player-facing contracts or only implementation details?

Classify each finding as one of:

- Blocks shipping
- Slows content production
- Creates regression risk
- Mostly cosmetic
- Acceptable tradeoff

### Deliverable

`docs/engineering-friction-audit.md`

Each finding must include evidence, impact, and a suggested verification step.

## Phase 4: Analyze Duplication By Meaning

Review duplication in four levels:

1. **Exact file duplication**: identical content at different paths.
2. **Asset duplication**: identical or equivalent images/audio with different names, formats, or imports.
3. **Implementation duplication**: multiple functions or scripts performing the same behavior.
4. **Ownership duplication**: multiple systems storing or modifying the same concept.

Ownership duplication is the highest-value category. Investigate, in particular:

- player or run state mirrored across controllers;
- competing input routes;
- repeated transform or geometry calculations;
- multiple menu navigation owners;
- legacy delegates still called by new code; and
- authored and generated layouts implementing overlapping rules.

Mark every candidate as:

- Safe to remove
- Safe to archive
- Requires runtime verification
- Requires a design decision
- Active

Never delete a Godot asset solely because static search found no reference.
Check dynamic paths, editor workflows, tests, imports, and export settings.

## Phase 5: Review Content Authoring Quality

For rooms, enemies, rewards, menus, and encounters, answer:

- Where is the content defined?
- Is it data-driven or embedded in orchestration code?
- Can designers preview it?
- Can designers tune it safely?
- Are runtime rules understandable?
- Are special cases isolated or spread through the coordinator?
- Does adding content require adding infrastructure?

Prefer systems that make authored content faster, safer, and easier to inspect.
Avoid universal frameworks unless they solve a demonstrated production need.

## Phase 6: Apply Cleanup Gates

Only clean a file when the evidence supports it.

### High-confidence candidates

- caches;
- logs;
- Python `__pycache__` directories;
- editor metadata;
- temporary generated output; and
- exact duplicate research files.

### Deletion requirements

Before removing runtime-adjacent material:

1. Verify scene, script, project, test, and export references.
2. Check dynamic loading and string-based paths.
3. Check whether it is an authoring or source asset.
4. Run focused tests.
5. Run the relevant full suite.
6. Review the diff.
7. Record the decision in `docs/cleanup-ledger.md`.

Keep uncertain material outside the Godot project or in Git history. Do not
create an in-project quarantine directory.

## Phase 7: Produce The Action Backlog

Every recommendation must include:

- problem;
- evidence;
- player or content impact;
- proposed change;
- risk;
- verification; and
- priority.

Prioritize in this order:

1. Shipping and save-data risks.
2. Incorrect or competing state ownership.
3. Bugs caused by hidden dependencies.
4. Friction in authoring rooms, enemies, and encounters.
5. Repeated behavior with a clear owner.
6. Generated and cache cleanup.
7. Documentation consolidation.
8. Cosmetic file organization.

### Deliverable

`docs/refactor-backlog.md`

## Verification Rules

Before accepting a cleanup or refactor:

- [ ] Clean project checkout boots.
- [ ] Import/parser scan succeeds.
- [ ] Focused smoke tests pass.
- [ ] Relevant full smoke suite passes in the approved environment.
- [ ] Web export still works if it is a supported target.
- [ ] No unexpected asset or scene changes appear.
- [ ] Documentation identifies the new owner.
- [ ] The diff is small enough to review.

Follow `AGENTS.md` for MCP-first verification rules. Do not run the full
standalone smoke suite while an MCP Godot editor/runtime is active.

## Initial Work Package

Start with only these tasks:

- [ ] Inspect Git status, tracking, ignore rules, and recent history.
- [ ] Confirm the clean project boot and one focused smoke test.
- [ ] Map the feature areas listed in Phase 1.
- [ ] Trace the room-combat-reward slice.
- [ ] Trace the save/load slice.
- [ ] Identify the first five high-confidence findings.

Do not reorganize directories or remove uncertain runtime files during this
work package.

## Maintenance

Update this plan when the analysis reveals a better sequence, new supported
platform, or changed production boundary. Update `AUDIT.md` when a finding is
confirmed or resolved. Update `ARCHITECTURE.md` when ownership changes.

Every completed phase should record:

- date;
- branch or commit;
- evidence gathered;
- tests run;
- findings confirmed; and
- follow-up work.
