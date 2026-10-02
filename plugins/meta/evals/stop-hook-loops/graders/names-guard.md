---
type: llm
weight: 3
---

PASS if the reply explains that the hook re-blocks every time Claude tries to stop, and that the fix is to read `stop_hook_active` from the hook's JSON input on stdin and exit 0 when it is true (or an equivalent bounded-retry mechanism that uses the input), and the fixed script reads stdin.
FAIL if the reply only suggests retrying flaky tests, adding a timeout or removing the hook, without using `stop_hook_active` or another input-based loop guard.
