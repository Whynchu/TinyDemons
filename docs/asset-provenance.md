# Tiny Demons — Runtime Asset Provenance

Status: Phase C closeout inventory, 2026-08-22

This document separates assets required by the game at runtime from generated
outputs and reference material. It is part of the fresh-clone review; it does not
grant or imply third-party licensing.

## Runtime asset groups

| Group | Runtime use | Source or generator | Review state |
| --- | --- | --- | --- |
| `assets/artwork/` | Base sprites, room art, HUD textures, and equipment | Authored project artwork | Required and tracked |
| `assets/baked/player/` | Pre-recolored player animation sheets | `tools/bake_palettes.gd` from `assets/artwork/` | Required, deterministic output tracked |
| `assets/sounds/10_Free_RPG_Battle_SFX/` | Battle cues | Existing project sound library | Required cues tracked; license review remains |
| `assets/sounds/10_ui_sfx_free_samples/` | UI/equipment cues | Existing project sound library | Required cues tracked; license review remains |
| `assets/sounds/reconstructed_ui/` | Current UI, alert, pickup, and run-result cues | `tools/sfx_reconstruction/` recipes and render tools | Runtime outputs tracked; provenance/license approval remains |
| `assets/sounds/Soundtrack/` | Main theme | Project soundtrack asset | Required and tracked; ownership review remains |
| `shaders/` | Runtime desaturation/presentation effects | Authored project shader | Required and tracked |

## Generated-output rules

- Palette sheets must be regenerated with `tools/bake_palettes.gd` whenever the
  source player artwork or palette catalog changes. The checked-in outputs are
  deterministic shipping artifacts, not independent source art.
- Reconstructed UI audio must be rendered from compact recipes using the tools
  under `tools/sfx_reconstruction/`. Runtime rendering must not read reference
  audio; the tool README documents that constraint.
- `analysis/`, local virtual environments, generated click experiments, and other
  intermediate reports are not runtime dependencies and remain ignored or outside
  the shipping asset path.
- The authored player HUD layers and their Aseprite source remain under
  `Artwork/`; the matching PNG runtime copies under `assets/artwork/` are the
  imported shipping resources. The generated 4×7 level-number atlas follows the
  same source/runtime split.
- The pause menu exports under `Artwork/` define the authored placement
  reference; the matching runtime panel tile under `assets/artwork/` is used
  by `scenes/menu_panel_8_piece.tscn` to compose the exact eight-piece frame.
- The player's Demon Cloak variant starts from
  `Artwork/TinyDemon_fullsheet_cloaked.png`; the imported runtime copy under
  `assets/artwork/` is sliced into the same rows as the base fullsheet, and
  `tools/bake_palettes.gd` bakes it into `assets/baked/player_cloaked/`.

## Fresh-clone acceptance checks

1. Every `res://` path used by gameplay, scenes, and `SoundManager` resolves from
   tracked files.
2. Palette outputs can be rebuilt from the tracked generator and artwork.
3. The editor import scan completes on the supported Godot version.
4. The smoke suite and main-scene headless boot pass without local-only generated
   files.
5. A release review separately confirms licenses/provenance for third-party and
   reference-derived audio before distribution.

The final item is intentionally a release/compliance decision, not something the
runtime can prove automatically.
