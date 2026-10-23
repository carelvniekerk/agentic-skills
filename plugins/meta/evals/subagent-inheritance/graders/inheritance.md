---
type: llm
weight: 3
---

PASS if the reply says all of the following: custom subagents load the CLAUDE.md hierarchy including ~/.claude/CLAUDE.md and rules by default, the built-in Explore (and Plan) agent starts without CLAUDE.md, the parent's auto memory is not loaded into subagents, and a custom agent can opt out with the `omitClaudeMd` frontmatter field. A statement that `omitClaudeMd` on a plugin agent is undocumented or unverified is a plus.
FAIL if it says no subagent sees the rules, says every subagent sees everything, or omits the Explore exception.
