---
description: A supervisor-with-subagents request that meets none of the five gate conditions. The skill should say a single agent will do, in the first line, and propose the cheaper fix.
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [langgraph, gate]
---

We have a customer support bot with 12 tools (order lookup, refund, shipping status, FAQ search, and so on) in one LangGraph agent. It works, but I want to redo it as a supervisor with three subagents because that feels more scalable. One team owns the whole bot, latency is fine at about 2 seconds, the system prompt is 1,800 tokens, and we haven't seen it pick the wrong tool. Can you design the supervisor architecture for me?
