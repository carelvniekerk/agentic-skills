---
description: Near-miss. A hook request should go to create-hook, not create-skill.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, negative]
---

I want Claude Code to refuse any Bash command containing `rm -rf` before it runs. What should the PreToolUse hook config look like? Just show me the JSON.
