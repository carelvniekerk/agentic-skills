---
description: English report section with no listed AI tells but figurative verbs on things, a verbless caption and layout description. The skill should rewrite those sentences and keep every figure and date.
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Write, Edit, Glob, Grep, Skill, Bash]
tags: [copyedit, en, effect, verbs]
---

This section goes to the client on Monday and the wording feels sloppy. Save it as `section.md` and copyedit it, please.

```markdown
## Target map

Four columns, eight numbered zones, drawn from the 2026-09-14 target slide.
Each box carries the slide's wording, and its panel names the suggested technology.
Each tool receives two scores from 1 to 5 for the feature that carries the capability.
Bold marks a tool that covers more than one zone or job.
Options with the same scores sit side by side, and Cloud Run appears under both Zone 2 and Zone 4 because it serves both.
Cloud Run hosts applications, APIs and agent services.
```
