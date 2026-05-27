---
name: create-hook
description:
    Author, edit, and debug Claude Code hooks (entries under `hooks` in settings.json, plugin `hooks/hooks.json`, or skill/agent frontmatter) following the official hooks reference.
    Use this skill aggressively whenever the user mentions creating, writing, editing, debugging, configuring, or distributing a hook — even if they only say "add a PreToolUse hook", "block rm -rf", "auto-format on save", "notify me when Claude finishes", "audit settings changes", or reference any of the lifecycle events (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolBatch`, `Stop`, `SubagentStop`, `Notification`, `PreCompact`, `PostCompact`, `SessionEnd`, `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `Setup`, `InstructionsLoaded`, `Elicitation`, `ElicitationResult`, `PermissionDenied`, `StopFailure`, `PostToolUseFailure`, `SubagentStart`, `UserPromptExpansion`).
    Also use it when reviewing existing hook configurations, choosing between command/HTTP/MCP/prompt/agent hook types, designing matcher and `if` patterns, wiring up `additionalContext` injection, restricting tools by exit code 2, or distributing hooks via plugins, skills, or agent frontmatter.
    The skill enforces a draft → test → review → iterate loop and keeps configurations aligned with the current hooks reference.
allowed-tools: Read Write Edit Glob Grep Bash(jq *) Bash(chmod *) Bash(mkdir *) Bash(ls *) Bash(cat *) Bash(git *) Bash(claude *) Bash(uv *) Bash(echo *)
---

# Hook Author

A disciplined workflow for authoring Claude Code hooks.
The deliverable is a working hook configuration (plus any handler scripts) that fires reliably at the right lifecycle point, makes the correct allow/deny/feedback decision, and fails safely when something goes wrong.

This skill enforces a **draft → test → review → iterate** loop.
The first draft is rarely the final draft, and skipping testing is the single biggest reason hooks misfire silently in production — a hook that exits 0 when it should exit 2 looks identical to a hook that's working correctly.

---

## Operating principle

A hook is a deterministic interception of Claude Code's lifecycle.
Three things determine whether it succeeds:

1. **Event selection.**
   Picking the wrong event is the most common authoring mistake.
   `PostToolUse` cannot block (the tool already ran).
   `PermissionRequest` does not fire in non-interactive `-p` mode.
   `Stop` runs whenever Claude finishes responding, not only at "task done".
   Match the event to the moment in the lifecycle where the decision can actually be made.
2. **Matcher and `if` filtering.**
   The matcher is the cheap filter, evaluated before any process spawns.
   The `if` field is a finer filter on tool name and arguments together.
   Both should be as narrow as possible — broad matchers cost spawn overhead and create surprising failures when an unrelated tool call activates the wrong handler.
3. **Decision contract.**
   Every event has a different decision contract: exit code, top-level `decision`, `hookSpecificOutput.permissionDecision`, `hookSpecificOutput.decision.behavior`.
   Mixing these up is silent — Claude Code accepts the JSON, ignores the unrecognised fields, and your hook does nothing.

Optimise for these three properties from the first draft.
Everything below operationalises that.

---

## Source formatting — one sentence per line

Whenever you write markdown in this workflow — a `SKILL.md` or agent-frontmatter body that wraps the hook config, handler-script docstrings, README snippets, or any commit/PR text — put each sentence on its own line in the source.
This convention is sometimes called *semantic line breaks*.

The rendered output is unchanged: a markdown renderer collapses consecutive non-blank lines within a paragraph into one rendered line, so the visual result is identical to a soft-wrapped paragraph.
The benefit is in `git diff`: editing one sentence produces a one-line diff instead of a re-flowed paragraph that touches every wrapped line.

Within a list item, the same rule applies — the bullet marker stays on the first line, and continuation sentences sit on subsequent unindented lines.
A blank line ends the paragraph or list item.

````markdown
- This is one bullet.
The bullet continues here, still in the same item.

- This is the next bullet.
````

Type each sentence on a new line as you author.
Do not rely on a post-processing script to enforce this — the rule is small and unambiguous when you write sentence-by-sentence.

---

## Companion skills — delegating to siblings

This skill is one of three that together cover Claude Code's authoring primitives:

- **`create-hook`** (this skill) — deterministic interception of a lifecycle event (format on save, block a command, inject context).
- **`create-skill`** — reusable prompt/workflow context that loads on demand into the parent conversation.
- **`create-agent`** — delegated subagent with its own context window, tool scope, and return-value contract.

If the user's request expands beyond a standalone hook, invoke the sibling skill via the `Skill` tool rather than re-deriving its workflow inline.
Hand over the context you have already gathered (the chosen lifecycle event, matcher and `if` filters, decision contract, handler type) so the sibling does not re-ask its own Phase 0 questions.

Common compositions when authoring a hook:

- The hook is being **packaged inside a skill** (skill frontmatter `hooks:`).
  Delegate the wrapping `SKILL.md` design to `create-skill` once the hook config is finalised.
- The hook lives in **agent frontmatter** (scoped to a specific subagent).
  Delegate the wrapping agent design to `create-agent` and embed the hook config in its `hooks:` field.
- The hook is part of a **plugin** that bundles skills and/or agents — delegate those parts to the matching sibling skill.

---

## Phase 0 — Capture intent

Before writing any JSON, establish what the hook is for.
Hooks are a deterministic alternative to asking the LLM to remember a rule, so the question is always: _what should always happen, regardless of what Claude decides?_

Ask the user — in a single batched message — to confirm:

1. **What action should fire automatically?**
   One sentence, action-oriented (format files, block destructive commands, log every Bash call, inject context after compaction, send a notification).
2. **At which lifecycle point?**
   See [§ The lifecycle and event catalogue](#the-lifecycle-and-event-catalogue) below to pick.
   The user often names the wrong event (e.g. wants `PostToolUse` to block — that's `PreToolUse`); always confirm the event matches the intent before drafting.
3. **What should happen on failure?**
   _Block the action_ (exit 2 or `permissionDecision: "deny"`), _warn but proceed_ (non-zero exit ≠ 2), _give Claude feedback to retry_ (`PostToolUse` with `decision: "block"` and `reason`), or _just log_ (any non-blocking exit).
4. **Where should the hook live?**
   Personal `~/.claude/settings.json`, project `.claude/settings.json` (committed), project `.claude/settings.local.json` (gitignored), plugin `hooks/hooks.json`, or skill/agent frontmatter.
   See [§ Hook locations and scope](#hook-locations-and-scope).
5. **Is this a deterministic rule or a judgement call?**
   Deterministic → command/HTTP/MCP hook.
   Judgement → prompt or agent hook.
   See [§ Hook handler types](#hook-handler-types).

Wait for confirmation before drafting.

---

## Phase 1 — The lifecycle and event catalogue

Hooks fire at specific points in the Claude Code session.
Events fall into three cadences: **once per session**, **once per turn**, and **on every tool call inside the agentic loop**.
The `if` field is only honoured on tool events; on any other event, a hook with `if` set never runs.

### Once per session

| Event          | When                                                                                  | Can block? |
| -------------- | ------------------------------------------------------------------------------------- | ---------- |
| `SessionStart` | New session, `--resume`, `--continue`, `/resume`, `/clear`, or after compaction       | No         |
| `Setup`        | `claude --init-only`, or `--init`/`--maintenance` in `-p` mode. CI/scripted prep only | No         |
| `SessionEnd`   | Session terminates                                                                    | No         |

### Once per turn

| Event                 | When                                                           | Can block?                                |
| --------------------- | -------------------------------------------------------------- | ----------------------------------------- |
| `UserPromptSubmit`    | User submits a prompt                                          | Yes — exit 2 erases the prompt            |
| `UserPromptExpansion` | A typed slash command expands into a prompt                    | Yes — `decision: "block"`                 |
| `Stop`                | Main agent finishes responding                                 | Yes — `decision: "block"` to keep working |
| `StopFailure`         | Turn ends due to API error (rate limit, auth, billing, server) | No                                        |
| `PreCompact`          | Before context compaction                                      | Yes                                       |
| `PostCompact`         | After context compaction                                       | No                                        |
| `TeammateIdle`        | Agent-team teammate about to go idle                           | Yes — exit 2 keeps it working             |

### Inside the agentic loop (per tool call)

| Event                | When                                                                  | Can block?                         |
| -------------------- | --------------------------------------------------------------------- | ---------------------------------- |
| `PreToolUse`         | Before tool execution                                                 | Yes — `permissionDecision: "deny"` |
| `PermissionRequest`  | A permission dialog is about to be shown                              | Yes — `decision.behavior: "deny"`  |
| `PermissionDenied`   | Auto-mode classifier denied a tool call                               | No (post-hoc); can `retry: true`   |
| `PostToolUse`        | After successful tool call                                            | No (already ran) — feedback only   |
| `PostToolUseFailure` | After failed tool call                                                | No — feedback only                 |
| `PostToolBatch`      | After every tool in a parallel batch resolves, before next model call | Yes — stops the loop               |
| `SubagentStart`      | A subagent is spawned via the `Agent` tool                            | No                                 |
| `SubagentStop`       | A subagent finishes                                                   | Yes — same contract as `Stop`      |
| `TaskCreated`        | A task is being created via `TaskCreate`                              | Yes — exit 2 rolls back            |
| `TaskCompleted`      | A task is being marked complete                                       | Yes — exit 2 prevents completion   |

### Async / observability events

| Event                | When                                                               | Can block?                                  |
| -------------------- | ------------------------------------------------------------------ | ------------------------------------------- |
| `Notification`       | Claude Code sends a notification (permission prompt, idle, auth)   | No                                          |
| `InstructionsLoaded` | A `CLAUDE.md` or `.claude/rules/*.md` is loaded                    | No                                          |
| `ConfigChange`       | A configuration file changes mid-session                           | Yes — except `policy_settings`              |
| `CwdChanged`         | Working directory changes (e.g. Claude runs `cd`)                  | No                                          |
| `FileChanged`        | A watched file changes on disk; matcher lists filenames            | No                                          |
| `WorktreeCreate`     | Worktree being created via `--worktree` or `isolation: "worktree"` | Yes — any non-zero exit fails creation      |
| `WorktreeRemove`     | Worktree being removed                                             | No                                          |
| `Elicitation`        | An MCP server requests user input during a tool call               | Yes — denies the elicitation                |
| `ElicitationResult`  | After user responds to an MCP elicitation                          | Yes — blocks the response (becomes decline) |

### Cadence implications

Per-session events run once and should be **fast** — they're on the startup path.
Per-turn events run on every prompt — they should also be fast.
Per-tool-call events run inside the agentic loop — they accumulate across long sessions, so a slow `PreToolUse` hook compounds.

For anything expensive, use [`async: true`](#async-and-asyncrewake) so the work happens in the background without blocking the loop.

---

## Phase 2 — Hook locations and scope

Where you define a hook determines its scope and whether it ships with the project.

| Location                      | Scope                         | Shareable               | Use when                                         |
| ----------------------------- | ----------------------------- | ----------------------- | ------------------------------------------------ |
| `~/.claude/settings.json`     | All your projects             | No, machine-local       | Personal preferences (notifications, audit logs) |
| `.claude/settings.json`       | Single project                | Yes, committed          | Project-wide rules everyone clones               |
| `.claude/settings.local.json` | Single project                | No, gitignored          | Per-developer overrides                          |
| Managed policy settings       | Organisation-wide             | Yes, admin-controlled   | Enterprise policy enforcement                    |
| Plugin `hooks/hooks.json`     | When the plugin is enabled    | Yes, with the plugin    | Distributable hooks tied to a feature            |
| Skill or agent frontmatter    | While the component is active | Yes, with the component | Hooks that only make sense with that skill/agent |

Enterprise admins can set `allowManagedHooksOnly` to block user, project, and plugin hooks.
Hooks from plugins force-enabled in `enabledPlugins` are exempt — that's how admins distribute vetted hooks via an organisation marketplace.

**Edits are usually picked up automatically** — Claude Code watches the settings files and reloads hooks.
If a change doesn't take effect, restart the session.

### Hooks and SkillShed publishing

If the hook is bundled inside skill or agent frontmatter, it travels with the skill or agent when SkillShed installs them — the frontmatter is preserved verbatim on the installed file.
Hooks in `settings.json` / `settings.local.json` are **not** part of any SkillShed entity and must be distributed separately (committed to the consumer's repo, or shipped via a plugin).
For a deterministic rule that should apply only while a particular skill or agent is active, prefer frontmatter hooks over settings hooks for exactly this reason — the skill is self-contained and the hook is portable across harnesses that recognise the frontmatter field (Claude Code does; Codex and Copilot tolerate the `hooks:` key as unknown YAML and ignore it, so no breakage on those platforms either).

---

## Phase 3 — Configuration anatomy

Hooks have three levels of nesting:

1. **Hook event** — which lifecycle point.
2. **Matcher group** — which occurrences of the event activate this group.
3. **Hook handler** — the command, HTTP endpoint, MCP tool, prompt, or agent that runs.

```json
{
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "if": "Bash(rm *)",
                        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm.sh"
                    }
                ]
            }
        ]
    }
}
```

**Terminology note** that matters when reading the docs:

- **Hook event** = lifecycle point (`PreToolUse`).
- **Matcher group** = the filter (`"matcher": "Bash"`).
- **Hook handler** = the inner object that actually runs (the `command`/`http`/`mcp_tool`/`prompt`/`agent`).
- **"Hook"** alone = the general feature.

### Matcher patterns

The matcher filters when the group activates.
How it's evaluated depends on the characters it contains:

| Matcher value                       | Evaluated as                         | Example                        |
| ----------------------------------- | ------------------------------------ | ------------------------------ |
| `"*"`, `""`, or omitted             | Match all                            | Fires on every occurrence      |
| Only letters, digits, `_`, and `\|` | Exact string, or `\|`-separated list | `Bash`, `Edit\|Write`          |
| Contains any other character        | JavaScript regex                     | `^Notebook`, `mcp__memory__.*` |

**Critical gotcha:** `mcp__memory` matches _no tool_, because it contains only letters/underscores and is therefore evaluated as an exact string — and no MCP tool is named exactly `mcp__memory`.
You **must** append `.*` to match all tools from a server: `mcp__memory__.*`.

What each event's matcher actually filters varies — see the [event catalogue](#the-lifecycle-and-event-catalogue) above.
Tool events filter on `tool_name`; `SessionStart` filters on `source` (`startup`/`resume`/`clear`/`compact`); `Notification` on type; `PreCompact`/`PostCompact` on `manual`/`auto`; etc.

These events **don't support matchers** at all (any matcher you set is silently ignored): `UserPromptSubmit`, `PostToolBatch`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `CwdChanged`.

### The `if` field — sub-tool filtering

`if` runs after the matcher and accepts permission-rule syntax: `Bash(git *)`, `Edit(*.ts)`, `Write(src/**)`.
It only spawns the handler when the tool call matches the pattern (or when a Bash command is too complex to parse, in which case the handler runs as a safety fallback).

Crucial constraints:

- **Only on tool events.**
  `if` is evaluated on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, and `PermissionDenied`.
  On any other event, a hook with `if` set **never runs at all** — fail-closed, not fail-open.
- **One rule per `if`.**
  No `&&`, no `||`, no list syntax.
  For multiple conditions, declare separate handlers.
- **Bash subcommand semantics.**
  `if: "Bash(git push *)"` matches both `FOO=bar git push` (after stripping leading `VAR=value`) and `npm test && git push`.
  The hook runs if **any** subcommand matches, and **always** runs when the command is too complex to parse.

Use the `if` field aggressively to avoid spawning processes you don't need.
A `PreToolUse` hook on Bash that activates on every Bash call but only does work for `git push` should put `git push *` in `if`, not in the script's logic.

### Common handler fields

These apply to every handler type:

| Field           | Description                                                                                                               |
| --------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `type`          | `"command"`, `"http"`, `"mcp_tool"`, `"prompt"`, or `"agent"`                                                             |
| `if`            | Permission-rule syntax for sub-tool filtering. Tool events only                                                           |
| `timeout`       | Seconds before cancelling. Defaults: 600 (command), 30 (prompt), 60 (agent)                                               |
| `statusMessage` | Custom spinner text shown while the hook runs                                                                             |
| `once`          | Run once per session then remove. **Only honoured in skill frontmatter**; ignored in settings files and agent frontmatter |

---

## Phase 4 — Hook handler types

Five types, each with different fields and tradeoffs.

### Command hooks (`type: "command"`)

Run a shell command.
Input arrives on stdin as JSON; results return through exit codes and stdout.

| Field         | Description                                                                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `command`     | Shell command to execute. Required                                                                                                                 |
| `async`       | Run in background, don't block the loop. See [§ async and asyncRewake](#async-and-asyncrewake)                                                     |
| `asyncRewake` | Background + wake Claude on exit code 2. Stderr (or stdout if stderr empty) is shown to Claude as a system reminder. Implies `async`               |
| `shell`       | `"bash"` (default) or `"powershell"`. PowerShell does **not** require `CLAUDE_CODE_USE_POWERSHELL_TOOL` for hooks — they spawn PowerShell directly |

**Path resolution** — always reference scripts via environment variables, never as plain relative paths:

| Variable                | Use for                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `$CLAUDE_PROJECT_DIR`   | Project-relative scripts. **Always quote**: `"$CLAUDE_PROJECT_DIR"/.claude/hooks/check.sh`                |
| `${CLAUDE_PLUGIN_ROOT}` | Scripts bundled in a plugin. Changes on each plugin update                                                |
| `${CLAUDE_PLUGIN_DATA}` | Plugin persistent data (dependencies, state); survives plugin updates                                     |
| `$CLAUDE_CODE_REMOTE`   | `"true"` in remote web environments; not set in local CLI                                                 |
| `$CLAUDE_EFFORT`        | Current effort level (also in `effort.level` JSON field)                                                  |
| `$CLAUDE_ENV_FILE`      | File path for persisting env vars; only available to `SessionStart`, `Setup`, `CwdChanged`, `FileChanged` |

### HTTP hooks (`type: "http"`)

POST the JSON input to a URL.
The response body uses the same JSON output format as command hooks.

| Field            | Description                                                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `url`            | URL for the POST. Required                                                                                             |
| `headers`        | Map of header name to value. Values support `$VAR_NAME` / `${VAR_NAME}` interpolation                                  |
| `allowedEnvVars` | List of env var names that may be interpolated. **Required** for any interpolation; unlisted refs become empty strings |

**Error semantics differ from command hooks**: non-2xx responses, connection failures, and timeouts are all _non-blocking_ — they don't deny the action.
To block, you must return a 2xx with a JSON body containing `decision: "block"` or `hookSpecificOutput.permissionDecision: "deny"`.

### MCP tool hooks (`type: "mcp_tool"`)

Call a tool on an already-connected MCP server.

| Field    | Description                                                                                                  |
| -------- | ------------------------------------------------------------------------------------------------------------ |
| `server` | MCP server name. Must already be connected — the hook never triggers an OAuth or connection flow             |
| `tool`   | Tool name on that server                                                                                     |
| `input`  | Tool arguments. Strings support `${path}` substitution from the hook input, e.g. `"${tool_input.file_path}"` |

The tool's text output is treated like command-hook stdout: parses as JSON → processed as a decision; otherwise plain text.
On `SessionStart` and `Setup`, the MCP server typically isn't connected yet — expect the "not connected" error on first run.

### Prompt hooks (`type: "prompt"`)

Single-turn LLM evaluation.
The model returns `{"ok": true|false, "reason": "..."}`.

| Field    | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `prompt` | Prompt text. `$ARGUMENTS` is replaced with the hook input JSON |
| `model`  | Model to use. Defaults to a fast model (Haiku)                 |

`"ok": false` behaviour by event:

- `Stop` / `SubagentStop`: `reason` fed back to Claude, it keeps working.
- `PreToolUse`: tool denied, `reason` returned as the tool error.
- `PostToolUse` / `PostToolBatch` / `UserPromptSubmit` / `UserPromptExpansion`: turn ends, `reason` shown as a chat warning.

### Agent hooks (`type: "agent"`) — experimental

Spawn a subagent that can use tools (Read, Grep, Glob, etc.) to verify conditions.
Same `{"ok", "reason"}` response format as prompt hooks but with longer default timeout (60s) and up to 50 tool-use turns.

**Use prompt hooks** when the input JSON alone is enough.
**Use agent hooks** when verification requires inspecting actual files or running commands (e.g. "are tests passing?").

---

## Phase 5 — Hook input

Every hook receives a JSON object on stdin (command), as POST body (HTTP), or in `$ARGUMENTS` (prompt/agent).

### Common input fields

| Field             | Description                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `session_id`      | Current session identifier                                                                                                                    |
| `transcript_path` | Path to the conversation JSONL                                                                                                                |
| `cwd`             | Current working directory                                                                                                                     |
| `permission_mode` | `"default"`, `"plan"`, `"acceptEdits"`, `"auto"`, `"dontAsk"`, `"bypassPermissions"`. Not on every event                                      |
| `effort`          | `{level: "low"\|"medium"\|"high"\|"xhigh"\|"max"}` — the **actual** effort the model used (downgraded if the requested level isn't supported) |
| `hook_event_name` | The event name                                                                                                                                |
| `agent_id`        | Subagent unique ID (only when in a subagent)                                                                                                  |
| `agent_type`      | Agent name (only when in a subagent or with `--agent`)                                                                                        |

### Per-event input

Each event adds its own fields.
Highlights:

- **`PreToolUse`** / **`PostToolUse`** / **`PostToolUseFailure`** / **`PermissionRequest`**: `tool_name`, `tool_input`, `tool_use_id`.
  `PostToolUse` adds `tool_response` and `duration_ms`.
  `PostToolUseFailure` adds `error`, `is_interrupt`, `duration_ms`.
- **`PostToolBatch`**: `tool_calls` array.
  `tool_response` here is the **serialised tool-result string** the model sees (line-prefixed for `Read`), _not_ the structured `Output` object that `PostToolUse` passes.
- **`PermissionRequest`**: also `permission_suggestions` — the "always allow" options the user would normally see.
- **`PermissionDenied`**: `tool_name`, `tool_input`, `tool_use_id`, `reason`.
- **`UserPromptSubmit`**: `prompt`.
- **`UserPromptExpansion`**: `expansion_type` (`slash_command`/`mcp_prompt`), `command_name`, `command_args`, `command_source`, `prompt`.
- **`SessionStart`**: `source` (`startup`/`resume`/`clear`/`compact`), `model`.
- **`Setup`**: `trigger` (`init`/`maintenance`).
- **`SessionEnd`**: matcher on `clear`/`resume`/`logout`/`prompt_input_exit`/`bypass_permissions_disabled`/`other`.
- **`Stop`** / **`SubagentStop`**: `stop_hook_active`, `last_assistant_message`. `SubagentStop` adds `agent_id`, `agent_type`, `agent_transcript_path`.
- **`StopFailure`**: `error` (`rate_limit`/`authentication_failed`/`oauth_org_not_allowed`/`billing_error`/`invalid_request`/`server_error`/`max_output_tokens`/`unknown`), `error_details`, `last_assistant_message` (the API error string, not Claude's text).
- **`TaskCreated`** / **`TaskCompleted`**: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`.
- **`TeammateIdle`**: `teammate_name`, `team_name`.
- **`InstructionsLoaded`**: `file_path`, `memory_type`, `load_reason`, `globs`, `trigger_file_path`, `parent_file_path`.
- **`ConfigChange`**: `source` (`user_settings`/`project_settings`/`local_settings`/`policy_settings`/`skills`), `file_path`.

For tool-input schemas (Bash command, Edit old_string/new_string, Read file_path/offset/limit, etc.), see the official reference: <https://code.claude.com/docs/en/hooks#pretooluse-input>.

---

## Phase 6 — Decision contracts

Every event has its own decision contract.
Mixing them up is silent: Claude Code accepts the JSON, ignores fields it doesn't recognise for that event, and your hook does nothing.

### Exit codes (universal)

| Exit code          | Effect                                                                                                                      |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `0`                | Action proceeds. JSON on stdout (if any) is parsed for structured control                                                   |
| `2`                | **Blocking error** — stderr is fed back, JSON on stdout is _ignored_. Effect depends on event (see below)                   |
| Any other non-zero | Non-blocking error. Transcript shows `<hook> hook error` + first stderr line; full stderr in debug log; execution continues |

**Critical:** exit code 1 is _non-blocking_, even though Unix convention says 1 = failure.
To enforce a policy, **use `exit 2`** — `exit 1` will let the action through.
The exception is `WorktreeCreate`, where any non-zero exit aborts creation.

#### Exit 2 effect per event

| Event                                                                                                                                        | Effect of exit 2                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `PreToolUse`                                                                                                                                 | Blocks the tool call                                            |
| `PermissionRequest`                                                                                                                          | Denies the permission                                           |
| `UserPromptSubmit`                                                                                                                           | Blocks the prompt and **erases it from context**                |
| `UserPromptExpansion`                                                                                                                        | Blocks the expansion                                            |
| `Stop`                                                                                                                                       | Prevents Claude from stopping                                   |
| `SubagentStop`                                                                                                                               | Prevents subagent from stopping                                 |
| `TeammateIdle`                                                                                                                               | Teammate keeps working                                          |
| `TaskCreated`                                                                                                                                | Rolls back task creation                                        |
| `TaskCompleted`                                                                                                                              | Prevents task completion                                        |
| `ConfigChange`                                                                                                                               | Blocks the config change (except `policy_settings`)             |
| `PreCompact`                                                                                                                                 | Blocks compaction                                               |
| `PostToolBatch`                                                                                                                              | Stops the agentic loop before next model call                   |
| `Elicitation`                                                                                                                                | Denies the elicitation                                          |
| `ElicitationResult`                                                                                                                          | Blocks the response (becomes decline)                           |
| `WorktreeCreate`                                                                                                                             | **Any** non-zero exit aborts creation                           |
| `PostToolUse`                                                                                                                                | Cannot block (already ran) — stderr shown to Claude             |
| `PostToolUseFailure`                                                                                                                         | Cannot block — stderr shown to Claude                           |
| `PermissionDenied`                                                                                                                           | Exit code & stderr **ignored** — use JSON `retry: true` instead |
| `SessionStart` / `Setup` / `SessionEnd` / `Notification` / `SubagentStart` / `CwdChanged` / `FileChanged` / `PostCompact` / `WorktreeRemove` | Stderr shown to user only; cannot block                         |
| `StopFailure` / `InstructionsLoaded`                                                                                                         | Output and exit code ignored entirely                           |

### JSON output (universal fields)

| Field            | Description                                                                                  |
| ---------------- | -------------------------------------------------------------------------------------------- |
| `continue`       | If `false`, Claude stops processing entirely. Takes precedence over event-specific decisions |
| `stopReason`     | Message shown to user when `continue: false`. Not shown to Claude                            |
| `suppressOutput` | If `true`, omits stdout from the debug log                                                   |
| `systemMessage`  | Warning shown to user                                                                        |

Stdout-injected context (`additionalContext`, `systemMessage`, plain stdout) is capped at **10,000 characters**.
Beyond that it's saved to a file and replaced with a preview + path.

### Per-event decision fields

| Events                                                                                                                                                | Pattern                     | Key fields                                                                                                           |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `UserPromptSubmit`, `UserPromptExpansion`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStop`, `ConfigChange`, `PreCompact` | Top-level `decision`        | `decision: "block"`, `reason`                                                                                        |
| `PreToolUse`                                                                                                                                          | `hookSpecificOutput`        | `permissionDecision` (`allow`/`deny`/`ask`/`defer`), `permissionDecisionReason`, `updatedInput`, `additionalContext` |
| `PermissionRequest`                                                                                                                                   | `hookSpecificOutput`        | `decision.behavior` (`allow`/`deny`), `updatedInput`, `updatedPermissions`, `message`, `interrupt`                   |
| `PermissionDenied`                                                                                                                                    | `hookSpecificOutput`        | `retry: true` tells the model it may retry the denied tool call                                                      |
| `WorktreeCreate`                                                                                                                                      | path return                 | Command: print path on stdout. HTTP: `hookSpecificOutput.worktreePath`                                               |
| `Elicitation` / `ElicitationResult`                                                                                                                   | `hookSpecificOutput`        | `action` (`accept`/`decline`/`cancel`), `content`                                                                    |
| `TeammateIdle`, `TaskCreated`, `TaskCompleted`                                                                                                        | Exit 2 or `continue: false` | Exit 2 = continue/feedback; `{"continue": false, "stopReason": "..."}` = stop entirely                               |
| `Notification`, `SessionEnd`, `PostCompact`, `InstructionsLoaded`, `StopFailure`, `CwdChanged`, `FileChanged`, `WorktreeRemove`                       | None                        | Side-effects only                                                                                                    |

### `PreToolUse` decision specifics

The deprecated top-level `decision`/`reason` fields still exist but **don't use them** — use `hookSpecificOutput.permissionDecision`/`permissionDecisionReason` instead.
The deprecated values `"approve"` and `"block"` map to `"allow"` and `"deny"`.

```json
{
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "Pre-approved git operations",
        "updatedInput": { "command": "git status --short" },
        "additionalContext": "Using shorthand status output for context efficiency."
    }
}
```

`permissionDecision` precedence when multiple hooks fire: **deny > defer > ask > allow**.
`"allow"` does **not** override deny rules from settings or managed policy.
Hooks can tighten restrictions but not loosen them past what permission rules allow.

`"defer"` is for non-interactive `-p` mode only (Agent SDK wrappers).
It exits with `stop_reason: "tool_deferred"` and the tool call preserved for resume.

### `PermissionRequest` `updatedPermissions`

The `decision.updatedPermissions` array applies permission updates when allowing.
Each entry has a `type`:

| Type                | Fields                             | Effect                                                                   |
| ------------------- | ---------------------------------- | ------------------------------------------------------------------------ |
| `addRules`          | `rules`, `behavior`, `destination` | Adds rules (`{toolName, ruleContent?}`)                                  |
| `replaceRules`      | `rules`, `behavior`, `destination` | Replaces rules of `behavior` at `destination`                            |
| `removeRules`       | `rules`, `behavior`, `destination` | Removes matching rules                                                   |
| `setMode`           | `mode`, `destination`              | Sets mode (`default`/`acceptEdits`/`dontAsk`/`bypassPermissions`/`plan`) |
| `addDirectories`    | `directories`, `destination`       | Adds working directories                                                 |
| `removeDirectories` | `directories`, `destination`       | Removes working directories                                              |

`destination`: `session` (in-memory only), `localSettings`, `projectSettings`, or `userSettings`.
`bypassPermissions` only takes effect if the session was launched with bypass already available; never persisted as `defaultMode`.

### `additionalContext` — injecting context for Claude

Most events can return `hookSpecificOutput.additionalContext` to pass a string into Claude's context.
It's wrapped in a system reminder and inserted at the point where the hook fired.

Where the reminder appears depends on event:

- `SessionStart` / `Setup` / `SubagentStart`: at conversation start, before the first prompt.
- `UserPromptSubmit` / `UserPromptExpansion`: alongside the submitted prompt.
- `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PostToolBatch`: next to the tool result.

**Phrasing matters.**
Write factual statements ("The deployment target is production", "This repo uses `bun test`") rather than imperative system commands.
Imperative framing can trigger Claude's prompt-injection defences and cause the text to be surfaced to the user instead of treated as context.

**For instructions that never change, prefer `CLAUDE.md`** — it loads without running a script and is the standard place for static project conventions.
Use `additionalContext` for _dynamic_ state: current branch, deployment target, open issues, recent CI results.

**On resume**: `additionalContext` from past turns is **replayed from the saved transcript** rather than re-running the hook.
Timestamps, commit SHAs, and any other "live at the time" values become stale on resume.
`SessionStart` hooks _do_ re-run on resume with `source: "resume"`, so they can refresh.

---

## Phase 7 — Async hooks and CLAUDE_ENV_FILE

### `async` and `asyncRewake`

Set `async: true` on a command hook to run it in the background without blocking.
The hook output won't influence the current decision, but side effects still happen.

`asyncRewake: true` (implies `async`) wakes Claude on exit code 2 with a system reminder containing the hook's stderr (or stdout if stderr is empty).
This is how you signal a long-running background failure to Claude after the loop has moved on.

Use this for:

- Slow linters/formatters that shouldn't block the agentic loop.
- Background uploads, syncs, or notifications.
- Long-running validation that should yell at Claude later if it fails.

### `CLAUDE_ENV_FILE` — persisting env vars across Bash calls

Available only to `SessionStart`, `Setup`, `CwdChanged`, and `FileChanged` hooks.

Write `export VAR=value` lines to the file (use `>>` to preserve other hooks' contributions).
Claude Code sources this as a preamble before every Bash command in the session.

Capture all environment changes from a setup command:

```bash
#!/bin/bash
ENV_BEFORE=$(export -p | sort)

source ~/.nvm/nvm.sh
nvm use 20

if [ -n "$CLAUDE_ENV_FILE" ]; then
  ENV_AFTER=$(export -p | sort)
  comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >> "$CLAUDE_ENV_FILE"
fi
```

Pair `SessionStart` (load on launch) with `CwdChanged` (reload on `cd`) to make `direnv` / `devbox` / `nix` work seamlessly inside Claude's Bash tool.

---

## Phase 8 — Combining multiple hooks

When several handlers match the same event, **all** run in parallel.
One handler returning `deny` does **not** stop sibling handlers from executing.
Don't rely on a deny in one handler to suppress side effects in another — they've already run.

After all matching handlers finish, Claude Code merges their outputs:

- **`PreToolUse` permission decisions**: most restrictive wins (`deny > defer > ask > allow`).
- **`additionalContext`**: text from every handler is concatenated and passed to Claude.
- **`updatedInput` on `PreToolUse`**: last-write-wins, and order is non-deterministic — **avoid having more than one hook modify the same tool's input**.

**Deduplication**: identical handlers are deduplicated automatically — command hooks by command string, HTTP hooks by URL.

---

## Phase 9 — Authoring command-hook scripts

If your hook scripts are written in Python, **always run them with `uv run`** — never the system Python interpreter, never `pip install` globally.

Use [PEP 723 inline metadata](https://peps.python.org/pep-0723/) so dependencies travel with the file:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["jq"]
# ///
"""Block destructive Bash commands."""
import json
import sys

data = json.load(sys.stdin)
command = data.get("tool_input", {}).get("command", "")

if "rm -rf" in command:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "Destructive command blocked by hook"
        }
    }))
    sys.exit(0)

sys.exit(0)
```

Reference it from the hook config:

```json
{
    "type": "command",
    "command": "uv run \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm.py"
}
```

For Bash scripts, this is the canonical skeleton:

```bash
#!/bin/bash
# .claude/hooks/<name>.sh
set -euo pipefail

INPUT=$(cat)
FIELD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# ... logic ...

# Block:
echo "Reason for the block" >&2
exit 2

# Allow:
exit 0

# Allow + structured response:
jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow"}}'
exit 0
```

**Make scripts executable**: `chmod +x .claude/hooks/<name>.sh`.
A "command not found" or non-executable file is a non-blocking error — the action proceeds, which is _not_ what you want for policy enforcement.

**Keep stdout clean**: only print JSON to stdout when you intend it as structured output.
For logging or debug prints, use stderr (`>&2`).
A shell profile that prints to stdout on startup (e.g. `echo "Shell ready"` in `.zshrc`) will corrupt your JSON parsing — wrap shell-profile echos in `if [[ $- == *i* ]]; then ... fi` so they only run in interactive shells.

---

## Phase 10 — Hooks in skills and agents

Skills and subagents can declare hooks in their YAML frontmatter, scoped to the component's lifetime:

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
    PreToolUse:
        - matcher: "Bash"
          hooks:
              - type: command
                command: "./scripts/security-check.sh"
---
```

For subagents, `Stop` hooks are **automatically converted to `SubagentStop`** since that's the event that fires when a subagent completes.
The `once: true` field is **only honoured in skill frontmatter** — ignored in settings files and agent frontmatter.

All hook events are supported in skill/agent frontmatter; cleanup happens when the component finishes.

---

## Phase 11 — The `/hooks` menu and disabling

`/hooks` opens a read-only browser of every configured hook.
Each hook is labeled with its source: `User`, `Project`, `Local`, `Plugin`, `Session`, or `Built-in`.
Selecting a hook shows event, matcher, type, source file, and the full command/prompt/URL.

To **add/edit/remove**, edit the settings JSON directly or ask Claude to make the change.

To **disable all hooks** without removing them, set `"disableAllHooks": true` in your settings file.
There's no way to disable an individual hook while keeping it in the configuration.
`disableAllHooks` respects the managed-settings hierarchy — admin-configured hooks can only be disabled by `disableAllHooks` set at the managed level.

---

## Phase 12 — Test the hook

A hook that hasn't been tested is not a finished hook.
The failure modes are silent: a hook that's misconfigured will appear in `/hooks` but won't fire, and a hook that fires but exits 1 instead of 2 will look like it's working but won't actually block anything.

### 12a. Verify configuration

1. Run `/hooks` — confirm the hook appears under the correct event.
2. Drill into it to confirm the matcher, type, and source file are what you intended.
3. If it's missing, validate the JSON (no trailing commas, no comments) and check the file path.

### 12b. Test inputs manually

For command hooks, pipe a sample event JSON through the script:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}' \
  | "$CLAUDE_PROJECT_DIR"/.claude/hooks/block-rm.sh
echo "exit: $?"
```

Verify:

- Exit code is correct for the input.
- Stdout is **either empty or valid JSON** (no profile noise).
- Stderr contains the expected reason on blocking inputs.

For Python hooks: `echo '...' | uv run hook.py; echo "exit: $?"`.

### 12c. Test in a real session

1. Trigger the event from inside Claude Code with an input that _should_ fire the hook.
2. Trigger again with input that _shouldn't_ fire (to verify the matcher/`if` filter).
3. For blocking hooks, confirm Claude sees the blocked-with-reason flow correctly.
4. For `additionalContext` hooks, confirm Claude actually uses the injected text in its next response.

### 12d. Read the debug log

The transcript view (`Ctrl+O`) shows a one-line summary per hook fire — silent on success, stderr on blocking errors, `<hook> hook error` notice on non-blocking errors.
For full execution detail (which hooks matched, exit codes, stdout/stderr), use the debug log:

```bash
claude --debug-file /tmp/claude.log
# in another terminal:
tail -f /tmp/claude.log
```

If you started without `--debug-file`, run `/debug` mid-session to enable logging and find the path.

---

## Phase 13 — Iterate

After each test pass:

1. **Note the failure mode** — is it triggering, decision contract, exit code, JSON shape, or matcher scope?
2. **Make the smallest change** that addresses the failure.
3. **Re-run manual + real-session tests.**
4. **Stop when correct, not when perfect.**
   File-watcher reloads mean edits take effect within the session; over-tuning a hook on a small set of inputs leads to brittleness.

---

## Common failure modes and fixes

### Hook never fires

- The hook isn't in `/hooks` → JSON is malformed, or the file watcher didn't pick up the change. Restart the session.
- Hook is in `/hooks` but never runs → matcher mismatch.
    - Matcher is case-sensitive: `bash` ≠ `Bash`.
    - For MCP tools, `mcp__memory` matches _nothing_ — use `mcp__memory__.*`.
    - The event you picked is the wrong one (e.g. `PostToolUse` for blocking — should be `PreToolUse`).
- Using `PermissionRequest` in non-interactive `-p` mode → it doesn't fire there. Switch to `PreToolUse`.
- Using `if` on a non-tool event → it never runs. Move the logic to the matcher or the script body.

### Hook fires but action proceeds when it should be blocked

- Exit code 1 instead of 2. **Use `exit 2`.**
- Mixing exit 2 with JSON output: Claude Code ignores JSON when you exit 2.
- `permissionDecision: "allow"` returned from a hook doesn't override deny rules from settings.
- For HTTP hooks, returning a non-2xx status is non-blocking. Block via 2xx + `decision: "block"` JSON.

### `<hook> hook error` in transcript

- Script exit code is non-zero and not 2. Test manually:
    ```bash
    echo '{...}' | ./hook.sh
    echo $?
    ```
- "command not found" → use `$CLAUDE_PROJECT_DIR` and quote it.
- "jq: command not found" → install `jq` (`brew install jq`, `apt install jq`) or rewrite in Python via `uv run`.
- Script not running at all → `chmod +x ./hook.sh`.

### `JSON validation failed`

Almost always shell profile pollution.
A `.zshrc` or `.bashrc` printing to stdout on shell startup gets prepended to the hook's JSON.
Wrap shell-profile output in interactive-shell guards:

```bash
if [[ $- == *i* ]]; then
  echo "Shell ready"
fi
```

### Stop hook runs forever

The script doesn't check `stop_hook_active` and keeps re-blocking:

```bash
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi
```

### `PostToolUse` `updatedToolOutput` ignored

The replacement value must match the tool's output schema exactly.
For `Bash`, that's `{stdout, stderr, interrupted, isImage}` — anything else is silently ignored and the original output is used.
MCP tool output is passed through without schema validation, so for non-MCP tools, validate the shape before returning.

### Hook can't bypass deny rules

That's by design.
Hooks can tighten restrictions but not loosen them past permission rules — even managed-policy deny rules win over `permissionDecision: "allow"`.

### Multiple hooks rewriting the same tool's `updatedInput`

Last-write-wins, order non-deterministic. **Don't do this.**
Either consolidate to one hook, or restructure so each hook modifies a different field.

---

## Quick checklist before declaring done

- [ ] Picked the right event for the lifecycle moment (especially: `PreToolUse` for blocking, not `PostToolUse`).
- [ ] Matcher is as narrow as possible; uses `.*` for MCP server prefixes; uses `|` correctly.
- [ ] `if` field used for sub-tool filtering; only on tool events.
- [ ] Decision contract matches the event (exit 2 vs `decision` vs `hookSpecificOutput.permissionDecision` vs `hookSpecificOutput.decision.behavior`).
- [ ] Exit code 2 used for blocking; not exit 1.
- [ ] Scripts referenced via `"$CLAUDE_PROJECT_DIR"` or `${CLAUDE_PLUGIN_ROOT}`, with quotes.
- [ ] Python scripts use `uv run` with PEP 723 inline metadata; no `pip install`.
- [ ] Bash scripts have `chmod +x`.
- [ ] Stdout is JSON-only when structured output is intended; debug prints go to stderr.
- [ ] Shell profile doesn't print to stdout in non-interactive shells.
- [ ] `additionalContext` phrased as factual statements, not imperatives.
- [ ] `Stop` / `SubagentStop` hooks check `stop_hook_active` to avoid loops.
- [ ] Hook is in the right scope (`~/.claude/`, `.claude/settings.json`, `.claude/settings.local.json`, plugin, skill/agent frontmatter).
- [ ] Tested with `/hooks`, manual stdin pipe, and a real session trigger.
- [ ] If long-running, marked `async: true` (or `asyncRewake: true` to signal failures back).
- [ ] Reviewed `allowed-tools` if hook is in skill frontmatter; reviewed `allowedEnvVars` if HTTP hook.

---

## Templates

### Block destructive commands (`PreToolUse`, command hook)

`.claude/settings.json`:

```json
{
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "if": "Bash(rm *)",
                        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm.sh"
                    }
                ]
            }
        ]
    }
}
```

`.claude/hooks/block-rm.sh`:

```bash
#!/bin/bash
set -euo pipefail
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE 'rm\s+-rf?\s+/'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Refuse to rm -rf at filesystem root"
    }
  }'
  exit 0
fi

exit 0
```

### Auto-format on edit (`PostToolUse`, command hook)

```json
{
    "hooks": {
        "PostToolUse": [
            {
                "matcher": "Edit|Write",
                "hooks": [
                    {
                        "type": "command",
                        "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
                    }
                ]
            }
        ]
    }
}
```

### Inject project state on session start (`SessionStart`, command hook)

```json
{
    "hooks": {
        "SessionStart": [
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": "echo \"Branch: $(git branch --show-current)\\nUncommitted: $(git status --porcelain | wc -l) files\""
                    }
                ]
            }
        ]
    }
}
```

(Plain stdout from `SessionStart` is automatically added to Claude's context.)

### Audit config changes (`ConfigChange`, command hook)

```json
{
    "hooks": {
        "ConfigChange": [
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": "jq -c '{timestamp: now | todate, source: .source, file: .file_path}' >> ~/claude-config-audit.log"
                    }
                ]
            }
        ]
    }
}
```

### Verify tests pass before stopping (`Stop`, prompt hook)

```json
{
    "hooks": {
        "Stop": [
            {
                "hooks": [
                    {
                        "type": "prompt",
                        "prompt": "Check if all tasks are complete. If not, respond with {\"ok\": false, \"reason\": \"what remains to be done\"}."
                    }
                ]
            }
        ]
    }
}
```

### Verify build artefact exists before idle (`TeammateIdle`, command hook)

```bash
#!/bin/bash
if [ ! -f "./dist/output.js" ]; then
  echo "Build artefact missing. Run the build before stopping." >&2
  exit 2
fi
exit 0
```

### Auto-approve `ExitPlanMode` (`PermissionRequest`, command hook)

```json
{
    "hooks": {
        "PermissionRequest": [
            {
                "matcher": "ExitPlanMode",
                "hooks": [
                    {
                        "type": "command",
                        "command": "echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}'"
                    }
                ]
            }
        ]
    }
}
```

### Reload direnv on `cd` (`SessionStart` + `CwdChanged`)

```json
{
    "hooks": {
        "SessionStart": [
            {
                "hooks": [
                    { "type": "command", "command": "direnv export bash > \"$CLAUDE_ENV_FILE\"" }
                ]
            }
        ],
        "CwdChanged": [
            {
                "hooks": [
                    { "type": "command", "command": "direnv export bash > \"$CLAUDE_ENV_FILE\"" }
                ]
            }
        ]
    }
}
```

### Send to a webhook (`PostToolUse`, HTTP hook)

```json
{
    "hooks": {
        "PostToolUse": [
            {
                "hooks": [
                    {
                        "type": "http",
                        "url": "http://localhost:8080/hooks/tool-use",
                        "headers": { "Authorization": "Bearer $MY_TOKEN" },
                        "allowedEnvVars": ["MY_TOKEN"]
                    }
                ]
            }
        ]
    }
}
```

### Plugin hooks (`hooks/hooks.json`)

```json
{
    "description": "Automatic code formatting",
    "hooks": {
        "PostToolUse": [
            {
                "matcher": "Edit|Write",
                "hooks": [
                    {
                        "type": "command",
                        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh",
                        "timeout": 30
                    }
                ]
            }
        ]
    }
}
```

### Skill frontmatter

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
    PreToolUse:
        - matcher: "Bash"
          hooks:
              - type: command
                command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/security-check.sh"
                once: false
---
```

---

## Security considerations

Hooks have access to your shell environment and run with your user's permissions.
Before checking project hooks into a repo, review:

- **What scripts can do**: a hook can `curl` data anywhere, write anywhere your user can write, and consume any env vars on the system.
  Project hooks become trusted code the moment a teammate accepts the workspace-trust dialog.
- **`allowedEnvVars`** in HTTP hooks: only env vars listed here are interpolated into headers.
  Don't list secrets unless the hook URL is trusted.
- **Plugin hooks** distributed via marketplaces: vet the plugin before enabling.
  Hooks fire automatically; you don't get a per-call confirmation.
- **`disableAllHooks`** at managed level: enterprises can use this to enforce that user-level hooks are disabled by default.

---

## Related documentation

- **Hooks reference (full event schemas)**: <https://code.claude.com/docs/en/hooks>
- **Hooks guide (worked examples)**: <https://code.claude.com/docs/en/hooks-guide>
- **Permissions**: <https://code.claude.com/docs/en/permissions>
- **Permission modes**: <https://code.claude.com/docs/en/permission-modes>
- **Skills**: <https://code.claude.com/docs/en/skills>
- **Subagents**: <https://code.claude.com/docs/en/sub-agents>
- **Plugins**: <https://code.claude.com/docs/en/plugins>
- **Settings**: <https://code.claude.com/docs/en/settings>
- **Bash command validator example**: <https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py>

---

Repeating the core loop one last time:

1. Capture intent — what should always happen, at which lifecycle point, with what failure semantics? (Phase 0)
2. Pick the event from the catalogue. (Phase 1)
3. Pick the location and scope. (Phase 2)
4. Write the configuration with the right matcher, `if`, and handler type. (Phases 3–4)
5. Inspect the input schema and write the script's decision contract correctly. (Phases 5–6)
6. Use `async`/`asyncRewake` and `CLAUDE_ENV_FILE` if applicable. (Phase 7)
7. Sanity-check interactions if multiple hooks share an event. (Phase 8)
8. Author scripts with `uv run` (Python), `chmod +x` (Bash), clean stdout. (Phase 9)
9. Place hooks in skills/agents if scope-bound. (Phase 10)
10. Verify with `/hooks`, manual stdin tests, real-session triggers, and the debug log. (Phases 11–12)
11. Iterate one change at a time. (Phase 13)

Add these as TodoList entries when authoring a hook so no step is silently skipped.
