---
description: skillOverrides does not apply to plugin skills, so the baseline the user plans would silently keep the skill on.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, hard]
---

I want to check whether my `git:commit` skill (it comes from my `git` plugin) actually improves commit messages. My plan: run five prompts in a fresh session, then add `"skillOverrides": {"commit": "off"}` to `.claude/settings.local.json` and run them again for the baseline. Is that settings snippet right, or should the key be `git:commit`?
