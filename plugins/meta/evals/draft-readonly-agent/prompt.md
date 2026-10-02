---
description: Draft a read-only log-triage subagent from a brief. Checks explicit tool scope, a delegation description and a return contract.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-agent, draft]
---

I want a subagent for my project that I can hand a CI log or a pytest output and it tells me what actually failed. The logs are huge so I don't want them in my main conversation. It should never edit files. Put it at .claude/agents/ and just show me the complete file in your reply, I'll save it myself. Don't ask me questions, make sensible choices and list them.
