---
description: Near miss. A question about one pasted file needs no subagent.
max_turns: 6
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [delegate, negative]
---

What does this do, and is the rounding right?

```python
# src/shared/money.py
from decimal import Decimal, ROUND_HALF_EVEN

def quantize(value: Decimal, places: int = 2) -> Decimal:
    return value.quantize(Decimal(1).scaleb(-places), rounding=ROUND_HALF_EVEN)
```
