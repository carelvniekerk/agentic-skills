---
description: Renaming a function used across modules should reach call-sites.
max_turns: 12
allowed_tools: [Agent, Read, Glob, Grep, Skill]
tags: [delegate, call-sites]
---

I want to rename `compute_tax` in `src/billing/tax.py` to `calculate_tax` and change it to take a `Decimal` rate instead of a float. I think it is called from a few places across the repo, including tests. Make the change.
