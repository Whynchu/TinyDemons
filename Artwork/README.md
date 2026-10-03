# Source artwork archive

This folder holds original/editable art and historical references. It is not
loaded by the game; `assets/artwork/` contains the imported files referenced by
runtime scenes and scripts. The `.gdignore` at this folder's root keeps this
archive out of Godot's import scan.

## Folder map

- `characters/player/` — player source sheets and variants; `reference_frames/`
  contains attack-timing and pose references.
- `characters/enemies/slimes/`, `skeletons/`, and `boss_slime/` — source and
  exported enemy art grouped by family.
- `characters/enemies/concepts/` — exploratory enemy art.
- `environment/rooms/` — doors, walls, tiles, and room props.
- `environment/stone_accents/` — reusable floor and wall accents.
- `environment/maps/` — authored and historical puzzle-map art.
- `effects/` — combat and movement effects.
- `items/equipment_icons/` — inventory slot and equipment icons.
- `items/pickups/` — equipment and currency pickup art.
- `ui/` — HUD, menus, controls, icons, portraits, and branding.
- `references/` — map drafts, palette references, and issue captures.

Original filenames are preserved so art can be matched to the imported runtime
counterpart by name. Keep new source files in the closest matching domain
folder. When moving runtime assets, use the Godot editor and update references;
these archive moves do not change runtime paths.
