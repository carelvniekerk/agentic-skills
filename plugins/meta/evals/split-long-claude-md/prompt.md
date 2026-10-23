---
description: Splitting a long CLAUDE.md. Only path-scoped rules shrink the always-loaded part, and an unscoped split saves nothing.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, hard]
---

My project CLAUDE.md is about 620 lines and Claude has started ignoring parts of it. Rough layout: 40 lines of project overview and commands, 120 lines of Python conventions, 90 lines of writing and tone rules for docs, 70 lines of LaTeX rules for the paper in docs/paper, 150 lines on our release process, 80 lines on database migrations, and 70 lines of "never do" rules such as never push to main and never edit generated files. I want to move things into .claude/rules/ so Claude loads less. Tell me what to move where and what that saves in tokens. Propose only, don't change any files.
