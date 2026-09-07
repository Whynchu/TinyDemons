# Asset And Reference Audit

Status: conservative static audit

Audit date: 2026-09-07

This report identifies asset classes and reference mechanisms. It is not an
orphan/deletion report. Godot imports, directory catalogs, generated frame
conventions, previews, tests, and export filters make simple text search unsafe
for deletion decisions.

## Asset Scale

Git-tracked assets currently break down as follows:

| Area | Files | Role |
|---|---:|---|
| `assets/artwork/` | 279 | authored runtime art, UI, room art, icons, source sheets |
| `assets/baked/` | 480 | deterministic player animation/palette output |
| `assets/sounds/` | 679 | source/import pairs, music, SFX, reconstructed and generated audio |
| Total | 1,438 | includes imported metadata and source variants |

Tracked extensions include 379 PNG files, 285 WAV files, 42 OGG files, 22
BFXR files, one MP3, one Aseprite file, one TRES resource, and 707 Godot
`.import` files.

The high `.import` count is expected for a Godot project and does not mean the
underlying source files are duplicated.

## Reference Classes

### Authored artwork

Primary location: `assets/artwork/`

Referenced by:

- scene `ext_resource` entries;
- menu and HUD layout scripts;
- actor animation and visual components;
- test fixtures and scene smoke tests;
- editor layout guides; and
- Web PWA icon settings.

Representative owners:

- `main.tscn` for room, actor, and core presentation art;
- `player_hud.tscn` and `player_hud.gd` for HUD art;
- `screen_state_controller.gd` and menu layout scripts for menu art;
- `slime_visual_component.gd` for slime animation sheets;
- `player_animation_component.gd` for player sheets and palette variants.

### Baked animation output

Primary location: `assets/baked/`

`tools/bake_palettes.gd` identifies this as deterministic output generated from
source artwork. The animation library constructs paths by palette and animation
name, so an individual baked PNG may have no direct literal reference.

Treat this entire class as runtime-required until:

1. the source-to-output generation contract is verified;
2. the requested palette/animation matrix is known; and
3. a clean regeneration test succeeds.

### Audio

Primary location: `assets/sounds/`

`sound_clip_catalog.gd` owns directory conventions including:

- `10_Free_RPG_Battle_SFX/`;
- `10_ui_sfx_free_samples/`;
- `reconstructed_ui/`;
- `Selfmade FX/`; and
- `Soundtrack/`.

Audio is selected through catalog names and preferred OGG/WAV paths. A sound
file without a direct script reference may still be part of the catalog or a
source/import pair.

Generated/analysis output includes paths such as:

- `assets/sounds/generated_ui/`;
- `assets/sounds/generated_clicks_v2/`; and
- SFX reconstruction workspace outputs.

These are candidates for separate production/reference classification, not
automatic deletion.

### Export-only assets

The Web preset directly references:

- `tinydemonicon_pwa_144.png`;
- `tinydemonicon_pwa_180.png`; and
- `tinydemonicon_pwa_512.png`.

The Web export includes all resources under the current preset. This means an
asset can affect build size or export behavior even when it is not loaded by the
desktop boot path.

## Dynamic Reference Owners

| Owner | Mechanism | Asset implication |
|---|---|---|
| `sound_clip_catalog.gd` | catalog paths and preferred-format fallback | scan audio directories, not just literals |
| `player_animation_component.gd` | palette/animation path construction | preserve baked frame matrix |
| `sprite_frame_library.gd` | accepts runtime texture paths | inspect all callers |
| `slime_visual_component.gd` | explicit frame-sheet paths | preserve attack/shock/spawn variants |
| `hud_controller.gd` | runtime texture loading and image processing | HUD assets may be built dynamically |
| `gameplay_state.gd` | `_load_texture_or_null()` | paths can originate from state/config |
| `pickup_runtime_controller.gd` | item icon paths | catalog-generated gear can load art indirectly |
| `ui_layout_guide.gd` | editor preview texture paths | editor-only does not mean disposable without workflow review |
| `dungeon_minimap_controller.gd` | image file path loading | map preview/export assets need separate classification |
| export preset | PWA icon paths and all-resource filtering | export-only dependencies are real dependencies |

## Reference Findings

### High-confidence required

- Core artwork referenced by `main.tscn`, `player_hud.tscn`, and production menu scenes.
- Baked player animation output used by palette/frame libraries.
- Sound catalog directories and their selected runtime cues.
- Web PWA icons.
- Source sheets used by deterministic bake tools.
- Imported metadata paired with actively used source resources.

### Requires classification

- SFX reconstruction workspaces and recipe files.
- Generated UI/click candidates.
- Preview-only art and mockup-derived source images.
- Duplicate WAV/OGG pairs where the catalog may prefer one format.
- Large source sheets whose output is already baked.

### Not enough evidence for deletion

- Files found only in documentation.
- Files with no literal `res://` reference.
- Individual baked frames.
- Individual audio files in catalog directories.
- Scene metadata paths used by editor tools.
- Imported `.import` files.

## Recommended Next Tooling

Before cleanup, build a normalized report with these columns:

```text
path
asset_class
source_or_generated
referenced_by_scenes
referenced_by_scripts
referenced_by_catalog
referenced_by_tests
referenced_by_export
import_pair
duplicate_hash
deletion_confidence
```

The scanner should normalize slash direction and case, resolve `.import` pairs,
recognize directory catalogs, and report unknown dynamic paths separately.

## Cleanup Policy

- Do not delete runtime assets from this report alone.
- Do not delete baked output until regeneration is verified.
- Do not delete audio based on WAV/OGG duplication without checking the catalog.
- Keep external reference material outside the runtime project where possible.
- Treat generated analysis output as a separate class from generated runtime output.
- Record every cleanup decision in `docs/cleanup-ledger.md`.
