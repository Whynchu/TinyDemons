# Stone Accent Procedural Placement Plan

Status: active plan; static Hub reference, sparse non-Hub selection, bounded
seeded movement, safe same-surface anchor swaps, fixed crack anchors, live
geometry validation, connected-room layout variation, transition staging,
room-tint propagation, and cached transition constraints implemented; weighted
variants and broader distance rules remain future work

Scope: authored stone accent presentation in every runtime room, with the Hub
as the full reference composition and non-Hub rooms as deterministic sparse
subsets with bounded movement and live geometry validation

Owner: room presentation and content authoring

Current code: `scripts/hub_stone_accent_layer.gd` owns the fixed reference table;
`scenes/main.tscn` mounts it under `Map`; `gameplay_bootstrap.gd` feeds it the
existing `RoomController.room_entered` signal and `gameplay_state.gd` performs
the geometry-aware final refresh; `room_puzzle_controller.gd` propagates the
active environment tint; runtime copies live under
`assets/artwork/Stone_accents/`. `room_controller.gd` owns the transition
prewarm/cache for boss authoring geometry so that room entry does not repeat
scene instantiation or per-cell tile copying.

Verification: `tests/hub_stone_accent_scene_smoke.gd` and
`tests/fire_palette_effects_scene_smoke.gd` pass in focused standalone headless
runs on 2026-09-13; screenshot comparison for sparse rooms remains the next
visual acceptance step

Supersedes: none

Reference: original Hub room mockup at native `240x160`

## Goal

Use the authored stone accent pieces in `Artwork/Stone_accents/` to reproduce
the original Hub room reference first, then use that same placement table as a
restrained sparse treatment in every other room before adding more variation.
Do not damage the room silhouette, traversal space, or authored pixel style.

The Hub keeps all 13 placements at their exact reference coordinates. Every
non-Hub room starts from the same table, removes 3 to 5 whole placements, and
then gives the survivors a deterministic placement pass. Floor stones may swap
authored anchors with other surviving floor stones. Wall stones may swap only
with other surviving stones on the same wall side. The outermost right-wall
stone, `WallStone_05_right`, is a reserved outer slot: it can jitter vertically
or be removed, but it never exchanges anchors with the two inner right-wall
stones. This keeps an inner stone from inheriting the clipping-prone far-right
anchor. Cracks never move and never participate in anchor swaps. After any
accepted swap, wall pieces may move vertically by at most 2 pixels; floor
pieces may move in both axes by at most 2 pixels. Bricks keep a two-pixel
solver inset from the wall lane edge (exceeding the required one-pixel visual
buffer), floor pieces keep their floor-boundary clearance, and no piece is
added, scaled, mirrored, or given a larger visual weight than the reference
composition. Connected non-Hub rooms retry seeded variants until their final
visible layout differs from the preceding room. Room-entry presentation is
staged: the signal applies a cheap provisional selection, then the final pass
runs once after live floor and door geometry is available. All accent
base/specular sprites receive the active room tint.

## Current Asset Inventory

- Four floor pieces: `FloorStone_01` through `FloorStone_04`.
- Five left-wall pieces: `WallCrack_01_left`, `WallCrack_02_left`,
  `WallStone_01_left`, `WallStone_02_left`, and `WallStone_06_left`.
- Four right-wall pieces: `WallCrack_03_right`, `WallStone_03_right`,
  `WallStone_04_right`, and `WallStone_05_right`.
- Specular overlays for all WallStone pieces and WallCrack 01/03.
- `WallCrack_02_left` intentionally has no specular companion unless a later
  art pass adds one.
- All current pieces are `16x16` and use the bottom-left contact convention.
- `WallStone_02_Specular_left.png` uses the normalized side naming convention.

`Artwork/` is source art and is `.gdignore`-protected. Runtime copies must be
placed under `assets/artwork/Stone_accents/` before scene/runtime integration.

## Naming Contract

Use this pattern for future pieces:

```text
<Surface><Family>_<Variant>_<side>[_Specular].png
```

Examples:

```text
FloorStone_01.png
WallStone_02_left.png
WallStone_02_Specular_left.png
WallCrack_03_right.png
```

Use lowercase `left` and `right` after an underscore. Do not infer side from
the asset image once the filename has declared it. Do not mirror a piece at
runtime unless the manifest explicitly permits mirroring; pixel-art lighting
may make an apparent mirror visually incorrect.

## Placement Model

Decorations should be separate from structural room geometry:

- Structural floor, wall, face, door, and socket layers remain owned by the
  existing `basic_room.tscn` and `IsometricRoomLayer` path.
- A dedicated stone accent layer owns accent sprites and their optional
  specular overlays.
- Each sprite uses `centered = false` and treats its bottom-left authored pixel
  as the placement anchor.
- Placement is expressed in room-local isometric coordinates first, then
  converted to pixels through the room's existing tile geometry.
- Accents render above structural surfaces but below actors and interaction
  effects unless an explicit wall-depth rule requires otherwise.

## Manifest Fields

The future manifest should record one row per base accent:

| Field | Purpose |
|---|---|
| `id` | Stable content identifier |
| `texture` | Runtime texture path |
| `surface` | `floor` or `wall` |
| `side` | `none`, `left`, or `right` |
| `specular_texture` | Paired overlay path or empty |
| `anchor` | Current authored anchor convention |
| `footprint` | Occupied local bounds |
| `allow_jitter` | Whether bounded movement is legal |
| `allow_anchor_swap` | Whether the piece may exchange its authored slot with a relative piece |
| `allow_mirror` | Whether horizontal mirroring is approved |
| `weight` | Selection weight for optional variants |
| `cluster` | Optional visual grouping identifier |

The first version may be a small typed data table owned by the stone accent
placer. A separate resource framework is not required for the initial pass.

## Implementation Phases

### Phase 1: Runtime asset preparation

- Copy the approved source pieces from `Artwork/Stone_accents/` to
  `assets/artwork/Stone_accents/`.
- Preserve exact pixel dimensions, nearest filtering, alpha, and filenames.
- Add import metadata only through the normal Godot import path; do not hand
  edit imported texture records.
- Register the focused reference smoke in `tests/manifest.csv`; keep the
  per-accent content manifest for the later procedural phase.

Exit evidence: all 21 source files are represented, every side is explicit,
the missing `WallCrack_02_left` specular is recorded as intentional, and the
focused composition smoke passes.

### Phase 2: Static Hub reference reconstruction

- Add a Hub-only `HubStoneAccentLayer` presentation owner.
- Place the reference accents from a fixed, hand-authored placement table.
- Match the supplied mockup at native `240x160` before introducing randomness.
- Keep doors, sockets, fire, NPCs, player spawn, and interaction points clear.
- Compare the output against the reference using screenshots, not only pixel
  coordinates.

Current result: the fixed table reproduces the recovered native reference
origins with 13 base placements and 8 optional specular overlays. It is shown
in room type `START` at full density and has no collision, socket, or gameplay
state.

Remaining exit evidence: screenshot comparison against the authoritative mockup
accepts the composition and confirms that gameplay collision and socket
behavior remain unchanged. A seed is deliberately not part of this phase.

### Phase 3: Surface and orientation validation

- Render representative left-wall pieces on the left wall.
- Render representative right-wall pieces on the right wall.
- Confirm whether any source needs a visual transform or whether the authored
  side-specific pieces are already sufficient.
- Validate specular overlays at the same anchor and z-order as their base piece.

Exit evidence: no wall accent floats, clips through the wall, reverses its
lighting, or crosses the wrong perspective side.

### Phase 4: Deterministic procedural variation

- Pass the current dungeon seed into the accent layer.
- Keep structural geometry fixed.
- Treat the reference placements as mandatory or optional slots.
- Apply bounded per-piece jitter only inside the piece's approved local limits.
- Keep crack anchors fixed; allow seeded anchor permutations only among floor
  stones or among wall stones on the same side.
- Commit a permutation only when the complete selected set still passes the
  live edge, door, and overlap validator; otherwise retain authored anchors for
  that relative group.
- Select optional variants by weighted groups rather than uniform random noise.
- Allow subtraction of optional pieces for sparse variants.
- Enforce minimum distances from the fire, entrances, NPCs, spawn, and doors.

Current result: non-Hub rooms deterministically remove 3 to 5 base placements
from the fixed table, with each paired specular overlay following its base.
The sparse selector preserves the complete floor group, at least two movable
pieces per inner wall-side group, and the authored outer-right slot contract.
Every selected movable group receives a seeded derangement, so each surviving
piece inherits another piece's authored anchor; cracks remain at their authored
anchors and `WallStone_05_right` remains at its reserved outer anchor.
Subtraction is therefore concentrated on cracks and wall stones while the full
floor group stays available for fluid exchanges. Surviving groups then use
independent seeded candidate order, so one seed can move a piece without
reshuffling every other piece.
Candidate footprints are checked against the live `FloorCollisionGuide`, a
two-pixel floor boundary clearance, the two-pixel brick inset inside the
authored wall lanes, opaque door/entrance pixels, door guide polygons, and
existing accent footprints. If a swap or room-specific geometry change makes a
slot unsafe, that candidate variant is rejected and the next deterministic
variant is tried; no swapped piece falls back to its own authored anchor.
Each room stores its accepted layout variant for stable revisits and retries
the next seeded variant when it would match the immediately preceding
connected non-Hub room or cannot satisfy the swap/density contract. Repeated
candidate checks reuse the current room's static geometry and jitter results so
the transition pass stays bounded. Boss-room authoring scenes and tile-layer
payloads are also prewarmed/cached during the boot loading frame, and room
geometry is copied only when switching between normal and boss modes. The Hub
bypasses this search and remains the visual reference. Candidate order pushes a
shared piece's previous pixel position to the end of its legal choices, and the
focused sweep verifies that connected rooms move at least 60% of their shared
movable pieces when a legal alternative exists.

Remaining exit evidence: screenshot checks confirm the sparse rooms remain
visually balanced and traversable. Weighted selection, clustering, mirroring,
and distance rules involving actors or the fire remain separate future work;
they are not needed to authorize the current small movement envelope.

### Phase 5: Verification and authoring workflow

- Add deterministic placement tests for seed repeatability.
- Validate surface/side eligibility and anchor bounds.
- Validate that mandatory accents cannot be removed.
- Validate that optional subtraction never removes gameplay-critical geometry.
- Add a screenshot checklist for Hub reference, sparse, dense, and mixed-side
  variants.
- Document how to add a new accent without editing room orchestration.

## Guardrails

- Do not randomize doors, sockets, collision guides, floor topology, or player
  spawn positions.
- Do not place accents through `gameplay.gd` special cases.
- Do not use visual accents as collision geometry unless a separate collision
  contract is explicitly approved.
- Do not mirror side-specific art automatically.
- Keep the same fixed reference placement table across rooms; non-Hub offsets
  must stay inside the approved two-pixel surface-specific envelope and the
  live geometry validator.
- Never offset or swap cracks.
- Restrict anchor swaps to floor-with-floor and same-side-wall-with-wall
  groups, and accept them only when the complete selected layout remains valid.
- Keep `WallStone_05_right` in the reserved outer-right slot; only the inner
  right-wall stone group may exchange anchors.
- Keep the two-pixel solver buffer between brick footprints and the wall lane
  edge so the rendered result retains at least a one-pixel visual gap.
- Never accept the same final accent layout for two connected non-Hub rooms;
  use the next deterministic layout variant when necessary.
- Prefer a changed pixel position for every shared movable piece between
  connected rooms; retain a repeated position only when the room's clearance
  rules leave no legal alternative.
- Apply the current room presentation tint to every accent base and specular
  overlay, including pieces revealed by a room-specific sparse selection.
- Keep the reference seed stable for screenshots, bug reports, and tests.

## Open Decisions

- Confirm whether all current wall pieces are already authored for their named
  side or whether any should support an approved mirrored variant.
- Confirm the exact reference screenshot that is the authoritative first target.
- Decide whether specular overlays are always rendered or selected by room
  palette/lighting state.
- Decide the initial accent density range for sparse and dense variants.
- Decide whether the static reference placement table should live beside the
  Hub scene or in a separate content definition script.
