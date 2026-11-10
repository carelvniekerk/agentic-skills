---
description: English executive summary with planted AI tells, German number formats and a hypothesis. The skill should fix the language, keep every figure and keep the hypothesis labelled.
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Write, Edit, Glob, Grep, Skill, Bash]
tags: [copyedit, en, effect]
---

This goes to the client on Friday and it reads like ChatGPT wrote it. Save it as `summary.md` and fix the language, please.

```markdown
# Executive Summary

Example Retail operates a large and genuinely capable analytical platform — one that has grown organically alongside the business. It carries roughly 31.000 queries a day.

One point deserves emphasis before the detail begins. The single largest opportunity is not a platform migration and not a tooling purchase. It is the move from nightly full rebuilds to incremental updates.

Production tables are rebuilt in full each night rather than updated incrementally. 212 of 530 nightly tasks issue a full replace, and retained previous versions make up 41,2 per cent of the physical footprint, highlighting the scale of the issue.

Three of 30 nightly runs finished in under ten minutes while reporting success. A skipped sensor chain would explain this. This is a hypothesis and we recommend verifying it first.

The concern is the supply chain, not the concept. The pattern is the deliverable, not the domain!
```
