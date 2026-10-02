---
description: Diagnosis of a Stop hook that never lets Claude finish. Needs stop_hook_active and the Stop decision contract.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-hook, debug]
---

I wrote a Stop hook so Claude can't finish while tests are failing. Now when one test is flaky Claude just keeps going round and round re-running things and burning turns instead of finishing. Here's the script it runs:

```bash
#!/bin/bash
if ! uv run pytest -q >/tmp/pytest.log 2>&1; then
  echo "Tests are failing, fix them before stopping. See /tmp/pytest.log" >&2
  exit 2
fi
exit 0
```

What's wrong and how do I fix it without losing the guard? Just explain and show the fixed script.
