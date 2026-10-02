---
type: llm
weight: 3
---

PASS if the review states all three of the following:
(a) `disable-model-invocaton` is misspelt and Claude Code silently ignores the unknown key, so the skill stays model-invocable;
(b) `allowed-tools` pre-approves tools and does not restrict them, so it cannot stop Bash, and the fix is `disallowed-tools` (or a permission deny rule);
(c) the nested reference (SKILL.md to guide.md to detail/format.md) should be linked directly from SKILL.md, or the long reference file needs a table of contents.
FAIL if any of (a), (b) or (c) is missing, or if the review claims `allowed-tools` restricts tools.
