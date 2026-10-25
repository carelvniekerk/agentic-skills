---
description: Trigger. A which-pattern question tied to a concrete system should load architecture-design.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [architecture-design, trigger]
---

Our checkout code has to support Stripe today and probably Adyen and PayPal later. Should I use a factory, a strategy, an adapter, or something else? And where should the package boundaries go so the payment code does not leak into the order domain? I want a design doc and an ADR I can review before we write code.
