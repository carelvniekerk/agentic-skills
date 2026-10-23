---
description: Two rule files that should be path-scoped but load unscoped, for different reasons. One uses Cursor-style frontmatter, the other an unquoted leading-asterisk glob.
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-instructions, hard]
---

I can't tell what loads when in my .claude/rules setup. /context shows both of these rule files loaded at the start of every session, even in a docs-only task, but I want python.md only for Python work and latex.md only while editing .tex files in docs/paper. Work out what is wrong with each file, give me corrected versions, and tell me how to verify what loads. Propose only, don't write any files.

.claude/rules/python.md:

```markdown
---
description: Python conventions
globs: "**/*.py"
alwaysApply: false
---
Format with ruff, use type hints, and put docstrings in Google style.
```

.claude/rules/latex.md:

```markdown
---
paths: **/*.tex
---
Put each sentence on its own line and use \cref for cross-references.
```
