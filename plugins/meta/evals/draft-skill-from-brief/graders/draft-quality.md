---
type: llm
weight: 2
---

PASS if the reply contains a complete SKILL.md whose description names what the skill does and includes the user's trigger phrases, and whose body gets live git state (for example with dynamic context injection such as !`git diff main...HEAD`, or an explicit git command) and states the output format.
FAIL if the SKILL.md is missing, has no description, or the body gives no way to obtain the diff.
