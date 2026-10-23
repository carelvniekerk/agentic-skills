---
description: Near-miss. Allowing a command without a prompt is a settings.json permission, not an instruction file.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, negative]
---

Add a rule so Claude Code can run `npm run test` and `npm run lint` without asking me every time, but still asks before `npm publish`. Show me the settings.json snippet, don't write files.
