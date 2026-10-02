# Hook handlers

The five handler types, their fields, how scripts are launched and referenced, background execution, environment persistence, how parallel handlers combine, and script skeletons.
Checked against <https://code.claude.com/docs/en/hooks> on 2026-10-02.

## Contents

- Common fields
- Command handlers
- HTTP handlers
- MCP tool handlers
- Prompt and agent handlers
- Path placeholders and environment
- Background hooks
- Persisting environment variables
- Combining handlers
- Frontmatter hooks
- Script skeletons
- Disabling hooks

## Common fields

| Field | Meaning |
| --- | --- |
| `type` | `command`, `http`, `mcp_tool`, `prompt` or `agent` |
| `if` | One permission rule, such as `Bash(git *)` or `Edit(*.ts)`, honoured only on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest` and `PermissionDenied`. On other events a handler with `if` never runs |
| `timeout` | Seconds before cancelling. Defaults are 600 for `command`, `http` and `mcp_tool`, 30 for `prompt` and 60 for `agent`. The command default drops to 30 on `UserPromptSubmit`, `PreModelSwitch` and `PostModelSwitch`, and to 10 on `MessageDisplay`. `SessionEnd` hooks share a 1.5-second budget unless a longer `timeout` raises it, up to 60 seconds |
| `statusMessage` | Spinner text while the hook runs |
| `once` | Remove the hook after its first successful run. Honoured only in skill frontmatter |

`if` holds exactly one rule, with no `&&`, `||` or list syntax, so each extra condition needs its own handler.
A file pattern such as `Edit(src/**)` matches only `src` in the working directory, and `Edit(**/src/**)` matches it at any depth.

## Command handlers

| Field | Meaning |
| --- | --- |
| `command` | The shell command, or with `args` the executable to spawn |
| `args` | Argument vector. Its presence switches to exec form: no shell, each element passed verbatim, placeholders substituted as plain strings |
| `async` | Run in the background without blocking |
| `asyncRewake` | Run in the background and wake Claude on exit 2, showing stderr (or stdout if stderr is empty) as a system reminder |
| `shell` | `bash` (default) or `powershell`. Ignored when `args` is set |

Use exec form whenever the command references a path placeholder, and shell form only when the hook needs pipes, `&&` or redirects.
In shell form, wrap each placeholder in double quotes.
Plugin hooks substitute `${user_config.*}` only in exec form, and a shell-form plugin hook that references one fails, so read `$CLAUDE_PLUGIN_OPTION_<KEY>` there instead.

Command hooks run in their own session with no controlling terminal, so they cannot write to `/dev/tty`.
Return `terminalSequence` in JSON for a desktop notification, window title or bell.

## HTTP handlers

| Field | Meaning |
| --- | --- |
| `url` | The POST target. The body is the hook input as JSON |
| `headers` | Header map. Values may interpolate `$VAR` or `${VAR}` |
| `allowedEnvVars` | Variables allowed into headers. Unlisted references become empty strings |

An HTTP hook cannot block through its status code.
Non-2xx responses, connection failures and 2xx responses with a non-JSON body are all non-blocking errors.
To block, return 2xx with a JSON body carrying the event's decision field.
The settings `allowedHttpHookUrls` and `httpHookAllowedEnvVars` restrict HTTP hooks from every source, managed ones included.

## MCP tool handlers

| Field | Meaning |
| --- | --- |
| `server` | A configured server name. For a plugin-bundled server, the scoped `plugin:<plugin>:<server>` |
| `tool` | The tool to call |
| `input` | Arguments. String values support `${path}` substitution from the hook input, such as `"${tool_input.file_path}"` |

The tool's text output is read like command stdout.
A result with `isError: true` is a non-blocking error.
The hook never starts an OAuth flow, so authenticate the server through `/mcp` first.
On blocking events Claude Code waits for a connecting server up to `MCP_TIMEOUT`, and on observational events it does not wait.

## Prompt and agent handlers

Both take `prompt`, with `$ARGUMENTS` replaced by the hook input JSON, and an optional `model` that defaults to the model Claude Code uses for background work.
The model replies `{"ok": true}` or `{"ok": false, "reason": "..."}`.

A prompt handler may also return `impossible: true` with `ok: false`, which lets a `Stop` or `SubagentStop` turn end instead of looping.
What `ok: false` does depends on the event:

- `Stop`, `SubagentStop`: the reason becomes Claude's next instruction and the turn continues.
- `PreToolUse`: the call is denied and the turn ends with a warning, unless `continueOnBlock: true` returns the reason to Claude as the tool error.
- `PostToolUse`: the turn ends with a warning, unless `continueOnBlock: true` feeds the reason back.
- `PostToolBatch`, `UserPromptSubmit`, `UserPromptExpansion`: the turn ends with a warning.
- `PostToolUseFailure`, `TaskCreated`: the reason returns to Claude as a tool error and the turn continues.
- `PermissionRequest`, `PermissionDenied`: no effect.
Use a command hook.

Agent handlers are experimental.
They spawn a subagent with Read, Grep and Glob for up to 50 turns, have no `continueOnBlock` or `impossible`, and on `ok: false` behave like a prompt handler with `continueOnBlock: true`.
Use a prompt handler when the hook input is enough to decide, and an agent handler only when the decision needs files or command output.
Both cost a model call on every trigger.

## Path placeholders and environment

| Name | Meaning |
| --- | --- |
| `${CLAUDE_PROJECT_DIR}` | The project root where the session started. It does not follow Claude into a worktree |
| `${CLAUDE_PLUGIN_ROOT}` | The plugin's install directory, which changes on every plugin update |
| `${CLAUDE_PLUGIN_DATA}` | The plugin's persistent data directory, which survives updates |
| `$CLAUDE_CODE_REMOTE` | `"true"` in remote web sessions |
| `$CLAUDE_EFFORT` | The effort level in effect |
| `$CLAUDE_ENV_FILE` | Only on `SessionStart`, `Setup`, `CwdChanged` and `FileChanged`. See below |

Both forms export the three placeholders as environment variables on the spawned process.
A hook inherits Claude Code's environment, minus the `OTEL_*` exporter variables.
If the current directory has been deleted, command hooks fall back to the session's start directory, then the project root, then home, then the temp directory.

## Background hooks

`async: true` starts the process and continues without waiting.
When it exits, its `additionalContext` and `systemMessage` reach Claude on the next turn, and neither is shown to the user.
`timeout` is not enforced on async hooks.
An idle session receives the output only at the next user interaction, except that an `asyncRewake` hook exiting 2 wakes Claude immediately.
Every firing starts a separate process with no deduplication.

Use async for slow formatters, uploads and test runs that should report back later.

## Persisting environment variables

On `SessionStart`, `Setup`, `CwdChanged` and `FileChanged`, append `export VAR=value` lines to `$CLAUDE_ENV_FILE`, and Claude Code sources them before every later Bash command.
Append with `>>` so other hooks' lines survive.
To capture everything a setup command changes:

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

Pair `SessionStart` with `CwdChanged` so direnv or nix environments reload when Claude changes directory.

## Combining handlers

All matching handlers run in parallel, so a deny from one does not stop another's side effects.
The same handler defined in several settings files runs once, while a plugin's or skill's copy stays separate.

- `PreToolUse` decisions: the most restrictive wins, deny, then defer, then ask, then allow.
- `additionalContext`: Claude receives every handler's value.
- `updatedInput`: replaces the whole input object, so two hooks rewriting the same tool's input conflict.
Keep input rewriting in one hook. [Guessing] The reference does not define which of two rewrites wins.

Hook entries merge across settings levels, so user, project and local settings add hooks without removing managed ones.

## Frontmatter hooks

Skills and subagents declare hooks under `hooks:` in YAML, in the same shape as settings:

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/security-check.sh"
          args: []
```

- A skill's hooks register when the skill is invoked and stay for the rest of the session, unless `once: true`.
- A subagent's hooks run only while it runs, and a `Stop` hook there becomes `SubagentStop`.
Under `--agent` they run alongside settings hooks.
- Plugin agents ignore `hooks:`, so plugin hooks go in `hooks/hooks.json`.
- A project subagent's frontmatter hooks run only after the workspace trust dialog is accepted for that folder, and a `-p` run does not count.

## Script skeletons

Python handlers run through `uv run` with PEP 723 metadata, so dependencies travel with the file:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Deny Bash commands that delete from the filesystem root."""
import json
import re
import sys

data = json.load(sys.stdin)
command = data.get("tool_input", {}).get("command", "")

if re.search(r"\brm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+/(\s|$)", command):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "Blocked rm -rf at the filesystem root. Delete a specific path instead.",
        }
    }))
sys.exit(0)
```

```json
{ "type": "command", "command": "uv", "args": ["run", "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.py"] }
```

A Bash handler reads stdin once and keeps stdout for JSON:

```bash
#!/bin/bash
set -euo pipefail
INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

if [[ "$COMMAND" == *"git push"*"main"* ]]; then
  echo "Blocked a push to main. Push a feature branch and open a pull request." >&2
  exit 2
fi
exit 0
```

`set -e` makes a failing `jq` exit 1, which is non-blocking, so decide deliberately whether a parse failure should block (`|| exit 2`) or allow, and say which in the script.
Wrap any shell-profile output in `if [[ $- == *i* ]]; then ... fi`, because profile text on stdout breaks JSON parsing.

## Disabling hooks

`/hooks` is a read-only browser that shows each hook's event, matcher, command and source.
Edit the settings file to change a hook.
`"disableAllHooks": true` turns every hook off without deleting them, and `--settings '{"disableAllHooks": true}'` does it for one run.
Only managed settings can disable managed hooks, and there is no way to disable a single hook in place.
