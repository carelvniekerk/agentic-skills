---
type: llm
weight: 3
---

PASS if the answer recommends `claude plugin eval` (or an equivalent with-plugin against without-plugin comparison in fresh sessions) as the way to measure whether the skill improves output, and separately covers trigger testing with prompts that should and should not trigger the skill.
FAIL if it only suggests trying prompts manually in the current session, or never compares against a run without the skill.
