---
description: Trigger. A reviewer verdict that names a recurring habit, with no marker words, should load note.
max_turns: 3
allowed_tools: [Read, Glob, Grep, Skill]
tags: [note, trigger]
---

The implement:code-reviewer agent returned this for the change you just made:

Verdict: BLOCKED
- `BLOCKING`: C1 hooks/sync.sh:42, the jq call ends in `|| true`, which turns a parse error into an allow. This is the third change in a row with a swallowed error. Fail closed and report the error.

Fix it.
