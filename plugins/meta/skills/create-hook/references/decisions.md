# Decision contracts

How a hook tells Claude Code what to do: exit codes, the universal JSON fields, each event's decision fields, input and output rewriting, and context injection.
Checked against <https://code.claude.com/docs/en/hooks> on 2026-10-02.

## Contents

- How stdout is read
- Exit codes
- Exit 2 per event
- Universal JSON fields
- Decision fields per event
- PreToolUse
- PermissionRequest and permission updates
- PostToolUse
- Stop and SubagentStop
- SessionStart
- Injecting context

## How stdout is read

Claude Code parses stdout as JSON only when, ignoring surrounding whitespace, it starts with `{` and ends with `}`.
Anything else is plain text, a JSON array included.
Plain-text stdout on exit 0 becomes context for Claude only on `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart` and `PostModelSwitch`, and goes to the debug log elsewhere.
Stderr on exit 0 goes to the debug log only, and Claude never sees it.

JSON that parses but fails the event's schema is a non-blocking error on any exit code except 2.
Each of `additionalContext`, `systemMessage`, `initialUserMessage` and plain stdout is capped at 10,000 characters.
Beyond that, Claude Code saves the text to a file and passes a path with a 2,000-character preview, and does not ask Claude to read the file.

## Exit codes

| Code | Effect |
| --- | --- |
| `0` | Success. JSON on stdout is honoured |
| `2` | Blocks on events that can block. JSON is still read, but nothing in it can lift the block. The message is the JSON reason if present, otherwise stderr |
| Other | With valid JSON, the JSON alone decides and the hook is not reported as an error. Otherwise a non-blocking error: the action proceeds and the transcript shows `Failed with non-blocking status code` and the first stderr line |

A script that cannot start, because the path is wrong or the file is not executable, lands in the non-blocking case, so a policy hook with a typo is silently off.
A timed-out `command`, `http` or `mcp_tool` hook renders no decision.
On `PreToolUse` the call then proceeds, while on `PreModelSwitch` a timeout blocks the switch.

## Exit 2 per event

| Event | Exit 2 |
| --- | --- |
| `PreToolUse` | Blocks the tool call, with stderr as the reason Claude sees |
| `PermissionRequest` | Not honoured. Use `decision.behavior` |
| `UserPromptSubmit` | Blocks the prompt so it never reaches Claude |
| `UserPromptExpansion` | Blocks the expansion |
| `Stop`, `SubagentStop` | Keeps Claude or the subagent working, with stderr as the reason |
| `TeammateIdle` | Keeps the teammate working |
| `TaskCreated` | Rolls back the task |
| `TaskCompleted` | Prevents completion |
| `ConfigChange` | Blocks the change, except for `policy_settings` |
| `PreCompact` | Blocks compaction |
| `PostToolBatch` | Stops the agentic loop before the next model call |
| `PreModelSwitch` | Blocks the switch and shows stderr to the user |
| `Elicitation` | Denies the elicitation, ignoring `hookSpecificOutput` |
| `ElicitationResult` | Turns the response into a decline, ignoring `hookSpecificOutput` |
| `WorktreeCreate` | Any non-zero exit fails creation |
| `WorktreeRemove` | Any non-zero exit fails removal if the directory still exists |
| `PostToolUse`, `PostToolUseFailure` | Cannot block, but stderr is shown to Claude, which is the way to surface a warning after the fact |
| `PermissionDenied`, `Notification`, `Setup`, `InstructionsLoaded` | Exit code ignored |
| `StopFailure` | Output and exit code ignored, apart from `terminalSequence` |
| `SessionStart`, `SubagentStart`, `SessionEnd`, `CwdChanged`, `FileChanged`, `PostCompact`, `PostModelSwitch` | Stderr shown to the user only |
| `DirectoryAdded` | Stderr goes to the debug log |
| `MessageDisplay` | The original text is displayed |

## Universal JSON fields

| Field | Meaning |
| --- | --- |
| `continue` | `false` stops Claude entirely and outranks any event decision |
| `stopReason` | Shown to the user with `continue: false`, and stays in the conversation |
| `systemMessage` | A warning shown to the user. Some events discard it |
| `terminalSequence` | An allowlisted escape sequence (OSC 0, 1, 2, 9, 99, 777 or BEL) for a notification, title or bell. Interactive sessions only |
| `suppressOutput` | Accepted but has no effect |

`hookSpecificOutput` must carry `hookEventName` set to the event.

## Decision fields per event

| Events | Pattern | Fields |
| --- | --- | --- |
| `UserPromptSubmit`, `UserPromptExpansion`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStop`, `ConfigChange`, `PreCompact` | Top-level | `decision: "block"` with `reason`. The only value is `"block"`, and omitting it allows |
| `TeammateIdle`, `TaskCompleted` | Exit code or `continue` | Exit 2 blocks with stderr. `{"continue": false, "stopReason": "..."}` stops the teammate |
| `TaskCreated` | Exit code or top-level | Exit 2 or `decision: "block"` cancels the task. `continue: false` is ignored |
| `PreToolUse` | `hookSpecificOutput` | `permissionDecision`, `permissionDecisionReason`, `updatedInput`, `additionalContext` |
| `PreModelSwitch` | `hookSpecificOutput` or top-level | `permissionDecision` (`allow`, `deny`, `ask`), or `decision: "block"` |
| `PermissionRequest` | `hookSpecificOutput.decision` | `behavior`, `updatedInput`, `updatedPermissions`, `message`, `interrupt` |
| `PermissionDenied` | `hookSpecificOutput` | `retry: true` lets the model retry, ignored for denials without a classifier verdict |
| `WorktreeCreate` | Path | A command hook prints the path on stdout, an HTTP hook returns `hookSpecificOutput.worktreePath` |
| `WorktreeRemove` | Exit code | JSON is discarded |
| `Elicitation`, `ElicitationResult` | `hookSpecificOutput` | `action` (`accept`, `decline`, `cancel`) and `content` |
| `MessageDisplay` | `hookSpecificOutput` | `displayContent` changes only what is shown, not the transcript or what Claude sees |
| `SessionStart`, `SubagentStart`, `PostModelSwitch` | Context only | `additionalContext`, plus the `SessionStart` extras below |
| `Setup`, `Notification`, `SessionEnd`, `PostCompact`, `InstructionsLoaded`, `StopFailure`, `CwdChanged`, `DirectoryAdded`, `FileChanged` | None | Side effects only |

## PreToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked a push to main. Push a feature branch and open a pull request."
  }
}
```

- `allow` skips the permission prompt, except for actions no mode auto-approves.
`AskUserQuestion` and `ExitPlanMode` need `updatedInput` alongside `allow`.
- `deny` blocks the call and shows the reason to Claude.
- `ask` prompts the user, shows the reason to the user only, and forces a prompt even in auto mode.
- `defer` pauses a `-p` run with `stop_reason: "tool_deferred"` for an SDK caller to resume.
It is ignored in interactive sessions and when Claude makes several tool calls at once.
- Deny and ask rules in settings are evaluated whatever the hook returns, so a hook's `allow` cannot override a deny rule.
- `updatedInput` replaces the whole input object, so copy unchanged fields across.
Permission rules are evaluated against the rewritten input.
- The top-level `decision` and `reason` are deprecated for this event, and `approve` and `block` map to `allow` and `deny`.

## PermissionRequest and permission updates

`PermissionRequest` reads only `hookSpecificOutput.decision`.
`behavior: "allow"` may carry `updatedInput`, which is re-checked against deny and ask rules, and `updatedPermissions`.
`behavior: "deny"` may carry `message` for Claude and `interrupt: true` to stop Claude.
The event fires only when Claude Code would ask for permission, so it never sees calls that rules or the permission mode already allow, and a policy that must cover every call belongs in `PreToolUse`.
In sessions that cannot show a prompt, such as background subagents in `-p` mode, it still runs, and a call no hook decides is denied.

Each `updatedPermissions` entry has a `type` and a `destination`:

| `type` | Fields |
| --- | --- |
| `addRules`, `replaceRules`, `removeRules` | `rules` (an array of `{toolName, ruleContent?}`), `behavior` (`allow`, `deny`, `ask`) |
| `setMode` | `mode`: `default`, `auto`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` as an alias for `default` |
| `addDirectories`, `removeDirectories` | `directories` |

`destination` is `session` (in memory), `localSettings`, `projectSettings` or `userSettings`.
`setMode` with `bypassPermissions` works only when the session was launched with bypass available, and is never persisted as `defaultMode`.
A hook can echo one of the `permission_suggestions` it received.

## PostToolUse

`decision: "block"` adds `reason` beside the tool result, and Claude still sees the original output.
`updatedToolOutput` replaces what Claude sees and must match the tool's output shape, such as `{stdout, stderr, interrupted, isImage}` for Bash, or it is ignored.
MCP tool output is not validated.
The tool has already run, so neither field undoes its effects.
Use `PreToolUse` to redact or change outbound input, and `PostToolUse` to redact inbound results.

## Stop and SubagentStop

`decision: "block"` with a required `reason` keeps Claude working.
`hookSpecificOutput.additionalContext` also continues the turn but shows as hook feedback rather than a hook error, which suits guidance such as "run the test suite before finishing".
Both are subject to the same loop guards: `stop_hook_active` in the input is `true` when Claude is already continuing because of a stop hook, and Claude Code overrides a block after eight consecutive continuations (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it).

```bash
if [ "$(jq -r '.stop_hook_active' <<<"$INPUT")" = "true" ]; then
  exit 0
fi
```

## SessionStart

Plain stdout already becomes context, so a context-only hook can print text.
The JSON form adds `initialUserMessage` (the first turn in `-p` mode), `sessionTitle`, `watchPaths` (absolute paths for `FileChanged`) and `reloadSkills` (re-scan skills the hook installed).
`SessionStart` re-runs on resume with `source: "resume"`, or `"fork"` with `--fork-session`.

## Injecting context

`hookSpecificOutput.additionalContext` reaches Claude as a system reminder on the next model request:

- `SessionStart`, `SubagentStart`: at the start of the conversation.
- `UserPromptSubmit`, `UserPromptExpansion`: beside the prompt.
- `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`: beside the tool result.
- `Stop`, `SubagentStop`: at the end of the turn, which then continues.
- `PostModelSwitch`: with the next request after the switch.

Write it as facts ("This repo uses `bun test`"), because text framed as system commands can trip Claude's prompt-injection defences and be shown to the user instead.
Use CLAUDE.md for conventions that never change, and `additionalContext` for live state such as the branch or recent CI results.
On `--resume` or `--continue`, context from past mid-session events is replayed from the transcript rather than recomputed, so timestamps and SHAs go stale.
`UserPromptSubmit` cannot rewrite the prompt, only add context beside it.
