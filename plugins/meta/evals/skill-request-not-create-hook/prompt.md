---
description: Near-miss. A request for a reusable review checklist is a skill, not a hook, even though it mentions running after edits.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-hook, negative]
---

I keep pasting the same PR review checklist into Claude after I finish editing: check error handling, check tests were added, check naming, check for leftover debug prints. I want to turn it into a SKILL.md I can invoke with a slash command. Show me the file, don't write it.
