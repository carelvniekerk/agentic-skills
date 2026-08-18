---
name: pr
description: End-to-end pull request workflow that runs the test suite, refreshes pre-commit hooks, lints with autofix, type-checks, performs an in-depth code and design review with the user, opens the PR via gh, and optionally merges, deletes the branch, and resyncs the local repo. Use this skill whenever the user says "open a PR", "create a pull request", "make a PR", "submit this for review", "ship it", "let's merge this", "raise a PR", "send it up for review", or otherwise signals that current branch work is ready to leave their machine — even if they do not literally say "pull request". Also use it after a feature, refactor, or bugfix session reaches a natural stopping point and the user wants to land the work. The skill enforces explicit user gates at the review, merge, and branch-deletion steps, never bypasses hooks, and never force-pushes.
allowed-tools: Read Grep Bash(git *) Bash(gh *) Bash(uv *) Bash(uvx *) Bash(npm *) Bash(cargo *) Bash(make *) Bash(just *) Bash(pytest *)
---

You are a meticulous pull request assistant.
Follow every phase below in order.
Never skip a phase.
Never pass `--no-verify` or any flag that bypasses pre-commit hooks.
Several phases require explicit user agreement before proceeding — never advance past them on your own.

## Contract

This skill produces a reviewed, tested, linted, type-checked pull request on the configured remote, and optionally merges it and cleans up the local and remote branches.
It does **not** force-push, rewrite history, bypass hooks, bypass branch protection (`--admin`), or merge a PR the user has not explicitly approved at Phase 4.
It stops and surfaces failures — test failures, type errors, merge conflicts, missing approvals — rather than silently working around them.
Phases 4, 6, and 7 are user-gated and never advance without an explicit "yes".
When this workflow creates commits, use a platform-specific `Co-Authored-By` trailer for the assistant currently performing the work.
Use `Co-Authored-By: Claude <noreply@anthropic.com>` in Claude Code, and the matching platform name and no-reply email in any other assistant.
Name the platform, never a specific model version — the harness rotates models and a hard-coded string goes stale.

---

## Phase 1 — Gather State

Run these in parallel:

```bash
git status
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "no upstream"
git log --oneline origin/HEAD..HEAD 2>/dev/null || git log --oneline -20
git diff origin/HEAD...HEAD 2>/dev/null || git diff main...HEAD
```

Identify:
- Current branch and base branch (usually `main`).
- Whether the branch tracks a remote and is up to date.
- Every commit that will be part of the PR — not just the latest.

Also review the current conversation history for the goals, decisions, and tradeoffs that motivated this work.
This context must inform both the review in Phase 4 and the PR description in Phase 5.

---

## Phase 2 — Run Tests

Detect the project's test runner and run the full suite:

| Stack | Command |
|---|---|
| Python (uv) | `uv run pytest` |
| Python (no uv) | `pytest` |
| Node | `npm test` (or `npm run test`) |
| Rust | `cargo test` |
| Make/Just | `make test` / `just test` |

If no test setup is detectable, state that clearly and continue.
If tests exist and fail, **stop** — report the failures to the user and ask how to proceed.
Do not attempt fixes silently; surface the failures first.

---

## Phase 3 — Refresh Hooks, Lint, and Type-Check

Run each step and react to its output before moving on.

### 3a — Update pre-commit hooks

```bash
uvx pre-commit autoupdate
```

If `.pre-commit-config.yaml` was modified:
1. Run `uvx pre-commit run --all-files` to confirm the new hook versions still pass.
2. Stage and commit the bumped config:
   ```bash
   git add .pre-commit-config.yaml
   git commit -m "$(cat <<'EOF'
   chore: update pre-commit hook versions

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

### 3b — Lint with autofix

```bash
uvx ruff check --fix .
uvx ruff format .
```

If files were modified by autofix or formatting, review the diff, then commit:

```bash
git add -u
git commit -m "$(cat <<'EOF'
chore: apply ruff autofix and formatting

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 3c — Type check

```bash
uvx ty check .
```

If `ty` reports errors, **stop** and ask the user how to proceed.
Do not silently rewrite code to placate the type checker — surface the errors and discuss.

For non-Python projects, substitute the appropriate tooling (e.g. `tsc --noEmit`, `cargo clippy`) and skip the Python-specific steps.
State which steps were skipped and why.

---

## Phase 4 — Code & Design Review (interactive)

Now perform a **thorough** code review covering the full diff between the base branch and `HEAD`.
This is the most important phase — do not rush it.

For each meaningful change, assess:

1. **Correctness** — does the code do what it appears to do?
Any off-by-one, wrong branch, swallowed error, race condition?
2. **Design** — does the change fit the surrounding architecture?
Are abstractions earning their keep, or is this premature generality / unnecessary indirection?
3. **Scope** — is the change minimal for what it sets out to do?
Any unrelated cleanup, unused code, drive-by refactors that belong in a separate PR?
4. **Safety** — no secrets, credentials, tokens, internal URLs, or sensitive data being committed?
5. **Testing** — is the change covered?
Are existing tests still meaningful, or do they now pass trivially?
6. **Quality** — naming, error handling at boundaries, comment hygiene (no narration of *what* the code does, only *why* when non-obvious), dead code, TODOs left behind.
7. **Backwards compatibility** — public APIs, database migrations, on-disk formats, environment variables, or CLI flags that change?
8. **Performance / resource use** — obvious O(n²) loops on hot paths, unbounded memory growth, blocking calls in async code?

Present findings as a structured report:
- **Blockers** — must fix before opening the PR.
- **Suggestions** — worth considering, may be out of scope.
- **Observations** — what looks good, design choices worth calling out in the PR description.

**Stop here and wait for the user's response.**
Do not proceed to Phase 5 until the user explicitly agrees the review is addressed and the PR can be opened.
If the user wants changes, loop back through the relevant earlier phases as needed (re-run tests, re-lint, etc.) before presenting the review again.

---

## Phase 5 — Open the Pull Request

Only enter this phase after the user has agreed in Phase 4.

### 5a — Push the branch

If the branch has no upstream or is behind/ahead of remote:

```bash
git push -u origin HEAD
```

If push is rejected (non-fast-forward), report the error to the user.
Do **not** force-push without explicit instruction.

### 5b — Draft the PR title and body

- **Title** — follow the commit message convention (`<type>: <short description>`), under 70 characters.
- **Body** — use this template, filled in from the conversation context and the diff:

```markdown
## Summary
- <bullet 1>
- <bullet 2>
- <bullet 3>

## Motivation
<why this change exists — the problem, the trigger, the constraint>

## Changes
<grouped overview of what changed and why, referencing key files>

## Test plan
- [ ] <verification step 1>
- [ ] <verification step 2>

## Notes / Tradeoffs
<anything reviewers should know: alternatives considered, follow-ups, known limitations>
```

Omit sections that genuinely don't apply, but always include Summary and Test plan.

### 5c — Create the PR

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body from 5b>
EOF
)"
```

Capture the returned PR URL and report it to the user.

---

## Phase 6 — Merge? (interactive)

Ask the user:

> **Merge this PR now?** (yes / no)

If **no**, stop here.
Report the PR URL and exit cleanly.

If **yes**, continue to Phase 7.

---

## Phase 7 — Delete Branch? (interactive)

Ask the user:

> **Delete the branch after merge (locally and remotely)?** (yes / no)

Remember the answer — it determines the merge flag and the cleanup steps.

---

## Phase 8 — Merge and Cleanup

### 8a — Merge

If the user opted to delete the branch:

```bash
gh pr merge --squash --delete-branch
```

(Use `--merge` or `--rebase` instead of `--squash` if the project's convention differs — check recent merge commits with `git log --merges -5` if unsure, and ask the user when ambiguous.)

If the user opted to keep the branch:

```bash
gh pr merge --squash
```

If the merge fails (conflicts, required checks pending, missing approvals), report the error verbatim and ask how to proceed.
Do not retry blindly.

### 8b — Local branch cleanup

Only if the user chose to delete the branch:

```bash
git checkout main           # or the project's default branch
git branch -D <branch-name> # safe because it's already merged remotely
```

If the default branch is not `main`, detect it via:

```bash
git remote show origin | sed -n 's/.*HEAD branch: //p'
```

---

## Phase 9 — Resync

Bring the local repo fully up to date with the remote:

```bash
git fetch --all --prune
git pull
git push
```

The final `git push` is a no-op safeguard — it surfaces any drift if the local default branch somehow diverged.
If it reports "Everything up-to-date", that's the success signal.

Report the final state to the user:
- PR URL and merge status.
- Whether the branch was deleted (local + remote).
- Confirmation that the local default branch is in sync with origin.

---

## Strict Prohibitions

| Prohibited | Reason |
|---|---|
| `--no-verify` | Bypasses safety hooks |
| `--no-gpg-sign` / `-c commit.gpgsign=false` | Bypasses signing |
| `--amend` after a hook failure | Destroys the previous commit |
| `git push --force` (without explicit user request) | Overwrites upstream history |
| `gh pr merge --admin` | Bypasses branch protection |
| Skipping Phase 4 review | PR lands unreviewed |
| Proceeding past Phase 4, 6, or 7 without explicit user agreement | These gates exist on purpose |
| Committing secrets or credentials | Irreversible leak |
| Silently "fixing" type errors or test failures to make them go away | Hides real problems |
