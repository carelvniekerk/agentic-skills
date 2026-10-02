# Hook templates

Complete configurations for common hooks, each tested shape taken from or checked against the hooks reference.
Adapt the matcher, `if` and script paths, then run the Phase 5 tests before relying on any of them.

## Contents

- Block destructive commands (PreToolUse, command)
- Guard pushes to main (PreToolUse, command, exit 2)
- Format files after edits (PostToolUse, command)
- Inject project state at session start (SessionStart, command)
- Audit configuration changes (ConfigChange, command)
- Check completion before stopping (Stop, prompt)
- Run tests before stopping (Stop, agent)
- Require a build artefact before a teammate idles (TeammateIdle, command)
- Auto-approve leaving plan mode (PermissionRequest, command)
- Reload direnv on directory change (SessionStart and CwdChanged)
- Desktop notification (Notification, command)
- Send events to a webhook (PostToolUse, http)
- Plugin hooks file
- Skill frontmatter hook

## Block destructive commands (PreToolUse, command)

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
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```

`.claude/hooks/block-rm.sh`, made executable with `chmod +x`:

```bash
#!/bin/bash
COMMAND=$(jq -r '.tool_input.command // empty')

if grep -qE 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+/([[:space:]]|$)' <<<"$COMMAND"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Blocked a recursive rm at the filesystem root. Delete a specific path instead."
    }
  }'
fi
exit 0
```

Exit 0 with no output leaves the call to the normal permission flow, so silence does not approve it.
For a rule that must always hold, add `Bash(rm -rf /*)` or similar to `permissions.deny` as well, because `if` filtering is best-effort.

## Guard pushes to main (PreToolUse, command, exit 2)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git push *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-push.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT") || {
  echo "guard-push could not parse the hook input, so the push was blocked." >&2
  exit 2
}

if grep -qE 'git[[:space:]]+push.*[[:space:]:](main|master)([[:space:]]|$)' <<<"$COMMAND"; then
  echo "Blocked a push to main. Push a feature branch and open a pull request." >&2
  exit 2
fi
exit 0
```

This guard fails closed on unparsable input.
It does not see a push to main made through a remote's default branch (`git push` with no refspec while on main), so test that form and decide whether to read the current branch as well.

## Format files after edits (PostToolUse, command)

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

Shell form is needed here for the pipe.
For Python files, swap the formatter for `uvx ruff format`.

## Inject project state at session start (SessionStart, command)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "printf 'Branch: %s\\nUncommitted files: %s\\n' \"$(git branch --show-current)\" \"$(git status --porcelain | wc -l | tr -d ' ')\""
          }
        ]
      }
    ]
  }
}
```

Plain stdout from `SessionStart` becomes context for Claude, and the hook re-runs on resume, so the values stay current.

## Audit configuration changes (ConfigChange, command)

```json
{
  "hooks": {
    "ConfigChange": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "jq -c '{timestamp: (now | todate), source: .source, file: .file_path}' >> ~/claude-config-audit.log"
          }
        ]
      }
    ]
  }
}
```

## Check completion before stopping (Stop, prompt)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Decide from this hook input whether Claude finished every task the user asked for. Reply {\"ok\": true} if so. Otherwise reply {\"ok\": false, \"reason\": \"<what remains>\"}, and add \"impossible\": true if the remaining work cannot be done. $ARGUMENTS"
          }
        ]
      }
    ]
  }
}
```

A prompt handler sees only the hook input, including `last_assistant_message`, and cannot run tests.

## Run tests before stopping (Stop, agent)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Run the project's test suite and report whether it passes. If tests fail, give the failing test names as the reason. $ARGUMENTS",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

Agent handlers are experimental and cost a multi-turn model run on every stop.
A command hook that runs the tests and checks `stop_hook_active` is cheaper and deterministic.

## Require a build artefact before a teammate idles (TeammateIdle, command)

```bash
#!/bin/bash
if [ ! -f "./dist/output.js" ]; then
  echo "The build artefact dist/output.js is missing. Run the build before stopping." >&2
  exit 2
fi
exit 0
```

## Auto-approve leaving plan mode (PermissionRequest, command)

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

## Reload direnv on directory change (SessionStart and CwdChanged)

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "direnv export bash >> \"$CLAUDE_ENV_FILE\"" }] }
    ],
    "CwdChanged": [
      { "hooks": [{ "type": "command", "command": "direnv export bash >> \"$CLAUDE_ENV_FILE\"" }] }
    ]
  }
}
```

## Desktop notification (Notification, command)

```bash
#!/bin/bash
input=$(cat)
body=$(jq -r '.message // "Claude Code needs your attention"' <<<"$input")
seq=$(printf '\033]777;notify;%s;%s\007' "Claude Code" "$body")
jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
```

Hooks have no terminal, so the escape sequence goes back through `terminalSequence` rather than to `/dev/tty`.

## Send events to a webhook (PostToolUse, http)

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

The POST body contains tool input and output, so confirm with the user where it goes before pointing it at anything but localhost.

## Plugin hooks file

`plugins/<plugin>/hooks/hooks.json`:

```json
{
  "description": "Automatic code formatting",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh",
            "args": [],
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

## Skill frontmatter hook

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
          args: []
---
```

The hook stays registered for the rest of the session once the skill runs.
Add `once: true` to remove it after its first successful run.
