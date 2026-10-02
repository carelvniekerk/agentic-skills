---
type: llm
weight: 3
---

PASS if the review states all three of the following:
(a) `PostToolUse` runs after the tool has already executed, so it cannot block the push, and the hook must move to `PreToolUse`;
(b) `exit 1` is a non-blocking error, so blocking needs `exit 2` (with the reason on stderr) or a `permissionDecision: "deny"` JSON response;
(c) the matcher `mcp__github` contains only letters and underscores, so it is compared as an exact tool name and matches no MCP tool, and it needs `mcp__github__.*`.
FAIL if any of (a), (b) or (c) is missing.
