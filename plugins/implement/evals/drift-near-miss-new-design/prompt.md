---
description: Near-miss. Reviewing or writing a new design belongs to architecture-design and must not load drift-check.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [drift-check, negative]
---

I want to add a webhook dispatcher to our Python service: events are queued, retried with backoff and delivered to customer URLs. Design the architecture before we build anything, and tell me which modules it needs.
