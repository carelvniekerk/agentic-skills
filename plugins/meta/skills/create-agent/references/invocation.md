# Invoking and running agents

How agents get invoked, where they run, what they start with, and how to resume, nest, fork and disable them.
Checked against <https://code.claude.com/docs/en/sub-agents> on 2026-10-02.

## Contents

- Ways to invoke an agent
- What an agent starts with
- Foreground and background
- Forks
- Whole-session agents
- --agents JSON
- Nesting and concurrency
- Resuming
- Disabling agents
- Common patterns

## Ways to invoke an agent

| Way | Guarantee |
| --- | --- |
| Automatic delegation | Claude decides from the request, the agent's `description` and the other agents' descriptions |
| Naming it in the prompt ("use the test-runner subagent") | Claude usually delegates, but may not |
| `@`-mention, or typing `@agent-<name>` or `@agent-<plugin>:<name>` | That agent runs. Claude still writes its task prompt |
| `claude --agent <name>` or the `agent` setting | The whole session runs as that agent |

The transcript shows a delegation as a row with the agent's name and a short task description.
`/tasks` lists running and recently finished subagents with their models.
The `/agents` wizard was removed in v2.1.198, so create and edit agents as files.

## What an agent starts with

A non-fork subagent starts with a fresh context containing:

- its own system prompt plus environment details, not the Claude Code system prompt;
- the task message Claude writes when delegating;
- the CLAUDE.md hierarchy the main conversation loads, unless `omitClaudeMd` is set (Explore and Plan skip it);
- a git status snapshot (Explore and Plan skip it);
- any preloaded skills;
- a roster of named agents, when it has `SendMessage` and another agent has a name.

It does not receive the conversation history, skills already invoked, files already read, the output style or the main conversation's auto memory.
A rule the agent must follow that is not in its body or CLAUDE.md has to go in the delegation prompt.
Its context window is sized by its own model.

Claude Code scans each subagent's final report before Claude reads it, and marks text that imitates harness tags or mentions permission settings.
The scan is not a security boundary, so restrict what the agent can reach.

## Foreground and background

- A foreground subagent blocks the main conversation, and its permission prompts pass through to the user.
- A background subagent runs concurrently.
Its permission prompts surface in the main session naming the agent, and a lasting grant applies to the whole session.
It has the reduced built-in tool set listed in the frontmatter reference.

Claude Code picks the mode from the first rule that applies:

1. A subagent spawned by an in-process agent-team teammate runs in the foreground.
2. With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, everything runs in the foreground.
3. With fork mode on, the interactive default, every spawned subagent runs in the background.
4. With fork mode off (`-p` and the Agent SDK by default), Claude chooses, and `background: true` keeps an agent in the background.

Ctrl+B moves a running task to the background.
A background subagent's result arrives as a completion notification in a later turn.

## Forks

A fork inherits the whole conversation, system prompt, tools and model, and shares the main session's prompt cache, so it is cheaper than a fresh subagent for work that needs the same context.
Only its final result returns.

- Start one with `/subtask <task>` (v2.1.212 and later, `/fork` before that or when agent view is off).
- Fork mode is on by default in interactive sessions and off in `-p` and the SDK.
`CLAUDE_CODE_FORK_SUBAGENT=1` turns it on everywhere, and `0` turns it off.
- Deny `Agent(fork)` to keep fork mode on but stop Claude spawning forks.
- A fork cannot spawn further forks, and `isolation: "worktree"` on the Agent call gives it its own worktree.

Prefer a fork when a named agent would need too much background, and a named agent when the job needs its own tool scope, model or return contract.

## Whole-session agents

`claude --agent <name>`, or `"agent": "<name>"` in `.claude/settings.json`, runs the main thread as that agent, with its tools, model and system prompt in place of the Claude Code system prompt.
CLAUDE.md still loads, even with `omitClaudeMd`.
`initialPrompt` is submitted as the first turn, and frontmatter hooks run alongside settings hooks.
The CLI flag overrides the setting, the choice persists across resume, and a plugin agent can be named bare or scoped.

## --agents JSON

```bash
claude --agents '{
  "release-checker": {
    "description": "Verifies release readiness: changelog, version, tag and tests.",
    "prompt": "Check that CHANGELOG.md has an entry for the current version, the package version matches the latest git tag, and the tests pass. Return PASS or FAIL with the reasons.",
    "tools": ["Read", "Bash", "Glob"],
    "model": "haiku"
  }
}' --agent release-checker -p "Run the release readiness check."
```

Each key is an agent name, and `prompt` replaces the Markdown body.
The definition accepts `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, `skills`, `initialPrompt`, `memory`, `effort`, `background`, `omitClaudeMd` and `isolation`, and ignores `color` and `experimental`.
In `-p` mode, `--agents` also accepts a path to a JSON file (v2.1.281 and later).
These agents exist only for that session.

## Nesting and concurrency

A subagent can spawn its own subagents up to three layers below the main conversation, after which `Agent` is withheld.
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` changes the limit, and `1` turns nesting off.
Leave `Agent` out of `tools` for an agent that should never delegate.
At most 20 subagents run at once by default (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).

## Resuming

Each invocation is a new instance.
To continue one, Claude sends it a message with `SendMessage`, addressed by agent ID or name, which does not need agent teams enabled.
The resumed run keeps its history and its original tool set.
Explore and Plan return no agent ID and cannot be resumed.
A subagent the user stopped with `x` in `/tasks` does not auto-resume.
Transcripts live at `~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`, survive main-conversation compaction, and are deleted after `cleanupPeriodDays` (30 by default).
Subagents auto-compact like the main conversation, and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` applies to them.

## Disabling agents

```json
{ "permissions": { "deny": ["Agent(Explore)", "Agent(my-custom-agent)"] } }
```

`Agent(<name>)` matches the `name` field and works for built-in and custom agents, as does `claude --disallowedTools "Agent(Explore)"`.
Denying `Agent` itself stops all delegation.
`CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` removes only Explore and Plan.

## Common patterns

- **Isolate high-volume work**: "Use a subagent to run the test suite and report only the failing tests with their error messages."
- **Parallel research**: separate subagents for independent areas, then a synthesis in the main conversation.
Each result still lands in the main context, so many detailed results add up.
- **Chains**: one agent's result feeds the next, with Claude passing the relevant part along.
