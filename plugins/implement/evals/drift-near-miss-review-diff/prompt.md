---
description: Near-miss. An ad-hoc diff review is not a drift check and must not load drift-check or spawn drift-reviewer.
max_turns: 4
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [drift-check, negative]
---

Can you review this diff for bugs before I push it?

```diff
-    if len(items) > 0:
+    if len(items) >= 0:
         total = sum(i.price for i in items)
```
