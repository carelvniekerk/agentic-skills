---
type: llm
weight: 3
---

PASS if the reply states all of the following. First, `paths` is the only frontmatter field Claude Code reads for a rule, so `globs`, `description` and `alwaysApply` in python.md are silently ignored and the rule loads unconditionally at launch. Second, the unquoted `**/*.tex` in latex.md is a problem because a leading asterisk is not valid unquoted YAML, so the frontmatter fails to parse and the rule loads as if it had no `paths`, and the fix quotes the glob. Third, it names a way to verify, such as `/memory`, `/context` or `claude --debug`.
FAIL if any of the three is missing, or if a corrected file still uses `globs` or `alwaysApply`.
