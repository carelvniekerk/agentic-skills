---
type: llm
weight: 3
---

PASS if the reply contains a complete agent Markdown file whose frontmatter has `name`, a `description` that says when Claude should delegate (for example on CI logs, test output or failures), and an explicit `tools` field that lists no write-capable tool (no `Write`, `Edit` or `NotebookEdit`), and whose body instructs the agent to return a short structured summary of the failures rather than raw log content.
FAIL if `tools` is omitted, if it includes `Write` or `Edit`, if read-only is enforced only through `permissionMode`, or if the body sets no return format.
