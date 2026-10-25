---
description: Trigger. A request to design a feature before building it should load architecture-design.
max_turns: 4
allowed_tools: [Read, Glob, Grep, Skill]
tags: [architecture-design, trigger]
---

We need to add a CSV import pipeline to our Python service: files arrive from three suppliers with different column layouts, rows are validated, and bad rows go to a review queue. Before we build anything, design the architecture: how should we split it into modules, what depends on what, and which design patterns are worth using here?
