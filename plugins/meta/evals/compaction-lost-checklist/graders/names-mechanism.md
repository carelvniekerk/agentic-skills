---
type: llm
weight: 3
---

PASS if the reply explains that after auto-compaction Claude Code re-attaches only the first 5,000 tokens of an invoked skill (or states a per-skill token cap with that figure), so content at the end of a long SKILL.md is cut, and recommends moving the checklist to the top or into the first part of the file (re-invoking the skill or splitting into reference files are acceptable additions).
FAIL if it gives only generic advice about context windows or attention without the per-skill re-attachment cap.
