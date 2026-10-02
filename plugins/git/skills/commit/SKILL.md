---
name: commit
description: >-
  Commit the current work in well-scoped commits and push: reviews every staged, unstaged and untracked change, splits unrelated concerns into separate commits, writes messages that carry the reasoning from the conversation, runs pre-commit hooks without bypassing them and pushes to the upstream branch.
  Use when the user says "commit", "commit this", "commit my changes", "make a commit", "save my work", "let's commit", "push this up" or "record this in git", or otherwise asks for finished work to be captured in git, even if they do not say "commit".
  Opening or merging a pull request belongs to the sibling pr skill.
allowed-tools: Read Grep Glob Bash(git *)
---

# Commit

You turn the working tree into one or more reviewed, well-scoped commits and push them.

Invoking this skill is the user's instruction to commit and then push, so push without asking again once the commits are made.
The skill never rewrites history: no `--amend`, no rebase, no force-push, no hook bypass.
It stops and reports instead of guessing when the diff holds a secret, when staging is ambiguous, when a merge or rebase is in progress, or when the push is rejected.

## Contents

- Workflow
- Stance
- Phase 1: gather state
- Phase 2: review
- Phase 3: group
- Phase 4: write the messages
- Phase 5: stage and commit
- Phase 6: push
- Gotchas
- Strict prohibitions

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Commit progress:
- [ ] 1. State gathered, untracked files included
- [ ] 2. Every changed and new file reviewed (secret found: stop)
- [ ] 3. Grouping decided and shown before any git add
- [ ] 4. Messages written from the diff and the conversation
- [ ] 5. Each group staged, verified and committed (hook failure: fix, re-stage, commit again)
- [ ] 6. Pushed, and the final state reported
```

## Stance

Committing is the moment the user's description of their change is written into history, so check it against the diff instead of transcribing it.

- If the change does not do what the user says, or the diff holds something they have not mentioned, say so in your first line, before any grouping plan.
- Put the uncomfortable findings first: a secret, a debug print, a half-finished refactor or an unrelated file.
- Challenge the grouping or the message only where it changes what lands in history.
If the user's split holds, say so in a clause and move on, and do not invent a reason to split a coherent change.
- When you disagree, give the reason, the alternative and the concrete downside, for example that a mixed commit cannot be reverted without losing the fix.
- Hold your position under pushback and revise it only for a new fact or a better argument.
After three exchanges, state the disagreement plainly and follow the user's decision.
- Never write a hypothesis into a message as fact.
If the conversation did not establish why a bug happened, the message says what changed and leaves the cause out or marks it as suspected.
- Surface anything off in the diff even when it is out of scope: a widened exception handler, a fallback that hides a failure, a test that now asserts nothing.

## Phase 1: gather state

Run these in parallel:

```bash
git status --porcelain=v1 --branch --untracked-files=all
git diff --cached
git diff
git log --oneline -10
```

`git diff` does not show untracked files, so read every `??` entry from the status output with `Read`.
For a binary file or one over 1 MB, report its path and size instead of reading it, and ask whether it belongs in the repository.

Stop and ask before going further if the status shows a merge, rebase, cherry-pick or bisect in progress, or a detached `HEAD`.

Read the conversation for the reasoning behind the change: the bug report, the root cause that was established, the alternatives ruled out, the design decision taken.
That reasoning goes into the message bodies.

## Phase 2: review

Check every changed and new file for:

1. **Correctness**: does the change do what it appears to do?
2. **Safety**: secrets, tokens, credentials, private keys, `.env` files, internal URLs or personal data.
3. **Scope**: does it belong with the rest, or is it a different concern?
4. **Leftovers**: debug prints, commented-out code, stray TODOs, editor or OS files such as `.DS_Store`.

If a file contains a secret, stop and tell the user which file and line, and do not stage anything.
If a generated or local file such as `__pycache__/` or `.venv/` shows up as untracked, propose a `.gitignore` entry instead of committing it.

## Phase 3: group

Keep the changes together when they implement one idea, however many files they touch.
Split them when they are distinct concerns, for example a bug fix next to an unrelated feature, a dependency bump next to logic changes, formatting mixed with behaviour changes, or config for an unrelated service.

If the user had already staged a set of files, treat it as their intended first commit and say so, unless the review found a problem in it.

Before touching `git add`, list each planned commit with its files and a one-line reason.
A single commit needs no plan, only the message.

## Phase 4: write the messages

Match the convention in `git log`.
Where the repository has none, use `<type>: <description>` with type one of `feat`, `fix`, `refactor`, `docs`, `test` or `chore`, a subject under 72 characters in the imperative mood, and no full stop.

Write a body whenever the conversation holds research, a root-cause analysis, a debugging session, a design decision or a trade-off.
The body explains why and what was learned: what caused the bug, why this approach, which alternatives were ruled out.
A change with no such context gets a subject only.

Write the body to this register:

- British English, plain complete sentences in the active voice, lines wrapped at 72 characters.
- Identifiers from the code verbatim, and one name for one thing across subject and body.
- No em or en dashes as punctuation, no semicolons where a full stop works, and no padding: if the reason fits in one sentence, write one sentence.
- No antithesis framing ("not just a fix, but a refactor"), colon-then-reveal, rhetorical questions, filler hedges ("it's worth noting", "that said"), or metaphor where the technical noun works.
- None of: delve, leverage, harness, unlock, seamless, holistic, pivotal, crucial, underscore, foster, showcase, elevate, game-changer, and robust except as the statistical term.
- No performance or reliability claim unless a measurement in this session supports it.

End every message with the model-agnostic trailer `Co-Authored-By: Claude <noreply@anthropic.com>`.
Name the platform and never a model version, because the harness rotates models and a version string goes stale.

```text
fix: count boundary values once in sliding window aggregation

The window range check used an inclusive upper bound, so values exactly
on the boundary were counted in two windows. Under high-frequency input
this inflated the aggregated metrics by up to a factor of two. The check
now uses an exclusive upper bound, which matches the documented contract.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Phase 5: stage and commit

For each planned commit, stage its files by path and check the result:

```bash
git add path/to/file1 path/to/file2
git diff --cached --stat
```

Use `git add -A` only when every remaining change belongs in this commit.
If the staged set is not what the plan says, fix it with `git restore --staged <path>` before committing.

Commit through a heredoc so the body keeps its line breaks:

```bash
git commit -m "$(cat <<'EOF'
<type>: <description>

<body>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

If a pre-commit hook fails, the commit was not created.
Read the hook output.
If the hook rewrote files itself (a formatter, an end-of-file fixer), re-stage only the rewritten files that belong to this commit.
If it reports a problem it cannot fix, such as a lint error or a failed type check, report it to the user and agree the fix before editing code.
Then run the same `git commit` again, never `--amend`, because amending would rewrite the previous, unrelated commit.

Confirm each commit with `git log --oneline -3`, then move to the next group.

## Phase 6: push

```bash
git push
```

If the branch has no upstream, run `git push -u origin HEAD`.
If the repository has no remote, report that the commits are local and stop.
If the push is rejected as non-fast-forward, report the error verbatim and ask how to proceed: suggest `git pull --rebase`, and do not run it or force-push on your own.

Finish with the commits created (hash and subject) and the branch they were pushed to.

## Gotchas

- `git diff HEAD` leaves out untracked files, so a new file holding a key is invisible to a review that only reads diffs.
- A hook that rewrites files leaves them modified and unstaged, so committing again without re-staging fails the same way.
- Pre-commit stashes unstaged changes while it runs, so a file that is partly staged is checked only on its staged part.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| `--no-verify`, `-n` on commit, `-c core.hooksPath=...` | Bypasses the pre-commit hooks |
| `--no-gpg-sign`, `-c commit.gpgsign=false` | Bypasses signing |
| `--amend`, `git rebase`, `git reset` on commits | Rewrites history the user did not ask to change |
| `git push --force`, `--force-with-lease`, `+refspec` | Overwrites upstream history |
| `git add -A` or `git add .` while splitting | Pulls files into the wrong commit |
| Committing a secret, credential or `.env` file | The leak is permanent once pushed |
| Skipping the review of untracked files | New files are where secrets usually arrive |
