# Two-band map lighting

Status: implemented for 0.3.80, 2026-10-08

## Requested result

- Two illuminated brightness bands with crisp pixel edges.
- Rest-fire light footprints are 1.5x the stable player footprint, with +/-3%
  size flicker and stronger brightness flicker.
- Player footprint is fixed from the authored idle silhouette across every
  animation and facing direction, with 25% less width and height than 0.3.79.
- Locked chest art stays dim; normal collectible chest art is unshaded.
- Floor-aligned 2:1 actor light ovals, sized from the full authored sprite bounds.
- Overlapping lights share coverage without adding brightness. Identical lights
  must produce exactly the same illumination as one light.
- Darkness and illumination apply to map scenery. Characters, equipment, loot,
  spell artwork, feedback and UI keep their own colors and alpha.

## Implementation sequence and ownership

1. `ActorLightingController` continues to own light sources and authored sprite
   fitting. Its actor footprints become world-aligned isometric ovals. Sources
   register in a group and disable the native additive pass.
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
5. Keep the current frame order: refresh actor poses and light footprints, then
   upload the map field. No new `_process()` callback. The Web shader uses a
   bounded 64-source array; actor, fire and spell sources take priority over
   pickup glows, and nearby sources break ties if the budget is exceeded.

## Acceptance and verification

- Assert two nonzero radial levels, empty exterior, and nearest filtering.
- Assert actor ovals remain 2:1 and floor-aligned after actor scaling/rotation;
  enemy/NPC authored corners lie within coverage. Player light keeps the smaller
  idle reference across walking, attack, roll and facing transitions.
- Sample identical overlapping lights and compare against a single source.
  Compare mixed-color and inner/outer overlap in reversed source order.
- Assert hidden, freed, zero-energy and off-screen-budget sources are excluded.
- Assert map-only material enrollment, including newly mounted map children;
  plain foreground sprites remain untouched.
- Assert flame size stays larger than the fixed player reference and source energy/fades are
  captured without enabling native additive lighting.
- Run the focused lighting smoke, strict composition audit, manifest validation,
  and Web export. Report rendered verification separately from CPU/shader checks.

## Boundaries and risks

Verification: focused actor-lighting smoke passes, including OpenGL compatibility
rendered pixel checks for both bands, map darkness, bright foreground and
non-additive overlap. Strict composition and test-manifest validation pass.
Web export and Pages deployment verification follows the release workflow.

No collision, combat, authored definition or room-generation behavior changes.
The shader is unshaded because it owns the ambient and light-field calculation.
Its 64-source budget avoids an unbounded Web fragment loop. Map enrollment uses
explicit scene paths and renderable types, excludes debug guides and gameplay
descendants of props, and never substitutes an existing unrelated shader.
