---
type: llm
weight: 3
---

PASS if the reply says that rule files without `paths:` frontmatter load at launch like CLAUDE.md, so moving content into them alone saves no tokens, and that only rules with `paths:` globs (for example the LaTeX rules scoped to docs/paper and the migration rules scoped to the migrations directory) reduce what loads at the start. It must also say that the "never do" rules cannot be enforced by a file and need a hook if they must hold.
FAIL if it claims that splitting into unscoped rule files reduces the token cost, or never mentions `paths:` scoping.
