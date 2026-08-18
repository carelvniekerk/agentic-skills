---
name: commit
description: Thorough commit workflow that reviews all diffs, splits unrelated changes into separate logical commits, writes rich messages informed by the conversation history, runs pre-commit hooks without bypass, and pushes. Use this skill whenever the user says "commit", "commit this", "commit my changes", "make a commit", "save my work", "ship it", "let's commit", "push this up", "record this", or otherwise signals that the current work should be captured in git — even if they do not explicitly say the word "commit". Also use it at the natural end of a debugging, refactoring, or feature session when the user indicates they are done. The skill enforces conversation-aware messages, code review before staging, splitting of unrelated concerns, and never bypassing hooks or force-pushing.
allowed-tools: Read Grep Bash(git *)
---

You are a meticulous commit assistant.
Follow every phase below in order.
Never skip a phase.
Never pass `--no-verify` or any flag that bypasses pre-commit hooks.

## Contract

This skill produces one or more well-scoped git commits, each with a message that reflects the conversation context that motivated the change, followed by a push to the configured remote.
It does **not** rewrite history, force-push, amend prior commits, or bypass hooks under any circumstance.
If staging is ambiguous or the diff contains secrets, it stops and surfaces the issue rather than guessing.

---

## Phase 1 — Gather State

Run these in parallel:

```bash
git status
git diff HEAD          # all changes (staged + unstaged combined)
git diff --cached      # staged only
git diff               # unstaged only
git log --oneline -10  # recent history for message style
```

Also review the current conversation history for any research, debugging sessions, architectural decisions, or problem descriptions that motivated these changes.
This context must inform commit messages.

---

## Phase 2 — Code Review

For every changed file, assess:

1. **Correctness** — does the change do what it appears to do?
2. **Safety** — no secrets, credentials, or sensitive data being committed?
3. **Scope** — does this change belong with the others, or does it address a different concern?
4. **Quality** — obvious bugs, logic errors, or regressions introduced?

Flag any issues before proceeding.
If a file contains secrets or credentials, **stop immediately** and warn the user — do not commit.

---

## Phase 3 — Commit Grouping

Decide whether all changes form a single logical unit or must be split.

**Split when changes are clearly distinct concerns**, for example:
- A bug fix accompanied by an unrelated new feature
- Dependency upgrades alongside business-logic changes
- Formatting/style cleanup mixed with functional changes
- Config changes for an unrelated service

**Keep together when** all changes implement one coherent idea — even across many files.

If splitting is needed:
1. List each planned commit with: files it will include + one-line rationale.
2. Present the grouping plan clearly before touching `git add`.

---

## Phase 4 — Write Commit Messages

For each planned commit, write a message using this format (from CLAUDE.md):

```
<type>: <short description>

<body — required when the change benefits from explanation>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**Body rules:**
- Write a body whenever the conversation contains research, a root-cause analysis, a debugging session, a non-obvious design decision, or a tradeoff discussion.
Summarise the *why* and *what was learned*, not just what changed.
- For straightforward changes with no conversation context, a one-line subject is sufficient.
- Mention key findings: e.g. what caused a bug, why a particular approach was chosen, what alternatives were ruled out and why.
- Keep each line under 72 characters.
- End with a platform-specific trailer for the assistant currently performing the work.
Use `Co-Authored-By: Claude <noreply@anthropic.com>` in Claude Code, and the matching platform name and no-reply email in any other assistant.
Name the platform, never a specific model version — the harness rotates models and a hard-coded string goes stale.

**Example with body:**

```
fix: correct off-by-one in sliding window aggregation

After investigating the latency spike reported in monitoring, the root
cause was an inclusive upper bound in the window range check. Values at
exactly the boundary were counted twice, inflating aggregated metrics by
up to 2x under high-frequency data. Switched to exclusive upper bound to
match the documented contract.

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Phase 5 — Stage and Commit (loop per commit)

For each commit in the plan:

### 5a — Stage

Stage only the files for this commit.
Prefer specific file paths over `git add -A`:

```bash
git add path/to/file1 path/to/file2
```

Never use `git add -A` or `git add .` unless every remaining unstaged change belongs in this commit.

Verify staging is correct:

```bash
git diff --cached --stat
```

### 5b — Commit

Pass the message via heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

<body if needed>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Never pass `--no-verify`, `--no-gpg-sign`, or any hook-bypassing flag.**

### 5c — Handle Hook Failures

If a pre-commit hook fails:
1. Read the hook output carefully.
2. Fix the underlying issue (format errors, lint violations, etc.).
3. Re-stage the fixed files.
4. Create a **new** commit — never `--amend` after a hook failure, as the previous commit was not created.

### 5d — Verify

```bash
git log --oneline -3
```

Confirm the commit appears with the correct message.

---

## Phase 6 — Repeat for Remaining Commits

If the plan includes multiple commits, return to Phase 5 for the next group.
Ensure each group is cleanly staged before committing.

---

## Phase 7 — Push

After all commits are created and verified:

```bash
git push
```

If the push is rejected (non-fast-forward), report the error to the user and do **not** force-push.
Describe what happened and ask how to proceed.

---

## Strict Prohibitions

| Prohibited | Reason |
|---|---|
| `--no-verify` | Bypasses safety hooks |
| `--no-gpg-sign` / `-c commit.gpgsign=false` | Bypasses signing |
| `--amend` after hook failure | Destroys the previous commit |
| `git add -A` / `git add .` when splitting | Risks including wrong files |
| `git push --force` | Overwrites upstream history |
| Committing secrets or credentials | Irreversible leak |
| Skipping Phase 2 code review | Changes land unreviewed |
