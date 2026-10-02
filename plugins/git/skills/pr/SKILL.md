---
name: pr
description: >-
  Take a finished branch to a pull request: runs the tests, the project's pre-commit hooks, linter and type checker on the changed files, reviews the full branch diff with the user, opens the PR with gh, and on request waits for CI, merges, deletes the branch and resyncs the default branch.
  Use when the user says "open a PR", "create a pull request", "make a PR", "raise a PR", "submit this for review", "send it up for review", "ship it" or "let's merge this", or otherwise says the branch is ready to leave their machine, even if they do not say "pull request".
  Committing without a pull request belongs to the sibling commit skill.
allowed-tools: Read Grep Glob Bash(git *) Bash(gh pr *) Bash(gh repo view *) Bash(uv *) Bash(uvx *) Bash(npm *) Bash(npx *) Bash(cargo *) Bash(make *) Bash(just *) Bash(pytest *)
---

# Pull request

You take a finished branch through tests, quality checks and a review with the user, open the pull request, and merge it only if the user asks.

The skill does not commit uncommitted work, rewrite history, force-push, bypass hooks or branch protection, push to the default branch, or bump tool versions.
It stops and reports test failures, type errors, failing CI and merge conflicts rather than working around them.
The review (Phase 4) and the merge (Phase 6) are user gates and never advance without an explicit yes.

## Contents

- Workflow
- Stance
- Phase 1: gather state
- Phase 2: run the tests
- Phase 3: hooks, lint and type check
- Phase 4: review (user gate)
- Phase 5: open the pull request
- Phase 6: merge (user gate)
- Phase 7: resync
- Gotchas
- Strict prohibitions

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
PR progress:
- [ ] 1. State gathered: clean tree, feature branch, base branch, every commit in the PR
- [ ] 2. Tests run (failure: stop and report)
- [ ] 3. Hooks, lint and type check run on the changed files (type errors: stop and report)
- [ ] 4. Review presented and the user said yes (changes wanted: return to 2)
- [ ] 5. Branch pushed and PR opened, URL reported
- [ ] 6. Merge decision asked; if yes, CI green and merged
- [ ] 7. Default branch in sync with origin, final state reported
```

## Stance

Your job is to make the PR better, not to wave it through on the user's description of it.

- If the branch does not do what the user says, or it should be more than one PR, say so before running anything.
- In the Phase 4 report, the first line says whether you would open this PR as it stands, and blockers come next.
- Challenge the design only where the weakness changes what the user should do.
If the approach holds, say so in a clause.
An empty suggestions list is a legitimate result, so do not invent one to fill the section.
- When you disagree, give the reason, the alternative and the concrete downside of the user's approach, phrased for the finding rather than from a template.
- Hold a finding under pushback and revise it only for a new fact or a better argument.
After three exchanges, state the disagreement plainly, offer to record it under Notes in the PR body, and follow the user's decision.
- Tag load-bearing inferences `[Likely]` or `[Guessing]`: an unmeasured performance claim, a guess about a library's behaviour you have not read, a theory about a flaky test.
Do not tag routine reporting of command output.
- List the judgement calls you made, and surface anything off in the test and lint output: skipped tests, tests that pass because they assert nothing, suppressed warnings, a coverage change larger than the diff explains.

## Phase 1: gather state

Run these in parallel:

```bash
git status --porcelain=v1 --branch --untracked-files=all
git fetch origin --prune
gh repo view --json defaultBranchRef,squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed
gh pr view --json url,state,baseRefName 2>/dev/null || echo "no PR for this branch"
```

Take the base branch from `defaultBranchRef` unless the user names another, then read the whole branch:

```bash
git log --oneline origin/<base>..HEAD
git diff origin/<base>...HEAD
```

Stop and ask before going further when:

- The working tree has uncommitted or untracked changes.
Offer to run the `git:commit` skill first, because later phases commit fixer output and must not sweep up unrelated work.
- You are on the default branch.
Offer to create a feature branch with `git switch -c <type>/<short-slug>`.
- `origin/<base>..HEAD` is empty, so there is nothing to open a PR for.
- A PR for this branch is already open.
Then the job is to push new commits and report the existing URL, not to create a second PR.

If the branch is behind `origin/<base>`, say so and let the user decide whether to merge the base in first.
Read the conversation for the goals, decisions and trade-offs behind the work, because they feed the review and the PR body.

## Phase 2: run the tests

Use the project's own runner:

| Signal | Command |
| --- | --- |
| `pyproject.toml` with a uv lock | `uv run pytest` |
| `package.json` with a `test` script | `npm test` |
| `Cargo.toml` | `cargo test` |
| `Makefile` or `justfile` with a `test` target | `make test` or `just test` |

If there is no test setup, say so and continue.
If tests fail, stop and report the failures, and do not edit code to make them pass until the user agrees the fix.

## Phase 3: hooks, lint and type check

Run checks on the files the branch changed, with the tool versions the project pins, so the PR does not pick up reformatting of untouched files.

If `.pre-commit-config.yaml` exists, run the project's hooks over the branch's changes:

```bash
uvx pre-commit run --from-ref origin/<base> --to-ref HEAD
```

Without pre-commit, run the stack's linter and formatter on the changed files: for Python, `uv run ruff check --fix <files>` and `uv run ruff format <files>`, falling back to `uvx ruff` when ruff is not a project dependency.

Then run the type checker the project configures, such as `uv run ty check`, `uv run mypy`, `npx tsc --noEmit` or `cargo clippy`.
If it reports errors, stop and report them, and do not rewrite code to satisfy the checker without the user's agreement.
Name every step you skipped and why.

If a fixer changed files, the tree was clean at Phase 1, so every modified file is fixer output.
Review that diff, then commit it by path:

```bash
git diff --name-only
git add <files from the list above>
git commit -m "$(cat <<'EOF'
chore: apply lint and formatting fixes

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Phase 4: review (user gate)

Review the full diff against the base branch, every commit and not only the latest.
For each meaningful change, check:

1. **Correctness**: off-by-one errors, wrong branches, swallowed errors, races.
2. **Design**: does it fit the surrounding architecture, or does it add an abstraction that only one caller uses?
3. **Scope**: unrelated cleanup, unused code or drive-by refactors that belong in another PR.
4. **Safety**: secrets, tokens, internal URLs, personal data.
5. **Tests**: is the change covered, and do the existing tests still assert something meaningful?
6. **Quality**: naming, error handling at boundaries, comments that narrate what instead of why, dead code, leftover TODOs.
7. **Compatibility**: changes to public APIs, migrations, on-disk formats, environment variables or CLI flags.
8. **Performance**: quadratic loops on hot paths, unbounded memory growth, blocking calls in async code.

Report in this order:

```text
<one line: would you open this PR as it stands, and why>

Blockers: must be fixed before the PR opens.
Suggestions: worth considering, possibly out of scope.
Observations: design choices worth naming in the PR body.
```

Stop and wait for the user.
If they want changes, make the agreed edits, commit them with `git:commit`, and return to Phase 2.
Continue to Phase 5 only on an explicit yes.

## Phase 5: open the pull request

```bash
git push -u origin HEAD
```

If the push is rejected, report the error verbatim and do not force-push.

Title: the commit convention (`<type>: <description>`), under 70 characters.
Body: this template, filled from the conversation and the diff.
Keep Summary and Test plan, and drop other sections that do not apply.

```markdown
## Summary

- <one to three bullets, one is right for a one-idea change>

## Motivation

<the problem, trigger or constraint behind the change>

## Changes

<what changed and why, grouped, naming the key files>

## Test plan

- [ ] <verification step>

## Notes

<alternatives considered, follow-ups, known limitations, recorded disagreements>
```

Write the title, the body and any commit message to this register:

- British English, plain sentences in the active voice, sentence case headings, prose in Motivation, Changes and Notes unless the content is a list.
- Identifiers from the code verbatim, and one name for one thing throughout.
- The first bullet does not restate the title, and the body does not end with a recap.
- No em or en dashes as punctuation (hyphens for numeric ranges), no antithesis framing, colon-then-reveal, rule-of-three padding, filler hedges, rhetorical questions, scare quotes or metaphor where the technical noun works.
- None of: delve, leverage, harness, unlock, seamless, holistic, pivotal, crucial, underscore, foster, showcase, elevate, game-changer, and robust except as the statistical term.
- No performance or reliability claim unless a measurement in this session supports it.

```bash
gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Report the PR URL.

## Phase 6: merge (user gate)

Ask one question and wait:

> Merge this PR now? (no / merge and keep the branch / merge and delete the branch)

On no, report the PR URL and stop.

On yes, wait for CI first:

```bash
gh pr checks --watch --fail-fast
```

If a check fails, report which one and stop.
If the repository reports no checks, say so and continue.

Pick the strategy from the Phase 1 `gh repo view` output: the only allowed one, or squash when several are allowed and the user has not said otherwise.
Ask when the history suggests a different convention.

```bash
gh pr merge --squash                  # keep the branch
gh pr merge --squash --delete-branch  # delete local and remote branch, switch to the default branch
```

If the merge fails on conflicts, pending checks or missing approvals, report the error verbatim and ask how to proceed.

## Phase 7: resync

```bash
git switch <base>
git pull --ff-only
git fetch --prune
git status -sb
```

`git status -sb` must show `## <base>...origin/<base>` with no ahead or behind count.
If the local default branch is ahead of origin, list the stray commits and ask, and never push them.
If `--ff-only` fails, report the divergence and stop.

Finish with the PR URL, whether it merged and how, whether the branch was deleted locally and remotely, and the sync state of the default branch.

## Gotchas

- `gh pr merge --delete-branch` already deletes the local branch and checks out the default branch, so a following `git branch -D` fails.
- `uvx ruff` runs the latest release, not the version the project pins, so its formatting can disagree with the project's own pre-commit hook.
- `pre-commit autoupdate` changes build configuration, so a version bump inside a feature PR is out of scope.
Mention outdated hooks as a suggestion instead.
- Merging straight after `gh pr create` races CI, because the checks have not started yet.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| `--no-verify`, `-c core.hooksPath=...` | Bypasses the pre-commit hooks |
| `--no-gpg-sign`, `-c commit.gpgsign=false` | Bypasses signing |
| `--amend`, `git rebase`, `git reset` on pushed commits | Rewrites history reviewers have seen |
| `git push --force` or `--force-with-lease` | Overwrites upstream history |
| `git push` while on the default branch | Lands commits without a PR |
| `git add -A` or `git add -u` on a tree that was not clean | Commits unrelated work |
| `gh pr merge --admin` | Bypasses branch protection |
| Merging before CI finishes, or past a failed check | Lands unverified code |
| `pre-commit autoupdate` inside the PR | Unrequested build configuration change |
| Advancing past Phase 4 or Phase 6 without an explicit yes | The gates exist on purpose |
| Editing code to silence failing tests or type errors without agreement | Hides real problems |
| Committing secrets or credentials | The leak is permanent once pushed |
