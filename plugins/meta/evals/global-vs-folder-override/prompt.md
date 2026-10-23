---
description: A design task that includes an override plan. The docs describe no override between user-level and project rules, so a plan that relies on one needs correcting.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, hard]
---

I'm tidying how Claude Code is set up on my machine and for one client repo. Facts: ~/.claude/rules/prose.md says "use bullets and tables where useful". In my client repo ~/Projects/acme I want long-form paragraphs only. The acme repo also has a 380-line CLAUDE.md whose 60-line "Writing" section repeats the global prose rules. My plan is to add .claude/rules/prose.md to the acme repo with the opposite rule so that it takes over there, and to leave the Writing section in CLAUDE.md as it is. Is that plan sound? Tell me what the files should look like and what else I should change. Propose only, don't write any files.
