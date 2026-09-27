# Coordination Board

A file-based tether for the AIs and humans working this repo. It records **who
is doing what, now** so two agents sharing the codebase (and the one Godot
editor) stop colliding. It is not a build artifact and not authoritative
documentation — when it disagrees with `docs/AUDIT.md` or the code, the code
wins.

## Why this exists

opencode and codex each connect to the Godot MCP toolkit on their own bridge
process. They share the **Godot editor** (ports 6550–6560), which serializes
writes via the mutation lock and the scene lease — but that only prevents races;
it carries **no identity and no messages**. The only cross-agent signal today is
an anonymous hint ("another session is currently editing …"). This board adds
the missing parts: names, intent, and handoff.

The board is ordinary files both agents already can read and write. Git supplies
history and attribution.

## Files

| File | Owner | Purpose |
| --- | --- | --- |
| `README.md` | shared | This protocol. Change it deliberately. |
| `BOARD.md` | shared | Current claim table — one row per active claim. |
| `status-opencode.md` | opencode only | opencode's live focus, in-flight work, blockers. |
| `status-codex.md` | codex only | codex's live focus, in-flight work, blockers. |
| `journal.md` | append-only | Timestamped event log; both agents append. |

## Rules (keep it cheap)

1. **Own your file.** Write only to `status-<you>.md`; append only to
   `journal.md`; edit `BOARD.md` one row at a time. Never rewrite another
   agent's status file. Ownership-by-file is what keeps concurrent writes from
   clobbering each other — there are no file locks here.
2. **Read before you act.** At the start of a task, read both status files and
   `BOARD.md`. Before touching a file/scene another agent owns, read its status.
3. **Claim before you edit.** Add a row to `BOARD.md` with your name, the
   paths/scenes you are about to touch, and a one-line intent. Keep it coarse:
   directories and scene paths, not every file.
4. **Journal decisions, not progress.** Log `claim`, `handoff`, `blocker`, and
   `done` events — not step-by-step narration. One line each.
5. **Handoff explicitly.** When you stop with work unfinished, write what is
   done, what is left, and the exact next command or file in your status file,
   and add a `handoff` journal entry naming the other agent.
6. **Resolve conflicts in the repo, not the board.** If two claims overlap, the
   lower-priority/later claim yields. Re-check `docs/AUDIT.md` ownership rules in
   `AGENTS.md` for who owns the feature.
7. **Commit at task boundaries.** The board travels with the code in the same
   commit, so history shows intent alongside the change. Do not commit the board
   mid-task with partial claims unless you intend them to be visible.

## Relationship to the Godot scene lease

The board is **intent and coordination**; the toolkit's scene lease is **live
contention**. Both matter:

- Use the board to avoid assigning two agents the same scene or script.
- If you still hit `"another session is currently editing …"`, that is the lease
  working. Do tab-independent work (scripts, project settings, autoloads —
  these bypass the lease) and come back. See
  `addons/godot_mcp_toolkit/CompanionSkills/godot-mcp-toolkit/references/parallel-sessions.md`.

**Never open the same project directory in two Godot editors** — unsupported and
corrupts `user://` (see `addons/godot_mcp_toolkit/docs/multi-instance.md`
Pattern C). One editor, two MCP clients, this board.

## Entry formats

`BOARD.md` row:

```
| opencode | res://scenes/player.tscn, scripts/player_controller.gd | refactor input handling | 2026-09-27 |
```

`journal.md` entry (append at the end):

```
## 2026-09-27T14:05Z — opencode — claim
Player input refactor. Touching scripts/player_controller.gd and
scripts/actor_motor.gd. Codex: hold off on the motor until this lands.
```
