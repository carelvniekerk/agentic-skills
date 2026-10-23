---
description: Review of an agent with fifteen tools and four jobs. Checks the tool-count and scope guidance in create-agent.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-agent, review, hard]
---

Can you review this agent before I share it with the team? It should review pull requests, triage new GitHub issues, post a summary to Slack and keep our Jira tickets in sync. Review only, don't write files.

```markdown
---
name: repo-helper
description: Helps with the repo.
tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, NotebookEdit, mcp__github__list_prs, mcp__github__create_issue, mcp__github__get_pr, mcp__slack__post_message, mcp__jira__search, mcp__jira__create_ticket
model: sonnet
---

You help the team with anything to do with our repository, issues and tickets.
```
