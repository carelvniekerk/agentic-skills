---
type: llm
weight: 3
---

PASS if the reply says that nothing overrides anything between a user-level rule, a project rule and CLAUDE.md: they all load, and when two conflict Claude may follow either. It must recommend a design that avoids relying on an override, such as rewriting the global rule so it does not contradict the project (a default plus a scoped addition), wording the project rule as an explicit carve-out that names the rule it replaces (while saying that is still a request), removing the duplicate Writing section, or a hook if it must hold.
FAIL if it says, even hedged with "usually", that the project rule takes over, takes priority, has higher priority, wins, or has the edge, or if it accepts the plan to leave the duplicate Writing section in place.
