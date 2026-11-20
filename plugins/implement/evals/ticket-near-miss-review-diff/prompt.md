---
description: Near-miss. An ad-hoc diff review is not a ticket and must not load ticket.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [ticket, negative]
---

Can you review this diff for bugs before I push it?

```diff
-    if len(items) > 0:
+    if len(items) >= 0:
         total = sum(i.price for i in items)
```
