---
description: Near miss. Library documentation already in the prompt needs no api-docs lookup.
max_turns: 6
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [delegate, negative]
---

Using only the documentation below, show me how to call `client.search` with a filter.

```text
client.search(query: str, *, filter: dict | None = None, limit: int = 10) -> list[Hit]
    filter: field name to exact-match value. limit: maximum number of hits.
```
