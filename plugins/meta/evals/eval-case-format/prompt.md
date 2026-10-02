---
description: Writing claude plugin eval cases needs the exact grader format, including the near-miss form with min 0, max 0 and arm both.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, hard]
---

My plugin `docs` has a skill `pdf-fill`. Write two `claude plugin eval` cases for it: one where a user asks to fill in a PDF form and the skill should fire, and one near-miss (they want to summarise a PDF) where `pdf-fill` must not fire. Show every file with its path relative to the plugin root. Don't write files, just put them in your reply.
