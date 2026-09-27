# Tiny Demons Agent Workflow

Status: current project-scoped Codex and opencode advisor setup

Updated: 2026-09-27

Scope: use Pip, Thorn, and Hexley for focused advice on project priorities and
feature decisions

Owner: repository contributors

Current code: the three roles are defined twice, once per client — Codex in
`.codex/agents/<role>.toml`, opencode in `.opencode/agent/<role>.md`. Both are
read-only advisors (Codex `sandbox_mode = "read-only"`; opencode `edit: deny` +
`bash: ask`) and do not implement changes.

Verification: inspect the agent definitions and invoke each agent by name in a
Codex session that supports custom agents, or delegate to it by name via the
Task tool in opencode

Supersedes: the earlier experimental setup discussed in the 2026-09-27 Codex
session history

## The three roles

| Agent | Specialty | Best question |
|---|---|---|
| Pip | Planning and delivery | What is the next bounded slice, and how will we know it is done? |
| Thorn | Source and architecture audit | What does the code actually do, who owns it, and what evidence is missing? |
| Hexley | Player-facing game design | What changes for the player, and does it create a meaningful choice or better feedback? |

All three are advisors. Their definitions prohibit file edits and further
delegation. They inherit the parent session's model and permissions. Use them
when a decision benefits from a specialist perspective; routine implementation
does not need all three.

## Ask about the next repo priority

Run them one at a time so their evidence and recommendations stay easy to
compare:

1. Ask Thorn to identify the strongest current code, behavior, and verification
   findings that should influence the next priority.
2. Ask Hexley to assess which unresolved player-facing problem deserves
   attention, using the current product and design contracts.
3. Give both summaries to Pip and ask for one sequenced next slice with owner,
   acceptance evidence, and focused verification.

Example prompts:

```text
Ask Thorn for a read-only audit of the current repo's strongest next-priority
candidates. Ground each in source and current authority docs. Do not edit files.
```

```text
Ask Hexley which unresolved player-facing issue should be prioritized next.
Use the ratified design contracts and distinguish evidence from inference. Do
not edit files.
```

```text
Ask Pip to compare these Thorn and Hexley summaries and recommend one bounded
next slice. Include owner, dependencies, acceptance evidence, and safe focused
verification. Do not edit files.
```

For a single feature decision, ask only the agent whose specialty fits. Request
parallel work explicitly only when the questions are independent and you want
their answers at the same time.

## Invocation and troubleshooting

The TOML files in `.codex/agents/` define Codex custom agents. Start a new
Codex session after adding or changing agent files if the current session does
not recognize them, then invoke the role by name in a direct delegation request.
If the current client does not expose custom-agent delegation, use the role
description and instructions as a prompt manually. See the official
[Codex subagents and custom agents guide](https://learn.chatgpt.com/docs/agent-configuration/subagents)
for current client support and configuration details.

The Markdown files in `.opencode/agent/` define the same three roles as opencode
subagents. opencode loads config at startup, so quit and restart opencode after
adding or changing an agent file. Delegate by name via the Task tool (for
example, subagent type `thorn`); opencode only exposes them as subagents, so
there is no separate primary-agent entry point to enable.

Project-scoped delegation is enabled in `.codex/config.toml` with one
concurrent subagent slot. The user's global Codex config still contains the
commented legacy `multi_agent = true` entry left from the earlier
terminal-launch diagnosis; this setup does not change global settings. If the
current Codex client does not recognize the project agents, start a new session
and check the current custom-agent support. Keep requests read-only and start
with one agent at a time.

Do not ask the agents to run the full smoke inventory. Follow the MCP-first and
supervised-run instructions in `AGENTS.md` for any requested verification.

## Design goals and limits

- The agents apply different evidence standards; they are reviewers, not three
  interchangeable voices.
- Thorn establishes source-backed reality, Hexley evaluates player outcomes,
  and Pip turns an accepted direction into verifiable work.
- Their advice does not replace the user's product decisions or the repository's
  authority documents.
- Read-only instructions are prompt-level boundaries, not a security sandbox.
  The delegated session still inherits the parent session's actual permissions.
- Keep or revise the setup based on whether the agents produce specific,
  evidence-backed recommendations that improve decisions.
