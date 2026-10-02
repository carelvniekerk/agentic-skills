---
type: llm
weight: 3
---

PASS if the review states all three of the following:
(a) a plugin agent silently ignores `permissionMode`, `mcpServers` and `hooks`, so none of those guarantees hold as written (naming at least `permissionMode` and `hooks` as ignored is required);
(b) with no `tools` field the agent inherits every tool from the parent, including write tools, Bash and any other connected MCP servers, so read-only must be enforced with an explicit `tools` allowlist (or `disallowedTools`);
(c) the hook belongs in the plugin's `hooks/hooks.json` and the server in the plugin's `.mcp.json` (or the agent must move to `.claude/agents/` to keep those fields).
FAIL if any of (a), (b) or (c) is missing, or if the review treats `permissionMode: plan` as an effective read-only guarantee for this agent.
