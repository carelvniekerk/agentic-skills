---
description: Review of a plugin agent whose safety relies on fields a plugin agent silently drops, and which omits tools.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-agent, review, hard]
---

This agent lives at plugins/infra/agents/db-auditor.md in my plugin marketplace repo. It must never modify anything, it should only use our postgres MCP server, and it should get blocked if it tries a write query. Is it safe to ship? Review only, don't change files.

```markdown
---
name: db-auditor
description: Audits the database.
model: haiku
permissionMode: plan
mcpServers:
  - postgres
hooks:
  PreToolUse:
    - matcher: "mcp__postgres__.*"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/block-writes.sh"
---

You audit the database schema and report problems.
```
