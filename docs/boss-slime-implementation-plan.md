# Tiny Demons - Boss Slime Implementation Plan

Status: implementation complete; final balance tuning remains a playtest activity

Date: 2026-09-07

Current owners: `slime_actor.gd`, `slime_brain.gd`, `slime_combat_component.gd`,
`slime_tuning.gd`, and actor geometry/presentation owners.

Verification: boss scene, variant, geometry, attack, and spawn coverage; final
balance and device/runtime behavior remain playtest work.

This document defines the complete boss-slime behavior and presentation pass.
The boss must feel like a larger, heavier version of the regular slime while
supporting the Normal Slime and every elemental slime variant. The work is one
coherent slice across movement, attacks, collision weight, jump/slam staging,
visual caching, palette completeness, and UI. Isolated changes that allow these
systems to disagree about boss size or state are out of scope.

Related design:

- [`elemental-slimes-and-combat-plan.md`](elemental-slimes-and-combat-plan.md)
- [`enemy-matchup-progression-plan.md`](enemy-matchup-progression-plan.md)
- [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)

## 1. Player-facing result

Every slime variant can be selected as the lead boss. Each boss uses the same
large-slime locomotion, basic attack, contact-weight, jump/slam, support-wave,
and UI behavior. Its variant controls its display name, combat element, stats,
palette, matchup behavior, damage feedback, and support-wave palette.

The baseline boss should read as a regular slime with greater mass:

- familiar scoot, hold, squish, and bite language;
- longer and more committed movement rather than tiny rapid corrections;
- a readable multi-frame bite lunge rather than a one-frame teleport;
- strong contact authority that slows and redirects the player;
- one authored jump away and targeted slam sequence;
- no runtime hitch when the support wave appears; and
- complete, consistent body and shadow coloration in every state.

Element-specific boss mechanics are not part of this pass. A Fire boss and an
Ice boss share the same behavior state machine. Future elemental abilities must
be designed as explicit extensions rather than branches hidden in palette code.

## 2. Canonical roster

`SlimeVariantCatalog` remains the identity authority. `ElementCatalog` remains
the combat matchup authority. Normal is the player-facing slime family name;
Neutral is its combat element. There is no Neutral flame.

| Variant key | Boss display name | Combat element | Palette |
| --- | --- | --- | --- |
| `grey` | Normal Slime Boss | Neutral | grey |
| `red` | Fire Slime Boss | Fire | red |
| `blue` | Water Slime Boss | Water | blue |
| `yellow` | Electric Slime Boss | Electric | yellow |
| `green` | Grass Slime Boss | Grass | green |
| `purple` | Shadow Slime Boss | Shadow | purple |
| `orange` | Ground Slime Boss | Ground | orange |
| `aquamarine` | Ice Slime Boss | Ice | aquamarine |

All eight variants are required in debug selection, encounter generation,
visual-library construction, automated tests, and asset validation. Production
generation may weight or progression-gate variants, but it must not rely on a
Blue/Green-only implementation path.

## 3. Identity and scale contract

Boss identity must become explicit. `encounter_scale > 1.0` currently acts as a
boss flag, health multiplier, lunge multiplier, geometry switch, and reward
multiplier even though the boss now uses native 32x32 artwork at visual scale
`1.0`. These concepts must not remain coupled.

Introduce or expose typed boss encounter data with separate fields for:

- `is_boss` or boss archetype identity;
- slime variant and combat element;
- native visual/canvas size;
- health, XP, and Soul reward scaling;
- locomotion profile;
- attack reach and lunge profile;
- contact mass; and
- support-wave policy.

Persisted or externally consumed data is not known to depend on
`encounter_scale`; migration compatibility should be added only if that is
confirmed during implementation. Existing metadata may remain temporarily as a
migration seam, but new boss behavior must consume the explicit contract.

## 4. Shared large-slime locomotion

The boss continues to use `SlimeBrain` and the regular explicit frame schedule.
It does not gain an independent `_process()` loop. Boss tuning modifies the
regular slime movement vocabulary rather than replacing it.

Initial tuning targets for playtesting:

| Property | Target |
| --- | ---: |
| Scoot distance | 6-8 px |
| Scoot duration | 0.48-0.62 s |
| Aggro hold | 0.14-0.24 s |
| Squish amplitude | 55-70% of regular slime |
| Movement variance | narrower than regular slime |
| Orbit preference | lower than regular slime |

The current duplicate movement slowdown must be removed. Boss movement must
have one named multiplier/profile rather than multiplying a boss tuning value
by a second spawn-time factor. Preferred attack spacing must derive from the
authored body reach plus the desired preparation gap, not the regular slime's
center-distance ring.

During a scoot, the boss commits to its selected heading. Repathing and orbit
changes occur between scoots so the larger body does not jitter or reverse in
place.

## 5. Basic attack contract

The boss bite remains recognizable as the regular slime bite:

- snapshot facing and target direction at attack start;
- use the authored 32x32 directional body and shadow frames;
- move over several attack frames;
- apply the hit once at the authored impact frame;
- preserve ordinary guard, dodge, element, hitstop, and damage behavior; and
- recover before returning to locomotion.

The boss lunge distance must be authored in world pixels beyond body contact,
not calculated as `encounter_scale * regular_lunge`. The initial playtest range
is 8-12 px over approximately 0.14-0.22 seconds. Collision and attack reach must
use the same body geometry and captured direction.

## 6. Contact weight and player slowdown

Enemy contact gains an explicit mass/inverse-mass response. Walking into an
enemy reduces only the movement component directed into that enemy; tangential
movement remains available so the player can slide around it.

Initial tuning targets:

| Contact | Retained inward movement | Tangential movement |
| --- | ---: | ---: |
| Regular slime | 70-85% | 85-100% |
| Boss slime | 10-30% | 75-100% |

The boss absorbs only a small part of overlap separation. A lunging boss may be
temporarily heavier, but must never trap the player against static geometry.
Swept movement, bounded correction, pinned-actor fallback, and a tangential
escape remain mandatory. Roll and backflip behavior must be explicit and tested
rather than accidentally inheriting walking slowdown.

Use a rounded contact hull or authored contact polygon for the boss. Do not use
the full body AABB as an invisible rectangular wall.

## 7. Jump/slam sequence

The phase owner is `BossJumpSlamComponent`. The required sequence is:

| Phase | Body | Shadows | Boss health UI | Targeting/collision |
| --- | --- | --- | --- | --- |
| Telegraph | Jump frames 0-4, grounded | Normal or jump shadow visible | Visible | Normal |
| Ascent | Jump frames 5-11 translate the sprite above the visible world | Hidden | Hidden | Invulnerable, non-colliding, not attackable |
| Airborne wait | Hold physically above the visible world while support enemies remain | Hidden | Hidden | Boss lock may be retained but cannot receive attacks |
| Descent commit | Sample and freeze the player's current valid floor position | Slam warning shadow appears | Hidden | Boss remains airborne/non-colliding |
| Descent | Slam frames 0-10 translate from offscreen to the frozen anchor | Animated slam shadow | Hidden | Player can leave the impact area |
| Impact | Slam frame 10 reaches the floor and resolves damage once | Impact frame | Hidden | Collision restored after placement validation |
| Recovery | Slam frames 10-14 | Slam recovery frames | Hidden | Boss remains phase-protected |
| Complete | Return to regular idle | Regular animated shadow | Restored | Normal targeting and collision |

The body must be translated upward and downward using `Sprite2D.offset` or an
equivalent presentation transform. Alpha is not the flight mechanism. The
offscreen offset is calculated from the active camera/logical viewport and the
sprite's rendered bounds so every supported display aspect fully clears the
screen.

The landing point is sampled exactly once when descent begins, after the support
wave has cleared. It must not use the player's position captured at jump start
and must not track after descent starts. This gives the player a readable,
stable dodge warning.

## 8. Health and enmity UI

Both boss health presentations are suppressed from launch through the final
slam recovery frame:

- overhead health frame, fill, damage fill, and enmity marker;
- selected-target name, health frame, fills, text, and focus presentation.

HUD presenters consult a phase-owned suppression predicate every frame. A
one-time `visible = false` assignment is insufficient because normal HUD updates
can restore the nodes.

Target lock retention and attackability are separate concepts. The boss may
remain the logical selected target while airborne, but attacks and projectiles
cannot hit it and its UI remains hidden. If the player selects another target,
slam completion must not steal selection back.

The boss overhead bar uses one geometry-derived anchor for the native 32x32
body. The enmity marker is placed relative to the resolved health-bar rectangle,
not from an independent hardcoded world offset.

## 9. Complete visual and palette manifest

Green remains the canonical source-art palette unless dedicated source sheets
are deliberately introduced. One startup-built visual library must produce all
eight roster palettes for every required state.

Required boss body sets:

- idle left and right;
- attack left and right;
- spawn;
- shocked;
- jump; and
- slam.

Required boss shadow sets:

- idle;
- attack left and right;
- spawn;
- shocked;
- jump; and
- slam.

Required regular-slime shadow sets:

- idle;
- attack left and right;
- spawn; and
- every additional authored regular shadow state.

Every manifest entry must validate frame size and count. Every generated body
and shadow frame must be recolored, cached, and warmed before combat. Blue and
red are not exceptions; they must pass through the same boss source pipeline as
grey, yellow, purple, orange, and aquamarine.

The recolor contract must validate the source artwork palette. The current
three exact RGB replacements can leave unmatched green pixels. Implementation
must either enforce an indexed source palette with validation or define all
approved source shades explicitly. Silent partial recoloring is not accepted.

## 10. Visual caching and support-wave performance

No image slicing, per-pixel recoloring, texture creation, actor-tree duplication,
or complete-roster visual rebuilding may occur when a boss phase starts.

During bootstrap or room preparation:

1. Slice each source sheet once through `SpriteFrameLibrary`.
2. Build each required palette set once.
3. Cache frames by source path, frame specification, state, direction, and
   palette.
4. Warm every body and shadow texture once.
5. Preallocate three support-slime actors, including components and visual
   nodes.

During the jump phase:

1. Reset and activate the three reserved actors.
2. Assign references to cached visual sets.
3. Apply boss-variant stats, element, palette, health, and spawn positions.
4. Register only those actors with active runtime collections.

On cleanup, deactivate and return the actors to the room-owned pool. Temporary
support enemies grant no XP, Soul, Chroma, kill telemetry, or persistent room
completion credit.

Acceptance target: activating the complete support wave performs no new texture
or actor allocations and causes no visible frame-time spike in desktop or web
playtests.

## 11. Encounter generation

Production boss selection consumes `SlimeVariantCatalog.VARIANTS`. The selection
policy may use run rank, authored curriculum, weights, or exclusions, but the
implementation path must support every entry.

Requirements:

- Normal bosses are valid lead bosses.
- Fire, Water, Electric, Grass, Shadow, Ground, and Ice bosses are valid lead
  bosses.
- Debug tooling can select each variant deterministically.
- Random tests use seeded selection.
- The support wave inherits the lead boss variant unless a later encounter
  design explicitly defines a mixed wave.
- Element matchups, immunity, damage colors, names, stats, and drops come from
  existing catalogs rather than boss-specific string branches.

## 12. Ownership

| Concern | Owner |
| --- | --- |
| Variant, name, element, stats | `slime_variant_catalog.gd` |
| Matchup calculation | `element_catalog.gd`, combat calculator/runtime |
| Boss phase timing and flight | `boss_jump_slam_component.gd` |
| Regular/boss movement decisions | `slime_brain.gd` |
| Attack timing | `slime_combat_component.gd` |
| Runtime slime orchestration | `slime_runtime_controller.gd` |
| Canonical boss geometry | `boss_slime_authoring.tscn`, `actor_geometry.gd` |
| Contact mass and separation | `actor_collision_system.gd`, `actor_motor.gd` |
| Frame libraries and recoloring | `slime_visual_component.gd`, `sprite_frame_library.gd` |
| Support pool and encounter generation | `room_controller.gd` |
| Overhead UI | `hud_controller.gd` |
| Selected-target UI | `targeting_runtime_controller.gd` |
| Frame order | `gameplay_frame_controller.gd` |

Do not move these behaviors into `gameplay.gd` to avoid boundary work. If a
change crosses three or more owners, define a typed boss phase status/result at
the component boundary rather than adding new `root.get/call` chains.

## 13. Implementation phases

### Phase A - Characterization and identity

- Add tests for all eight variants through regular and boss presentation.
- Record current movement, attack, contact, phase, allocation, and UI behavior.
- Introduce explicit boss identity and separate balance/visual concepts.
- Add deterministic debug variant selection.

Exit: every catalog variant can instantiate as a boss with correct identity,
element, native geometry, and display name.

### Phase B - Visual library and performance

- Add source/frame/palette caches.
- Build and warm the complete body/shadow manifest once.
- Validate source palette and frame counts.
- Preallocate the three support actors.
- Remove phase-time complete-roster rebuilds.

Exit: all eight variants are completely recolored and support activation has no
runtime texture or actor allocation.

### Phase C - Large-slime locomotion and attack

- Remove duplicate boss movement slowdown.
- Add one boss locomotion profile through `SlimeBrain`.
- Make spacing geometry-aware.
- Convert the bite lunge to multi-frame movement.
- Tune cadence and squish against regular slimes.

Exit: blind playtesting identifies the boss as a heavier regular slime rather
than a separate or erratic movement system.

### Phase D - Contact weight

- Add contact mass and inward/tangential movement decomposition.
- Add safe boss authority and pinned-actor fallback.
- Define walk, run, roll, backflip, and attack contact behavior.

Exit: walking into a boss slows the player substantially without trapping them;
the player cannot casually push the boss around.

### Phase E - Jump, slam, and UI

- Implement explicit telegraph/ascent/wait/descent/impact/recovery states.
- Calculate offscreen translation from the active view.
- Hide all shadows during ascent/wait and animate the descent warning shadow.
- Sample the player at descent commit and freeze the anchor.
- Suppress and restore both boss health presentations.
- Correct the shared overhead/enmity anchor.

Exit: the complete sequence is readable, dodgeable, and restores every runtime
state after completion, death, reset, or room transition.

### Phase F - Balance and rollout

- Enable the complete production selection policy.
- Tune movement, contact, attack, slam radius/damage, and repeat interval.
- Verify every element matchup and immunity against every boss variant.
- Update `GAMEPLAY_TUNING.md` with final live values.

Exit: all automated gates and desktop/web playtest checks pass.

## 14. Verification matrix

Automated coverage must include:

- eight boss variants instantiate with correct name, element, palette, and
  native 32x32 geometry;
- every body and shadow state has the expected frame count and complete palette;
- left/right attack shadows follow facing;
- no source-green pixels remain in non-green outputs unless explicitly listed
  as invariant colors;
- support activation performs no frame slicing, recoloring, or actor creation;
- boss scoot cadence and distance stay within the authored profile;
- bite movement advances over multiple frames and hits once;
- regular/boss contact applies distinct mass and slowdown;
- jump body clears every supported logical view;
- all shadows and boss health UI are hidden during ascent/wait;
- descent anchor equals the player's position at descent commit, then remains
  fixed;
- slam body and warning shadow animate at the same anchor;
- impact hits inside and misses outside the authored radius;
- dodge/guard/immunity behavior remains valid;
- phase completion restores collision, targetability, body offset, shadows,
  health UI, and marker placement; and
- reset/death/transition interruption performs the same cleanup.

Scene/playtest coverage must run at all supported display aspects and include at
least Normal, one starter element, one fusion element, Shadow, and Ground's
Electric immunity. Before production rollout, run the complete eight-variant
matrix.

## 15. Non-goals

- Unique attacks or phase rules per element.
- Dual-element bosses.
- New elemental status effects.
- Replacing the existing combat matchup table.
- Mixing intentional stat or matchup changes into the structural visual,
  collision, or performance work.

These require separate design approval after the shared boss foundation is
stable.
