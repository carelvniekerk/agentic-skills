---
description: Review of a hook config with defects that fail silently. Checks the decision-contract and matcher rules the hook skill exists to enforce.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-hook, review, hard]
---

i added these to .claude/settings.json so claude can't push to main or call any github MCP tool without me knowing. nothing seems to get blocked though. can you review it? don't write any files.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": ".claude/hooks/no-push-main.sh" }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "mcp__github",
        "hooks": [{ "type": "command", "command": "echo 'github tool used' >> ~/gh-audit.log" }]
      }
    ]
  }
}
```

.claude/hooks/no-push-main.sh:

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')
if [[ "$CMD" == *"git push"*"main"* ]]; then
  echo "pushing to main is not allowed"
  exit 1
fi
exit 0
```
