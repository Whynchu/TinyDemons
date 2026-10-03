# Content folder map

This is the navigation guide for Tiny Demons' authored content and runtime assets.

## Where things live

| Path | Purpose | Editing notes |
| --- | --- | --- |
| `scenes/` | Runtime rooms, menus, previews, and authoring scenes | Currently flat. Scene names identify their role; check the scene owner in `AGENTS.md` before changing runtime composition. |
| `Artwork/` | Original/source art and historical art references | Grouped by domain, including enemy families, room art, item icons/pickups, and UI. The root `.gdignore` keeps this archive out of Godot's import scan. See [`Artwork/README.md`](../Artwork/README.md). |
| `assets/artwork/` | Imported game art addressed by runtime scenes and scripts | Existing `res://` paths are kept stable. Use search and the source-art map to find related source files. |
| `assets/baked/` | Processed animation sheets used by actors | Already grouped by actor and presentation variant. |
| `assets/sounds/` | Runtime audio and source libraries | Subfolders group soundtrack, generated/reconstructed UI sounds, self-made effects, and third-party SFX sets. Audio keys are registered in the sound catalog; check that before adding or renaming a sound. |
| `resources/definitions/` | Authored typed content and catalogs | `items/` holds standalone gear definitions; `geometry/` holds family-wide enemy geometry. Other definitions are at the root and searchable by stable ID/name. |
| `resources/tuning/` | Shared gameplay tuning resources | Keep the existing resource paths unless using a reference-aware Godot move. |
| `resources/generated/` | Generated content manifests | Do not hand-edit. Regenerate with `tools/dev.ps1 manifest refresh`; validate with `tools/dev.ps1 manifest check`. |

## Path safety

Runtime scenes, scripts, resources, and generated manifests refer to files through
`res://` paths and resource UIDs. Move active Godot files through the editor's
FileSystem dock, then check the changed references and regenerate manifests.
Do not copy the source archive's folder moves onto `assets/` or `resources/`
without migrating and validating their references. The source art is organized
separately because it is excluded from runtime import and has no project path
references.

For content changes, read [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) and the
trap register in [`authoring-system-plan.md`](authoring-system-plan.md) before
editing `.tres` data.
