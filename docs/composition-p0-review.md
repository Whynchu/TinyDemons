# Composition cleanup P0 review

Status: P0 inventory and dispositions complete; the wider cleanup proposal is
still awaiting owner review. No runtime changes or removals are approved.

Snapshot: tracked-tree commit `85c9f071354e3564b3726c9fe063f8ffb74e68f6`;
Graphify map built at `78320ffb8cbe2d29a6f801e8bc48478ed9982a5b`.

## Coverage

The [machine-readable disposition inventory](composition-p0-disposition.json)
contains every community in the captured Graphify map and every tracked path
not represented as a graph source path. It records per-community source paths,
owner authorities, representative nodes, relationship evidence, caveats,
dependencies, confidence and next action. Each unmatched path has a domain,
disposition, rationale, owner, reference counts, confidence, risk and next
action.

| Measure | Count |
| --- | ---: |
| Graph nodes / links | 21,073 / 46,226 |
| Communities | 727 |
| Graph source paths | 1,016 |
| P0 path inventory | 3,126 |
| Paths not represented in the graph | 2,110 |
| Graph source paths absent from the tracked snapshot | 0 |
| Communities with no source paths | 0 |
| Graph nodes without source attribution | 58 |

The path inventory is the 3,124 files tracked at the source commit plus the two
P0 review artifacts, so neither report leaves its own path outside the census.
The two pre-existing working-tree edits in `project.godot` and
`scenes/authoring/previews/enemy_preview_workbench.tscn` are identified in the
inventory but their uncommitted contents are not represented by the map.
Committed `scripts/`, `resources/`, `scenes/`, `assets/`, and `tests/` paths did
not change between the map commit and the tracked-tree commit. The nested
`graphify-godot/` repository is excluded and remains a separate project.

This is full enumeration with source-path and domain-level triage, not manual
review of every symbol or binary. Graph edges aid navigation; they do not prove
runtime calls or unused code. A missing literal or basename reference does not
prove a file is unused. The inventory marks 1,508 paths with no such direct
text reference and keeps them under conservative retention or investigation
rules.

## Community dispositions

| Disposition | Communities | Reading |
| --- | ---: | --- |
| Retain with the mapped domain owner | 290 | Keep the current ownership boundary visible; candidate refactors remain in the staged plan. |
| Retain cross-domain navigation | 212 | Inspect the seam in a later bounded slice; graph links alone do not make it a defect. |
| Retain documentation or coordination | 157 | Keep design, workflow, and planning connections navigable. |
| Retain verification evidence | 61 | Keep tests and verification surfaces tied to their owners. |
| Retain and review vendor boundary | 7 | Preserve the third-party boundary until licensing and update ownership are checked. |

Every one of the 727 communities has source-path evidence and an explicit next
action. Relationship samples are labeled as graph evidence, not verified
runtime callers. The 58 source-unattributed nodes cannot support individual
ownership claims; their surrounding community still has mapped source paths.

## Unmapped-path dispositions

All 2,110 paths have a recorded disposition. The detailed counts are grouped
here; individual rows and the full 19-way disposition vocabulary are in the
JSON inventory.

| Group | Count | Disposition |
| --- | ---: | --- |
| Godot `.import` metadata and `.uid` sidecars | 1,194 | Retain; these are part of Godot import and resource identity workflows. |
| Source art, mockups, referenced runtime art, and generated runtime art | 482 | Retain; source/runtime pairs and generated outputs need provenance and regeneration proof before any retirement. |
| Audio clips | 335 | Retain 90 resolved catalog endpoints; investigate the other 245 as alternate/source/tooling candidates. |
| BFXR SFX source projects | 22 | Retain as editable source projects pending production-workflow review. |
| Other config, vendor notices, docs, tooling, shader, and visual evidence | 77 | Retain or investigate under the path-specific owner and next-action record. |

No path has deletion approval. Each file row records the same explicit hold
until its stated evidence gate closes; this is not an asset cleanup list.

## Asset and SFX evidence

- The audio catalog has 53 keys resolving to 90 declared or preferred endpoint
  files. The project contains 335 tracked `.wav`, `.ogg`, and `.mp3` files;
  245 are outside those endpoints and remain investigation candidates, not
  “unused” files. The 22 `.bfxr` files are editable source projects and are
  counted separately.
- Exact hashing found 184 media groups: 5 audio groups and 179 non-audio
  groups. Many non-audio pairs are source-art/runtime copies. Hash equality
  does not prove interchangeable use, and no group is approved for removal.
- The web export currently includes all resources with no exclusion filter, so
  an actual exported-PCK inventory is still required before making shipping or
  size claims.
- Godot sidecars, generated art, editor previews, source archives, catalog
  fallback behavior and tool/test consumers remain explicit evidence gates in
  the parent [cleanup proposal](composition-cleanup-review-plan.md).

## Handoff

P0 is complete as an inventory and disposition pass. The next phase is P1:
characterize mixed-family replacement, save/restore, preview, exported-PCK and
performance behavior before changing enemy ownership or retiring files. The
[extraction ledger](composition-extraction-ledger.md) records the source-backed
in-progress extractions and their outstanding proof. The overall proposal and
its implementation sequence remain subject to owner review.
