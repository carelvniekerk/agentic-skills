---
description: Which subagents see CLAUDE.md, rules and auto memory. Needs the Explore and Plan exception and omitClaudeMd.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, hard]
---

My writing rules are in ~/.claude/CLAUDE.md and ~/.claude/rules/prose.md. Do my subagents follow them? I mainly use a custom reviewer agent in .claude/agents/, the built-in Explore agent, and a plugin agent from our marketplace. Does any of them see my auto memory? I want to know whether I have to paste the rules into each agent's prompt.
