---
type: llm
weight: 3
---

PASS if the reply warns that the plugin name `claude-tools` is reserved or will be rejected (for example by `claude plugin validate`) because names starting with `claude-` are not allowed for third-party plugins, and proposes or uses a different name.
FAIL if it writes the manifest with `"name": "claude-tools"` without warning that the name is rejected.
