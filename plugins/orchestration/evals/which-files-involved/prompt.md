---
description: A which-files-would-this-touch question should reach repo-map.
max_turns: 12
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [delegate, repo-map]
---

We need to add a per-customer currency to invoices, so `Money` has to carry a currency code. Which modules and files would that touch, and how do billing, the API and the nightly job depend on each other today?
