---
description: Near-miss. Comparing two code idioms should not load source-comparison.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [source-comparison, negative]
---

Which is better here, a list comprehension or a generator expression?

```python
total = sum([x * x for x in values])
```
