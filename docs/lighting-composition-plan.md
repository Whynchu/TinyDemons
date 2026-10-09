# Two-band map lighting

Status: actor-light removal and ambient lift applied 2026-10-08; visual review pending

## Requested result

- Two illuminated brightness bands with crisp pixel edges.
- Rest-fire inner-band contribution has a source-specific 0.9 gain (2026-10-09);
  the outer band retains its existing strength. Rendered acceptance is pending.
- Map scenery uses a 0.64 ambient baseline, slightly lifted from 0.60 while
  retaining the dark-room look.
- Rest-fire light footprints are 1.5x the stable player reference footprint, with +/-3%
  size flicker and stronger brightness flicker.
- The player reference footprint is fixed from the authored idle silhouette
  across every animation and facing direction, with 25% less width and height
  than 0.3.79.
- Locked chest art stays dim; normal collectible chest art is unshaded.
- Actor sprites do not emit map-light footprints; fire, pickups, weapons and
  spell impacts keep their authored lights.
- Overlapping lights share coverage without adding brightness. Identical lights
  must produce exactly the same illumination as one light.
- Darkness and illumination apply to map scenery. Characters, equipment, loot,
  spell artwork, feedback and UI keep their own colors and alpha.

## Implementation sequence and ownership

1. `ActorLightingController` owns fitted source construction for fire and effect
   lights. Player, enemy, attack and NPC sprites do not create map-light sources.
   The player's authored idle bounds remain the stable size reference for rest
   fire. Sources register in a group and disable the native additive pass.
2. `MapLightingController`, an explicitly scheduled scene component, captures
   visible source transforms, colors and energy. A shared map shader evaluates
   the strongest contribution at each world pixel. Equal strongest contributors
   share an averaged tint; brightness is never summed.
3. Only map sprites, tiles, floor underlay, chest and firepit receive the map
   material. Newly added map artwork is enrolled through the scene-tree signal.
   Global CanvasModulate becomes neutral, preserving all foreground art by
   default. This replaces the blocked broad foreground-material migration.
4. The shared radial definition has inner alpha 0.78, outer alpha 0.40 and zero
   outside. The inner radius is 0.58 of the outer radius. Fire footprint sizing
   uses the player's fixed idle reference rather than a texture-scale constant.
5. Keep the current frame order: update actor/effect poses, then upload the map
   field. No new `_process()` callback. The Web shader uses a bounded 64-source
   array; fire and spell/effect sources take priority over pickup glows, and
   nearby sources break ties if the budget is exceeded.

## Acceptance and verification

- Assert two nonzero radial levels, empty exterior, and nearest filtering.
- Assert normal runtime player, enemy, attack and NPC sprites do not register
  map-light sources, and map scenery remains readable at the 0.64 ambient level.
- Sample identical overlapping lights and compare against a single source.
  Compare mixed-color and inner/outer overlap in reversed source order.
- Assert hidden, freed, zero-energy and off-screen-budget sources are excluded.
- Assert map-only material enrollment, including newly mounted map children;
  plain foreground sprites remain untouched.
- Assert flame size stays larger than the fixed player reference and source
  energy/fades are captured without enabling native additive lighting.
- Run the focused lighting smoke, strict composition audit, manifest validation,
  and Web export. Report rendered verification separately from CPU/shader checks.

## Boundaries and risks

The 0.3.80 baseline passed the focused actor-lighting smoke, including OpenGL
compatibility pixel checks for both bands, map darkness, bright foreground and
non-additive overlap. The actor-light removal and 0.04 ambient lift have not
received in-editor visual review yet.

No collision, combat, authored definition or room-generation behavior changes.
The shader is unshaded because it owns the ambient and light-field calculation.
Its 64-source budget avoids an unbounded Web fragment loop. Map enrollment uses
explicit scene paths and renderable types, excludes debug guides and gameplay
descendants of props, and never substitutes an existing unrelated shader.
