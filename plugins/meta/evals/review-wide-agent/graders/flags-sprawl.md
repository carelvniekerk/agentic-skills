---
type: llm
weight: 3
---

PASS if the review flags that the tool list is too large (fourteen or more tools) because tool selection gets less reliable as the list grows, says the agent's scope is too wide for one agent (pull request review, issue triage, Slack posting and Jira sync), and recommends splitting it into narrower agents that each hold only the few tools their job needs, ideally five or fewer and not more than about ten. A note that the description "Helps with the repo" is too vague to delegate on is a plus.
FAIL if it only improves the description, or accepts the fourteen-tool list as it stands.
