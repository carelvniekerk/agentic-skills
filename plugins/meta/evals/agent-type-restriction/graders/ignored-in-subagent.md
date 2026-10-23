---
type: llm
weight: 3
---

PASS if the reply says that the `Agent(type)` allowlist only restricts spawnable types for an agent run as the main thread with `claude --agent`, that a subagent definition ignores the parenthesised list so the restriction does not apply as written, and that omitting `Agent` from `tools` is how to stop a subagent spawning. Offering a way to get the restriction (running it as the main session agent) is a plus.
FAIL if it says the line restricts the subagent to builder and tester.
