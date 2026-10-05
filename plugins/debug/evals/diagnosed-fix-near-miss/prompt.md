---
description: Near miss. The user has already diagnosed the bug and asks for the fix, so bug-discovery should not fire.
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
tags: [bug-discovery, negative]
---

Found the bug in our eval metric: `token_accuracy` divides by the total number of labels, but padded positions are -100 and shouldn't count. Fix it so it only counts non-padding tokens:

```python
import torch

def token_accuracy(logits: torch.Tensor, labels: torch.Tensor) -> float:
    preds = logits.argmax(dim=-1)
    correct = (preds == labels).sum().item()
    return correct / labels.numel()
```
