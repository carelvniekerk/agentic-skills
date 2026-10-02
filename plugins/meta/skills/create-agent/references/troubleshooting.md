# Troubleshooting agents

Symptoms after an agent is in use, their usual causes and the fix for each, followed by the security review to run before committing or publishing an agent.

## Contents

- The agent never loads
- Claude never delegates to it
- Claude delegates to the wrong agent
- The agent has too much access
- The agent floods the main conversation
- A field has no effect
- The agent cannot use a tool it lists
- Edits do not take effect
- Memory stays empty
- Resume does not work
- Security review

## The agent never loads

- The file is missing `name` or `description`, the `name` starts with `-` or contains `:`, or the YAML does not parse.
Project and personal files with these problems are skipped, and `claude --debug` says why.
- The opening `---` is not the first line, so the file reads as documentation.
- Two files in the same agents tree share a `name`, and only one loads, chosen by read order.
`/doctor` reports the duplicates.
- The `agents` directory was created after the session started, which needs a restart.

Run `claude plugin validate <agents-dir>` to catch YAML that does not parse.

## Claude never delegates to it

- The description lacks the words and situations the user produces.
Add them, with informal versions, and name the scope precisely.
- The task is small enough for Claude to do directly.
That is expected, and a skill may suit it better.
- A higher-priority definition with the same name shadows it (managed, then `--agents`, then project, then personal, then plugin).
- `Agent(<name>)` is in `permissions.deny`, or `Agent` itself is denied.

Confirm a fix with several fresh-session prompts or `claude plugin eval`, never with one retried prompt or an `@`-mention.

## Claude delegates to the wrong agent

Two descriptions overlap.
Narrow one by language, framework, file type or input kind, or merge the two agents.
Review the other agents in all scopes before adding one.

## The agent has too much access

- `tools` is omitted, so it inherited every tool and MCP server.
Set it explicitly.
- `permissionMode` was meant to restrict it, but the main conversation runs in `bypassPermissions`, `acceptEdits` or auto mode, which override it, or it is a plugin agent, which ignores it.
- `memory` is set, which enables `Read`, `Write` and `Edit`.
- `Agent` is in its tools, so it can spawn subagents with their own scope.

## The agent floods the main conversation

The body has no return contract.
Name the sections to return, a length limit and what to leave out ("Do not include raw command output").
If the work is small enough that the summary is as long as the raw output, the job did not need a subagent.

## A field has no effect

- It is misspelt or not camelCase (`disallowed-tools`, `max_turns`), and Claude Code ignores unknown fields silently.
- It is `hooks`, `mcpServers`, `permissionMode` or `initialPrompt` on a plugin agent.
Move hooks to `hooks/hooks.json` and servers to `.mcp.json`.
- It is `omitClaudeMd` or `initialPrompt` used outside the mode where it applies.
- A project agent's frontmatter hooks or inline MCP servers need the folder's workspace trust dialog accepted, and a `-p` run does not count.
- `model` is overridden by a per-call model, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` or the `availableModels` allowlist.
`/tasks` shows the model the agent runs on.

## The agent cannot use a tool it lists

- The tool is one every subagent loses, such as `AskUserQuestion` or `EnterPlanMode`.
- The agent runs in the background, which keeps a reduced built-in set.
- `disallowedTools` contains the tool, possibly with a specifier, which still removes the whole tool.
- `Skill` is missing from `tools`, so runtime skill invocation is off.
- A preloaded skill sets `disable-model-invocation: true`, so it cannot be preloaded.

## Edits do not take effect

Claude Code watches `.claude/agents/` and `~/.claude/agents/` and uses the new definition on the next delegation.
Restart only after creating a scope's first `agents` directory, after editing an agent under an `--add-dir` directory, or in a session started with `--disable-slash-commands`.
An installed plugin needs `/reload-plugins` or an update.

## Memory stays empty

The body never tells the agent to read or update its memory.
Add both instructions, and ask for it in the delegation prompt.
Memory also has no effect while auto memory is turned off.

## Resume does not work

- Explore and Plan return no agent ID and cannot be resumed.
- The user stopped the agent with `x`, which prevents auto-resume.
- The transcript was deleted after `cleanupPeriodDays`.

## Security review

- Anyone who clones a repository and accepts workspace trust gets a project agent's tools, inline MCP servers and hooks.
- Inline MCP servers run their command on every spawn, so audit the command and arguments.
- `project` memory is committed, so keep secrets and personal data out of what the agent writes there.
- An agent that sends repository content or user data to an external service needs the user's agreement, and under DSGVO a check of what personal data it carries.
- Plugin agents ignore hooks, MCP servers and permission modes for security, so a plugin's guarantees rest on `tools` and plugin-level hooks.
