---
description: Near-miss. Explaining a runtime error should not load eli5.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [eli5, negative]
---

What does this error mean? I get it when I call `model.generate(**inputs)`:

```text
RuntimeError: Expected all tensors to be on the same device, but found at least two devices, cuda:0 and cpu!
```
