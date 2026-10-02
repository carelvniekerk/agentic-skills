---
type: llm
weight: 3
---

PASS if the response, before running tests, lint or opening the PR:
(a) points out the uncommitted change in `src/cli.py` and identifies it as a leftover debug print;
(b) points out the untracked `notes/export-ideas.md`;
(c) stops to ask the user how to handle them (commit, discard, stash or leave out) rather than proceeding.
FAIL if the response proposes `git add -u`, `git add -A` or `git add .` at any stage while those changes are present, or opens the PR without resolving them, or runs `pre-commit autoupdate`.
