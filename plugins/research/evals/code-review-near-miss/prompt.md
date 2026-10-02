---
description: Near-miss. A code review should load neither peer-review nor the research reviewer agent.
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill, Agent]
tags: [peer-review, reviewer, negative]
---

Review this function for bugs before I merge it:

```python
def moving_average(xs, k):
    out = []
    for i in range(len(xs) - k):
        out.append(sum(xs[i:i + k]) / k)
    return out
```
