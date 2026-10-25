---
description: Near-miss. A local refactor of one function is not an architecture task and should not load architecture-design.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [architecture-design, negative]
---

Rewrite this function to use early returns instead of nested ifs:

```python
def classify(n):
    if n is not None:
        if n > 0:
            return "positive"
        else:
            if n < 0:
                return "negative"
            else:
                return "zero"
    else:
        return "missing"
```
