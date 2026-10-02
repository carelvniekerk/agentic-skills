# Agent frontmatter reference

Every subagent frontmatter field, and the rules for tools, models, permissions, preloaded skills, MCP servers, hooks, memory and isolation.
Checked against <https://code.claude.com/docs/en/sub-agents> on 2026-10-02.

## Contents

- Parsing rules
- Field table
- Plugin agents
- Tools and disallowedTools
- Model resolution
- Permission modes
- Preloading skills
- MCP servers
- Hooks
- Persistent memory
- Isolation and working directory

## Parsing rules

An agent file is Markdown with YAML frontmatter between `---` markers, and the opening `---` must be the first line.
Only `name` and `description` are required.
Multi-word fields are camelCase and must match the table exactly, because Claude Code ignores an unknown field without reporting it.

A project, personal or managed agent file is skipped without notice in the session when:

- it has no `name`, in which case it is treated as documentation;
- the opening `---` is not on the first line;
- `name` starts with `-` or contains `:`;
- it has a `name` but no `description`;
- the YAML does not parse.

All but the first two write the reason to the debug log (`claude --debug`).
A plugin agent with no `name` or broken YAML still loads, under its filename.
`claude plugin validate <agents-dir>` reports frontmatter that does not parse, but not a missing `name`.

## Field table

| Field | Meaning |
| --- | --- |
| `name` | Unique identifier, passed to hooks as `agent_type`. The filename need not match, and `:` is reserved for plugin scoping |
| `description` | When Claude should delegate. Required |
| `tools` | Comma-separated string or YAML list. Omitted means every tool available to subagents. If nothing in the list resolves, the agent usually fails to launch |
| `disallowedTools` | Tools removed from the inherited or listed pool. A specifier such as `Bash(git push *)` still removes the whole tool |
| `model` | `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` as an alias for `default`. Ignored on plugin agents |
| `maxTurns` | Agentic turn limit, after which the output returns marked partial and can be resumed |
| `skills` | Skills whose full content is injected at startup |
| `mcpServers` | Server names to reuse, or inline server definitions. Ignored on plugin agents |
| `hooks` | Hooks that run while the agent runs. Ignored on plugin agents |
| `memory` | `user`, `project` or `local` persistent memory |
| `background` | `true` keeps the agent in the background even when Claude asks for the foreground |
| `omitClaudeMd` | `true` launches without the user, project and local CLAUDE.md files. Ignored under `--agent` |
| `effort` | `low`, `medium`, `high`, `xhigh` or `max`, overriding the session's level where the model supports it |
| `isolation` | `worktree` runs the agent in a temporary git worktree |
| `color` | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink` or `cyan` |
| `initialPrompt` | First user turn when the agent runs as the main session under `--agent`. Ignored on plugin agents |
| `experimental` | A map, of which only `cacheTtl` (`5m` or `1h`) is read |

There is no `preloaded-skills`, `permissions` or `allowed-tools` field: preloading uses `skills`, and tool scope uses `tools` with a comma-separated value, unlike a skill's space-separated `allowed-tools`.

## Plugin agents

Plugin agents ignore `hooks`, `mcpServers`, `permissionMode` and `initialPrompt`, and nothing warns about it.
Put hooks in `<plugin>/hooks/hooks.json` and servers in `<plugin>/.mcp.json`, where they apply whenever the plugin is enabled.
To keep those fields on one agent, the user has to copy the file into `.claude/agents/` or `~/.claude/agents/`.

A plugin agent is addressed as `<plugin>:<name>`, plus any subfolder of `agents/` (`my-plugin:review:security`).
[Likely] A same-named project or personal agent does not replace the scoped plugin agent, because the two names differ, but Claude can still pick the wrong one, so delete the old copy when moving an agent into a plugin.

## Tools and disallowedTools

Every subagent loses some tools whatever its `tools` field says: `AskUserQuestion`, `EnterPlanMode`, `EndConversation`, `ScheduleWakeup`, `WaitForMcpServers`, `Workflow`, `ExitPlanMode` unless `permissionMode` is `plan`, and `Agent` at the nesting depth limit.

A background subagent, the default in interactive sessions, also keeps only these built-in tools, plus every MCP tool: `Read`, `Grep`, `Glob`, `LSP`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage` and `Artifact`.
The same definition can therefore resolve to different tools in the foreground and the background.

- When both fields are set, `disallowedTools` is applied first and `tools` resolves against what remains.
- Both accept `mcp__<server>` or `mcp__<server>__*` for a whole server, and `disallowedTools: mcp__*` removes every MCP tool.
- Listing `Agent` lets a subagent spawn its own subagents up to the depth limit.
`Agent(worker, researcher)` restricts the spawnable types only for a main-thread agent under `--agent`, and the list is ignored in a subagent.
- `Skill` in `tools` allows runtime skill invocation, which is separate from preloading with `skills`.
Omit `Skill` or disallow it to stop the agent invoking skills.

## Model resolution

Claude Code picks the model from the first of these that is set:

1. the `model` parameter Claude passes on the Agent call;
2. the definition's `model`, where `inherit` means the main conversation's model;
3. `CLAUDE_CODE_SUBAGENT_MODEL`;
4. the main conversation's model.

A family alias such as `opus` resolves to the main conversation's exact model when that model is in the same family.
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` overrides every definition and per-call model.
The organisation's `availableModels` allowlist can substitute another model, with a warning.
Subagents inherit the session's extended-thinking setting, and there is no per-agent thinking field.

## Permission modes

With no `permissionMode`, the agent inherits the main conversation's mode.
When the main conversation runs in `bypassPermissions`, `acceptEdits` or auto mode, the agent runs in that mode and its `permissionMode` is ignored.
Under auto mode the classifier also reviews the subagent's tool calls and its final report.
When the main conversation runs in `default`, `dontAsk` or `plan`, the agent's mode applies, except that `bypassPermissions` keeps the main conversation's mode (since v2.1.267).

So `permissionMode: plan` on a research agent does nothing in a session the user started in acceptEdits.
Enforce read-only through `tools`.

## Preloading skills

`skills` injects each listed skill's full content at startup:

```yaml
skills:
  - api-conventions
  - error-handling-patterns
```

- A skill with `disable-model-invocation: true` cannot be preloaded, and a missing or disabled skill is skipped with a debug-log warning.
- `skills` controls preloading, not access, so the agent can still invoke other skills through the Skill tool.
- Preloaded content costs tokens on every spawn, so preload only what most runs need.
- This is the inverse of a skill with `context: fork`, where the skill supplies the prompt and runs inside an agent type.

## MCP servers

```yaml
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github
```

An inline definition uses the `.mcp.json` schema and connects when the agent starts and disconnects when it finishes, so the main conversation never pays for its tool descriptions.
A string reuses a server the session already has.
Inline servers in a project agent load only after the folder's workspace trust dialog is accepted, and a `-p` run does not count.
Managed MCP policies, `--strict-mcp-config` and `--bare` apply to agent servers as well.
The field also applies when the agent runs as the main session under `--agent`.

## Hooks

Frontmatter hooks use the settings format and run only while the agent runs, and a `Stop` hook there becomes `SubagentStop`.
Under `--agent` they run alongside settings hooks.
A project agent's frontmatter hooks need the workspace trust dialog accepted for that folder, and a `-p` run does not count.
Settings, managed and plugin hooks also fire for a subagent's tool calls, and `SubagentStart` and `SubagentStop` in settings match on the agent's name, or `^plugin:name$` for a plugin agent.
Use `meta:create-hook` to write the hook itself.

## Persistent memory

| Scope | Directory |
| --- | --- |
| `user` | `~/.claude/agent-memory/<name>/` |
| `project` | `.claude/agent-memory/<name>/`, shareable through version control |
| `local` | `.claude/agent-memory-local/<name>/`, kept out of version control |

With memory on, the system prompt gains memory instructions and the first 200 lines or 25 KB of `MEMORY.md`, and `Read`, `Write` and `Edit` are enabled automatically.
That last point gives a read-only agent write access, limited only by its instructions, so weigh it before adding memory to a reviewer.
Memory has no effect when auto memory is turned off.
Tell the agent in its body when to read and update its memory, or the directory stays empty.

## Isolation and working directory

A subagent starts in the main conversation's working directory, and `cd` does not persist between its Bash calls.
`isolation: worktree` gives it a temporary worktree branched from the default branch rather than the session's `HEAD`, removed automatically if it makes no changes.
Claude Code refuses Bash commands inside an isolated agent that would run git against the main checkout.
Use isolation for experimental edits, parallel agents that would collide, and changes that need review before merging.
