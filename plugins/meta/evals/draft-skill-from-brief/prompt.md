---
description: Drafting a skill from a complete brief. Checks the draft's structure rather than its wording.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, authoring]
---

Make me a personal skill called pr-summary. It should summarise the current branch's diff against main into a PR description: a one-paragraph summary, then a list of risky changes (migrations, config, auth). It should trigger when I say things like "summarise my changes", "write the PR description" or "what did I change on this branch". It only reads git state, no side effects, and I don't want test cases for it.

I've answered your intake questions already, so don't ask me anything. Show the complete SKILL.md in your reply instead of writing files.
