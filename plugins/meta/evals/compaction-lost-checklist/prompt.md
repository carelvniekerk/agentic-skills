---
description: Diagnosis needs the documented compaction limit (first 5,000 tokens per skill, 25,000 combined) rather than generic context-window advice.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, hard]
---

My personal skill at ~/.claude/skills/release/SKILL.md is about 900 lines (around 14k tokens). The release checklist is at the very end. It works fine at first, but in long sessions, after Claude Code has auto-compacted, Claude stops following the checklist even though I invoked the skill at the start. What is going on in Claude Code specifically, and how should I restructure the skill?
