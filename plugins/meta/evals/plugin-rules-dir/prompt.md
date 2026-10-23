---
description: A plugin has no rules component. A rules/ folder is not in the manifest or the standard layout, so the answer must point to a skill or a SessionStart hook.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, hard]
---

I maintain a plugin in our marketplace repo and I want it to ship a rules/ directory (a prose.md and a python.md with paths globs) so that those rules load automatically whenever someone enables the plugin, the same way .claude/rules/ works in a project. Can I do that, and if not, what is the closest thing? Answer only, don't write files.
