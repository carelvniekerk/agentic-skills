---
description: Near-miss. A plain commit-and-push request should go to commit, not pr.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
tags: [pr, negative]
---

Just commit the README typo fix and push it, no PR needed.

You can't see my machine, so the repo state is pasted below. If you can't run git here, give me the exact commands and commit messages in order, and stop wherever you'd need to ask me something.

```text
$ git status --porcelain=v1 --branch
## main...origin/main
 M README.md

$ git diff
-Instal with uv:
+Install with uv:
```
