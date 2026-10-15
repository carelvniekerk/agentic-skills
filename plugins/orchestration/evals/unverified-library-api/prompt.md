---
description: Code against an unverified external API should reach api-docs.
max_turns: 12
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [delegate, api-docs]
---

Write the function that streams the output of a LangGraph `StateGraph` to the console, node by node, with partial tokens. We are on `langgraph==1.0.3` per `uv.lock`. I do not remember the current `stream_mode` options, so use the real ones.
