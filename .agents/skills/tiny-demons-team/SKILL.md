---
name: tiny-demons-team
description: Coordinate bounded multi-agent implementation for Tiny Demons composition or content-authoring work when the user explicitly requests delegation or parallel work.
---

# Tiny Demons team work

Use this skill only for explicitly delegated composition or authoring tasks. For
ordinary code changes, work directly. The parent agent owns task selection,
coordination, integration, and technical acceptance. Preserve the user's final
product and visual acceptance.

## Before assigning work

Read the repo's `AGENTS.md`, `docs/agent-workflow.md`, and the relevant source
authority docs. For composition and authoring work, consult
`docs/composition-team-execution-plan.md` when present, plus
`docs/authoring-system-plan.md` and its trap register. Check `docs/AUDIT.md`,
`docs/CONTENT_AUTHORING.md`, and ownership guidance as applicable. Source and
runtime consumers decide what is true; plans describe intended direction.

The active subagent cap is the capacity actually available in the current
session. The project config currently allows one concurrent subagent in addition
to the parent, so run child assignments serially. Do not alter
project or global concurrency settings to make room. Pip, Thorn, and Hexley are
read-only advisors: the parent chooses any advisor needed, and advisors do not
spawn workers. Workers likewise do not spawn more agents.

## Delegate a bounded slice

Give each worker a self-contained packet containing:

- the exact branch and absolute worktree path to use;
- owned paths and a clear file boundary for its changes;
- the concrete outcome and acceptance/stop condition;
- source and authority docs to consult, including relevant authoring traps;
- preservation constraints and meaningful verification evidence requested.

State that the worker is sharing the codebase: it must preserve concurrent
changes, never revert work by others, and adapt to edits it encounters. Keep
workers out of the Godot editor/MCP bridge and external publication. The parent
owns the coordination board/status files, editor bridge, integration, commits,
and any push or publication explicitly authorized by the user.

Choose model effort for the work: Luna LOW suits mechanical bounded edits and
independent navigation; Luna MAX suits contract design, cross-file reasoning,
and code integration. Honor explicit user model/effort choices. Keep each
assignment narrow enough for its chosen effort and report assumptions early.

With Codex's collaboration API, use `agent_type: worker`,
`model: gpt-6-luna`, and `reasoning_effort: low` or `max`. Model overrides
require `fork_turns: none`, so include the full packet rather than relying on
inherited conversation. Advisor types are `pip`, `thorn`, and `hexley`.

## Preserve project contracts

Follow `AGENTS.md` verification restrictions, including MCP-first editor safety
and supervised standalone-run rules. Confirm the editor peer's actual project
before relying on `res://` evidence:
a peer attached to a different worktree does not validate the assigned branch.
Use the owning feature boundary and existing frame schedule. Preserve actor
geometry, stable IDs, save
compatibility, and gameplay balance unless the authorized task explicitly
changes them. Do not delete or replace assets as a shortcut. For content slices,
verify the actual runtime consumer before treating authored fields as
authoritative; consult the authoring plan's trap register.

## Review and hand off

Require a concise handoff with changed paths, key decisions/assumptions,
verification performed and results, known gaps, and any required next action.
The parent checks the diff and the acceptance condition before integrating.
Ask the worker to report an independent usability exercise where relevant:
what task they completed, time spent, docs they needed, errors or ambiguity
encountered, and any runtime edits made. This is process evidence, not proof of
player-facing quality. Keep rendered or in-editor visual acceptance as a
separate human review when the task requires it.

Stop and hand back when scope expands, ownership is unclear, a preservation
contract conflicts with the requested change, or the requested verification
requires editor access or external mutation. Report the blocker and concrete
evidence; do not broaden the assignment yourself.
