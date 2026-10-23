---
description: Agent(type) in a subagent's tools list is ignored. It restricts spawnable types only for an agent run as the main thread with --agent.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-agent, review, hard]
---

This is a subagent in my plugin marketplace repo at plugins/build/agents/orchestrator.md. I want it to be able to spawn only the builder and tester agents and nothing else. Does the tools line do that? Review only, don't change files.

```markdown
---
name: orchestrator
description: Runs the build and test agents in order and reports the result.
tools: Agent(builder, tester), Read, Grep
model: sonnet
---

You coordinate the builder and tester agents and report whether the build passed.
```
