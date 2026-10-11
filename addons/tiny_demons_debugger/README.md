# Tiny Demons debugger reader

This project-local Godot MCP extension exposes the debugger panel retained Errors list to MCP clients. It returns errors and warnings, project source locations, and source and stack details without changing selection or clearing the panel.

## Use

The project plugin discovers `addons/tiny_demons_debugger/debugger_extension.gd`. After creating or editing the extension, call `extensions_refresh`. Reconnect the MCP client if its tool list is cached. Call `tiny_demons_debugger_read_errors` with optional pagination:

- `offset`: zero-based entry offset (default 0).
- `limit`: 1–50 entries (default 20).

The result includes total/error/warning counts, `has_more` and `next_offset`. Entry text is marked as untrusted editor content. Godot retains debugger entries for the editor session; start the project to refresh the session after source changes.

## Compatibility

Godot does not expose the Errors list as a public editor API. This reader locates the native `ScriptEditorDebugger` session Errors tab and reads its `Tree` rows. This structure was verified with Godot 4.7.2 and can change in an engine update. If the tree is not found, the command returns `UNSUPPORTED` rather than claiming the list is empty. The reader never clears entries or starts, stops, or sends input to a game.
