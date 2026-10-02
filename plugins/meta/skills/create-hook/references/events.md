# Hook events

Every Claude Code hook event: when it fires, what its matcher filters on, whether it can block, and the input fields worth knowing.
Checked against the hooks reference at <https://code.claude.com/docs/en/hooks> on 2026-10-02.
Read the reference itself for full input schemas, including per-tool `tool_input` shapes.

## Contents

- Event catalogue
- Matcher rules
- Common input fields
- Input fields per event
- Which handler types each event accepts

## Event catalogue

| Event | Fires | Matcher filters | Can block |
| --- | --- | --- | --- |
| `SessionStart` | A session begins or resumes | `startup`, `resume`, `clear`, `compact`, `fork` | No |
| `Setup` | `--init-only`, or `--init` or `--maintenance` in `-p` mode | `init`, `maintenance` | No |
| `InstructionsLoaded` | A CLAUDE.md or `.claude/rules/*.md` file loads, at start or lazily | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` | No |
| `UserPromptSubmit` | A prompt is submitted, before Claude sees it | None | Yes |
| `UserPromptExpansion` | A typed command or skill expands into a prompt | Command name | Yes |
| `MessageDisplay` | Assistant text is displayed | None | No, display-only |
| `PreToolUse` | Before a tool call runs | Tool name | Yes |
| `PermissionRequest` | A tool call needs a permission decision | Tool name | Yes, JSON only |
| `PermissionDenied` | Auto mode denied a tool call | Tool name | No, can allow a retry |
| `PostToolUse` | A tool call succeeded | Tool name | No, feedback only |
| `PostToolUseFailure` | A tool call failed | Tool name | No, feedback only |
| `PostToolBatch` | A batch of parallel tool calls resolved, before the next model call | None | Yes |
| `Notification` | Claude Code sends a notification | Notification type, such as `permission_prompt` or `idle_prompt` | No |
| `SubagentStart` | A subagent is spawned | Agent type | No |
| `SubagentStop` | A subagent finishes | Agent type | Yes |
| `TaskCreated` | A task is being created | None | Yes |
| `TaskCompleted` | A task is being marked complete | None | Yes |
| `Stop` | Claude finishes responding | None | Yes |
| `StopFailure` | The turn ends on an API error | Error type, such as `rate_limit` or `billing_error` | No |
| `TeammateIdle` | An agent-team teammate is about to go idle | None | Yes |
| `ConfigChange` | A configuration file changes mid-session | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` | Yes, except `policy_settings` |
| `CwdChanged` | The working directory changes | None | No |
| `DirectoryAdded` | A directory is added with `/add-dir` or the SDK | `slash_command`, `register_repo_root` | No |
| `FileChanged` | A watched file changes on disk | Literal filenames to watch | No |
| `WorktreeCreate` | A worktree is being created | None | Yes, any non-zero exit |
| `WorktreeRemove` | A worktree is being removed | None | Yes, any non-zero exit |
| `PreCompact` | Before compaction | `manual`, `auto` | Yes |
| `PostCompact` | After compaction | `manual`, `auto` | No |
| `PreModelSwitch` | Before a requested model switch | Canonical target model name | Yes |
| `PostModelSwitch` | After the session's model changes | Canonical target model name | No |
| `Elicitation` | An MCP server asks for user input | MCP server name | Yes |
| `ElicitationResult` | After the user answers an elicitation | MCP server name | Yes |
| `SessionEnd` | The session terminates | `clear`, `resume`, `logout`, `prompt_input_exit`, `other` | No |

`PreToolUse` and `PostToolUse` do not fire for `EndConversation` calls.

## Matcher rules

| Matcher | Evaluated as |
| --- | --- |
| `"*"`, `""` or omitted | Matches every occurrence |
| Only letters, digits, `_`, `-`, spaces, `,` and `\|` | An exact string, or a list split on `\|` or `,` |
| Anything else | An unanchored JavaScript regular expression |

- `FileChanged` and `StopFailure` use the narrower exact set of letters, digits, `_` and `|`, so a hyphen, space or comma sends their matcher down the regex path.
- A regex matches anywhere in the value: `Edit.*` matches `NotebookEdit`, so write `^Edit$` for a whole-name match.
- MCP tools are named `mcp__<server>__<tool>`.
`mcp__memory` is an exact string that matches no tool, and the server needs `mcp__memory__.*`.
A plugin-bundled server's tools are `mcp__plugin_<plugin>_<server>__<tool>`.
- A plugin agent's type is scoped, such as `my-plugin:reviewer`.
The colon sends the matcher down the regex path, so anchor it as `^my-plugin:reviewer$`.
- A matcher on an event without matcher support is silently ignored.

## Common input fields

Every event receives `session_id`, `transcript_path`, `cwd` and `hook_event_name`.
Most also receive `prompt_id`, `permission_mode` and, inside a tool-use context, `effort.level`.
Inside a subagent or under `--agent`, the input adds `agent_id` (subagents only) and `agent_type`.

- `cwd` follows Claude into worktrees and after `cd`, while `${CLAUDE_PROJECT_DIR}` stays at the project root where the session started.
- `transcript_path` is written asynchronously and can lag the current turn.
On `Stop` and `SubagentStop`, read `last_assistant_message` instead of parsing the transcript.
- The Manual permission mode arrives as `"default"`.
- Only `SessionStart` may receive `model`, and not always.
`PreModelSwitch` and `PostModelSwitch` receive `from_model` and `to_model`.
There is no `$CLAUDE_MODEL` variable.

## Input fields per event

- `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PermissionDenied`: `tool_name`, `tool_input`, `tool_use_id`.
`PostToolUse` adds the tool's response, `PostToolUseFailure` adds the error, `PermissionRequest` adds `permission_suggestions`, and `PermissionDenied` adds the denial reason.
- `PostToolBatch`: the batch's tool calls, where each result is the serialised string the model sees, not the structured object `PostToolUse` receives.
- `UserPromptSubmit`: `prompt`.
- `UserPromptExpansion`: the command name, its arguments and source, and the expanded `prompt`.
- `SessionStart`: `source`, and sometimes `model`.
- `Stop`: `stop_hook_active`, `last_assistant_message`, `background_tasks`, `session_crons`.
- `SubagentStop`: `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`.
- `StopFailure`: the error type and details.
- `TaskCreated`, `TaskCompleted`: the task's ID, subject and description, plus teammate and team names where relevant.
- `ConfigChange`: `source` and `file_path`.

Confirm a field against the reference before a script depends on it, because the event sections there are the only complete list.

## Which handler types each event accepts

All five types (`command`, `http`, `mcp_tool`, `prompt`, `agent`) work on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionDenied`, `Stop`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `UserPromptSubmit` and `UserPromptExpansion`.
`PermissionRequest` accepts every type except `agent`.
`SessionStart` and `Setup` accept `command` and `mcp_tool` only, with no `http`.
The remaining events accept `command`, `http` and `mcp_tool`.
`SessionStart` at launch and every `Setup` run before MCP servers are available, so their `mcp_tool` hooks are skipped and a `command` hook is the only option for launch-time work.
