---
description: Near-miss. A request to design the architecture belongs to architecture-design and must not load ticket.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [ticket, negative]
---

We need a rate limiter in front of our Python API: per-key limits, a shared counter store and graceful degradation when the store is down. Design the architecture: modules, dependencies and which design patterns are worth using.
