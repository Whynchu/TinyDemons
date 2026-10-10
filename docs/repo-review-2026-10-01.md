# Tiny Demons — Repository Review: Composition, Code Efficiency, and Practicality

Status: scored review at version 0.3.25; current 0.3.82 reconciliation appended below
Scope: whole-repository structural review at `d8e3fa3` (release `0.3.25`), covering
composition maturity, code efficiency, practicality/navigability, documentation
truth, and player-facing delivery.
Owner: architecture and authoring owners named in `ARCHITECTURE.md`; this review
is advisory and does not itself change runtime behavior.
Current code: measured with `tools/validate_composition.ps1` and direct source
inspection at `0.3.25`.
Verification: read-only. No Godot process and no test suite were launched (the
session restriction in `coord/status-codex.md` applies). All findings are
source- or validator-backed; player-facing claims are design inferences from
source, not playtests.
Supersedes: none. It complements `AUDIT.md` (source measurements) and
`authoring-system-plan.md` (authoring targets), and it flags where those drift.

## 0. How this review was produced

Three project advisors reviewed different surfaces in parallel and read-only,
then their findings were reconciled against direct measurements:

- architecture and code structure (composition kinds, dynamic seams, half-baked
  systems, folder layout, efficiency);
- modularity/buildability (definition -> catalog -> factory -> preview ->
  validator -> save-ID maturity per content kind, reusable "pieces," a target
  folder layout, and a migration sequence);
- player-facing design (which systems deliver meaningful decisions).

Ground-truth snapshot used for the scorecard:

| Metric | Value |
| --- | --- |
| HEAD | `d8e3fa3` release `0.3.25` |
| `scripts/*.gd` | 229 (flat, no subdirectories) |
| `root.call/get/set` sites | 2,198 (baseline 2,202; target <= 2,499) |
| `GameplayState` | 1,718 lines / 286 fields |
| `RoomController` | 2,250 lines (target <= 2,296) |
| Editor composition | 97.6% |
| Components blind / configured | 23 / 22 of 23 |
| Definition surfaces editor-able | 23 of 23 |
| Scenes (`*.tscn`) | 27 |
| Resources (`*.tres`) | 46 |
| Docs (`docs/**/*.md`) | 116 |
| Test manifest | 152 rows: 75 verified, 76 unverified, 1 environment |

`tools/validate_composition.ps1` reports `COMPOSITION_AUDIT_OK`.

## 1. Scorecard

| Dimension | Score | One-line |
| --- | ---: | --- |
| Composition layout | **6.0 / 10** | Excellent enemy pipeline and guardrail; most other content kinds are still code-wired. |
| Code efficiency | **5.5 / 10** | Clean frame schedule and blind leaf components; a few monoliths and a service-locator hub dominate cost. |
| Practicality / navigability | **6.0 / 10** | Strong docs and tooling; a 229-file flat `scripts/` and non-recursive scanners hurt humans and LLMs. |
| Documentation quality | **8.0 / 10** | Unusually honest and self-aware — but counts and "current release" labels are stale. |
| Verification maturity | **4.5 / 10** | 76/152 manifest rows unverified, including gate rows; "implemented in source" outruns evidence. |
| **Overall** | **6.0 / 10** | A strong, real foundation with uneven execution; the "build from pieces" promise is half-kept. |

Interpretation: this is a mature indie codebase with a genuine architecture
(typed contexts, blind components, a real frame schedule, a real enemy authoring
pipeline). It is not yet the "highly modular, easily built from pieces" system the
project aims to be, because only one content kind is fully data-driven and the
file layout does not signal ownership.

## 2. What is genuinely strong (keep and standardize)

- **Deterministic frame schedule.** `gameplay.gd` -> `GameplayFrameController`
  orders the frame with no hidden `_process()` in gameplay owners.
- **Typed narrow contexts.** 21 `*_context.gd` bundles replace ad-hoc root
  reaches with configure-injected callables.
- **Blind leaf components.** 23 components are blind and 22 are `@export`-
  configured; `HealthComponent` is a clean reference.
- **The enemy pipeline is complete.** `EnemyDefinition` (typed + `validate()`)
  -> `SlimeVariantCatalog` over generated manifests -> `EnemyFactory` -> preview
  workbench -> definition validator -> stable `enemy_definition_id`. A new
  variant is data-only; this is the model to copy.
- **Honest docs.** The authoring plan carries a "trap register," and `AUDIT.md`
  explicitly disclaims the composition scorecard as a proxy. That self-awareness
  is rare and valuable.

## 3. Composition maturity by content kind

Pipeline stages: definition -> catalog/registry -> factory -> preview ->
validator -> save ID. "Missing piece" = what blocks adding a second variant with
zero central-runtime edits.

| Kind | Verdict | Missing piece |
| --- | --- | --- |
| Enemies | **Complete** | none for variants; new *families* still edit `enemy_factory.gd` |
| Items | Partial | typed `ItemFactory`/instance path; `visual_id` written but never read |
| Elements | Partial | one authored registry; 4-5 parallel tables + hand `element_for_palette()` |
| Statuses | Partial | move under `resources/definitions/`, drop the `STATUS_IDS` code allowlist, add catalog/preview |
| Rooms (prefabs) | Partial | dynamic registry (factory is a code list); stable socket IDs separate from the 4 edge kinds |
| Dungeon layouts/runs | Partial | promote `RoomSpec`/`ConnectionSpec` to `Resource`; authored payloads are `Array[Dictionary]` |
| Spells | Partial (new) | authored `.tres` + discovery + validator (registry is still a code dictionary) |
| Encounters / Rewards | Partial | currently singleton tuning bags; need catalogs + factories |

Cross-kind gap: there is no shared `ContentDefinition` base / `ContentRegistry`;
each kind re-implements discovery differently.

## 4. Half-baked and "implemented in source" systems (ranked)

1. **Dead authored policy fields (high).** `dungeon_generation_policy.gd:23-24`
   exports `first_orb_depth` / `first_special_depth`, but the generator uses
   hardcoded `dungeon_layout_generator.gd:31,50` (`FIRST_ORB_DEPTH`,
   `PRIMARY_FLAMES`). A designer edits a `.tres` that does nothing; the validator
   even asserts the no-op. Either make them authoritative or delete them.
2. **Spells have no authored data yet (high).** `spell_form_catalog.gd:34-102`
   builds all eight forms in code; there is no `spell_form*.tres`. The delivery
   behavior is now real (Fire `CONE`, Water `PROJECTILE_SPLASH`, Electric
   `INSTANT_TARGET`, Grass `BEAM`, Shadow/Ice `PROJECTILE`, Ground `RADIAL_SELF`)
   but it is not authorable.
3. **Dead R7 route code (medium).** `puzzle_route_generator.gd:37-155`
   `_build_native_r7()` and `:216-217` `is_native_r7()` have no callers;
   `puzzle_map_layout_compiler.gd:34` `build_r6()` aliases R5.
4. **Untyped authored payloads (medium).** `dungeon_run_definition.gd:12-13` and
   `puzzle_plan_data.gd:10,13` are `Array[Dictionary]` while typed
   `RoomSpec`/`ConnectionSpec` exist but are unused by the resources.
5. **Items half-migrated (medium).** `visual_id` is defined/serialized but only
   read by the preview workbench; `demon_cloak` has four owners.
6. **Element identity in 4-5 parallel tables (medium).** `ElementCatalog`
   enum + `element_catalog.tres` + `PlayerChromaComponent.Aspect` +
   `aspect_catalog.gd` + `slime_visual_component.gd` palette list, plus a
   hand-written `element_for_palette()`.
7. **Status system real but unverified (medium).** Typed resources and
   `StatusComponent` exist; registered checks have not run and a magenta render
   artifact is unresolved.

## 5. Code efficiency and practicality

- **Dynamic seams:** 2,198 `root.call/get/set` sites across 229 scripts,
  concentrated in 29 files. `screen_state_controller.gd` (332), then
  `combat_runtime_controller.gd` (235), `room_controller.gd` (212),
  `slime_runtime_controller.gd` (197). The metric under-counts real coupling:
  `GameplayState` contains ~342 forwarding `.call(...)` delegations and the frame
  controller rebuilds callable contexts that still read the state bag by name.
- **Largest owners / mixed responsibility:** `screen_state_controller.gd`
  (~5,200 lines; menus + routes + HUD + save-select + cloud glue + input
  dispatch), `dungeon_layout_generator.gd`, `room_controller.gd`,
  `hub_flow_controller.gd`, `enemy_preview_workbench.gd`, `gameplay_state.gd`
  (213 mutable `var`s).
- **Guardrail is relative, not absolute.** `root_accesses_max` (2,499) sits
  above the current 2,198, and "100% progress" is measured from a recorded start
  (3,135). Passing means "no worse than baseline," which the plan itself states.
- **Frame-path risk:** the frame schedule calls
  `pickup_runtime_controller.flush_pending_profile_save(root)` each frame; when a
  pickup sets the pending flag it performs synchronous
  `JSON.stringify`/`FileAccess` write/verify/backup/rename on the main thread.
- **`GameplayState` is pinned at its ceiling** (1,718/`1719`, 286/`286`): the
  guardrail permits neither regression nor improvement, so it discourages the
  state-bag reduction the architecture actually needs.

## 6. Folder / module organization

All 229 runtime scripts sit flat in `scripts/` (each with a `.uid`). Natural
clusters exist only by filename prefix: menu/UI/preview (~34), combat/actors
(~52), rooms/dungeon (~48), magic/chroma/status (~22), save/run (~21),
content/authoring (~11), input (3), audio (1). The flat layout forces
filename-prefix matching, makes ownership ambiguous (`player_*.gd` spans input,
combat, magic, and save), and gives LLMs no folder-level signal.

Constraints on regrouping: every script has a `.uid`; scenes/resources use
`uid://`; and **241 literal `res://scripts/...` `preload` references** exist in
code. A raw filesystem move breaks those; the in-editor FileSystem move rewrites
UID + path and is the safe path. Critically, the repo scanners are non-recursive
today (`tools/validate_composition.ps1:143,477-478` and
`tools/generate_script_index.ps1:15-16`), so a subfolder would silently drop out
of the audit and the script index.

Proposed target layout (feature folders) and migration are detailed in the
modularity advisor output; the standard to adopt is:

```text
scripts/
  core/ enemies/ items/ elements/ combat/ spells/ rooms/ dungeon/
  progression/ save/ menus/ presentation/ input/ authoring/
scenes/  resources/{definitions,tuning,generated}/  tools/  tests/
```

Migration must be tooling-first: make the scanners recursive (no file moves),
then move one feature cluster per commit under the editor/UID control, updating
the composition validator's hardcoded filenames and refreshing the content
manifest after any `.tres` move.

## 7. Player-facing delivery (design intent vs implementation)

- **FOCUS / combo (Pillar 2): partially delivers.** Both are real and wired
  (`combat_momentum_component.gd:31-52`; combined at
  `combat_runtime_controller.gd:147`), but the multiplier is applied only in the
  melee path. `player_magic_damage_result_against`
  (`combat_runtime_controller.gd:174`) applies neither focus nor combo, and magic
  hits still build combo — so casting fills a meter it cannot spend. The
  elemental player is excluded from the game's advertised skill layer.
- **Elemental identity: now more than a palette, still not a class.** The seven
  deliveries are implemented as of `0.3.25` and spells guarantee their payload
  status, so Fire cone vs Ice shard is felt. But Water/Grass/Ground remain
  status-free, there is no per-element passive or ability kit (§5.7 is target
  `T`), and form choice is a one-time bind rather than a loadout economy.
- **Non-combat gameplay: does not deliver a decision.** The only gate types are
  `GATE_PUZZLE_COLOR`, `GATE_ELEMENT`, `GATE_ENTRANCE_ORB`
  (`dungeon_graph.gd:34-38`); the required palette is always the player's own
  starter flame (`room_puzzle_controller.gd:52-57`). The GDD's §7.5 vocabulary
  (keys, switches, plates, breakables, carryables, timers) is unimplemented
  though tagged `S`.
- **Progression/economy: coherent at small scale, grind-forward at the tail.**
  Long-term gear odds key on `completed_runs` (capped at 20), and grading is a
  near-monotone ratchet (`run_grade.gd`), so clears beat grades. Pillar 2's
  "skilled player in starter gear" is arithmetically defensible for melee only.
- **Readability (Pillar 6): unverified.** No native-resolution evidence exists;
  status-outline offset, death-sprite, and a magenta rectangle are open, with
  performance flags (mobile freeze, boss-entry ~300-385 ms).

## 8. Documentation vs code (drift to fix)

| Doc claim | Reality |
| --- | --- |
| `AUDIT.md` title "Version 0.2.99"; "current release 0.3.18" | Release is `0.3.25` |
| `KNOWN_ISSUES.md` "current release 0.3.18"; "149 manifest rows / 147 runnable" | 152 rows; 42 counts differ |
| `AGENTS.md` "~2,201" root sites | 2,198 |
| `component-composition-design.md` lists nonzero root sites for animation/equipment-visual components | Both are now 0 (coupling moved to contexts) |
| GDD §7.5 puzzle vocabulary tagged `S` | Unimplemented (color/orb gates only) |

Recommendation: derive counts from tooling (a generated metric block) rather
than hand-copying them, and refresh `AUDIT.md` / `KNOWN_ISSUES.md` headers.

## 9. Top recommendations (bounded, in order)

1. **Make repo scanners recursive**, then relocate scripts into feature folders
   one cluster per commit under editor/UID control. This is the enabling step for
   every later navigability gain.
2. **Adopt one "piece" standard** and hold every content kind to it:
   `class_name` definition with `validate()` -> catalog with data-only discovery
   -> factory -> preview -> definition validator -> stable save ID. Close the
   kinds in this order: spells, statuses/elements, items, rooms, runs,
   encounters/rewards.
3. **Make a piece "done" only when the runtime consumes its authored fields** —
   fix or delete the dead `dungeon_generation_policy` fields and the dead R7
   builder; wire or remove `visual_id`.
4. **Extend FOCUS/combo to the magic and beam paths** (or re-scope the pillar).
   Cheapest change with the largest player-facing payoff.
5. **Extract the 8 imperative menu routes** from `screen_state_controller.gd`
   into scenes + presenters + a route registry, one screen at a time.
6. **Give non-combat one real decision** (one breakable or one carryable) or
   correct the `S` tags — stop institutionalizing "element = color key."
7. **Reduce `GameplayState` toward a real target** by moving transient entity
   state into owning components; re-pin the baseline lower only after proof.
8. **Attack the verification gap**: the 76 unverified rows and the 6 unverified
   gate rows are the evidence debt behind most "implemented in source" claims.
9. **Collapse the duplicate element tables** into one authored registry with
   enum/table agreement checks.
10. **Make the meta reward performance over clears**: shift loot progression
    toward grade and allow a poor clear to grade lower, so rank is not a ratchet.

## 10. The standard moving forward

A feature is "buildable from pieces" only when all six hold:
typed definition + validator; data-only discovery; a factory (not a code
branch); an editor preview; a consumed-by-runtime guarantee (no dead fields); and
a stable save identity with a focused contract test. A folder owns a feature end
to end. Tooling derives its own indexes, and docs derive their counts from
tooling. Structural moves never share a commit with balance changes.

## 11. Advisor inputs

This review consolidates three read-only advisor passes (architecture/code,
modularity/buildability, player-facing design) run against `0.3.25`. Their
per-finding evidence is reflected above; the scorecard and ground-truth table are
from direct measurement.

## 12. Current reconciliation — 2026-10-10, version 0.3.82

Sections 1–11 remain the scored review of the `0.3.25` tree. Their counts,
documentation-drift examples, and numeric scores are historical. The current
source-backed snapshot is in [`AUDIT.md`](AUDIT.md); the repository review score
has not been recalculated for `0.3.82`.

The current static composition check passes its strict targets: 1,859 dynamic
`root.call/get/set` sites, `GameplayState` at 1,714 lines / 282 fields,
`RoomController` at 2,180 lines, 296 scripts in 13 directories, and 0
unclassified scripts. The measured editor-composition score is 94.6%. The
forward target for `screen_state_controller.gd` is still open at 870 / 800
lines, and 512 untyped root parameters remain against a zero target. The green
strict scorecard does not close those forward targets or the authoring-system
work.

The current Pause slice follows the narrower owner pattern already recorded in
`FEATURE_MAP.md`: `PauseMenuState` and `MenuCommandList` own routing/navigation
state, `PauseScreenPresenter` composes the view, `PauseItemsPresenter` renders
the page, `PauseItemsModel` projects/group/sorts profile gear, and
`PauseItemsInputController` handles page input. `screen_route_controller.gd`
continues to route Pause pages. This avoids growing the controller facade and
the main Pause presenter. The Items page supports All, Weapons, Armor, and
Accessories, with Name/Rarity sorting and grouped counts. Its data contract is
gear-only until Consumable and Key Item definitions and storage paths exist.

The test-manifest validator passes at 157 rows, 155 runnable paths, two report
rows, and a 45-path curated gate. The Pause smoke was updated for this slice,
but was not executed: Godot editor/runtime processes were already active and no
Godot MCP diagnostic or playtest tools were connected in the session. Rendered
layout, touch/controller interaction, and in-editor acceptance remain open.

For agent and human coordination, the repository has role-specific Pip, Thorn,
and Hexley advisors, a documented one-at-a-time workflow, and the `coord/` board
protocol for active claims and handoffs. This task used all three advisors and
recorded its own claim/status. Continue refreshing `AUDIT.md`, `KNOWN_ISSUES.md`,
and `SCRIPT_INDEX.md` at slice boundaries so source counts and evidence do not
fall behind release notes.
