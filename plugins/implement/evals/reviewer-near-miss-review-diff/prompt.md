---
description: Near-miss. An ad-hoc request to review a diff is not an implement loop and must not spawn implement:code-reviewer, which needs a brief with acceptance criteria.
max_turns: 4
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [reviewers, negative]
---

Can you review this diff for bugs before I push it?

```diff
-    if len(items) > 0:
+    if len(items) >= 0:
         total = sum(i.price for i in items)
```
