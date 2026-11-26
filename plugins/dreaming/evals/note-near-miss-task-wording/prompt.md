---
description: Near-miss. A task instruction that contains marker words ("don't", "always", "instead") but holds no lasting lesson should not load note.
max_turns: 3
allowed_tools: [Read, Glob, Grep, Skill]
tags: [note, negative]
---

Read plugins/dreaming/hooks/dream-gate.sh but don't print the whole file, just the first ten lines, and always show line numbers in this answer instead of a summary.
