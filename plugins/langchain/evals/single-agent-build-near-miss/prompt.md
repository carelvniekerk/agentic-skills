---
description: Near miss. Writing one LangGraph agent with two tools is not an architecture question, so the architect skill should not fire.
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
tags: [langgraph, negative]
---

Write a minimal LangChain agent with two tools, a `calculator(expression: str)` and a `get_time(timezone: str)`, using init_chat_model with the model name read from an environment variable. Just the code.
