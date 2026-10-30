# Reviewer briefs and the rounds log

The fixed templates for the briefs that `implement:implement` gives its three reviewers, the template for the pre-lock test review, and the format of `.implement/rounds.md`.
A brief is built from these templates and from files and command output, and never from the implementer's own account of the work.

## Contents

- What goes in a brief and what stays out
- Building the parts
- The common brief
- The pre-lock test review brief
- The task paragraph for each reviewer
- What each reviewer receives
- The rounds log

## What goes in a brief and what stays out

A reviewer judges the work in a clean context, which means the brief gives it the specification and the artefacts and none of the implementer's reasoning.
The evidence for this design is limited: Anthropic's guidance recommends a fresh-context reviewer, and the one related study found no significant gain over a context-aware reviewer, so the brief keeps the framing out as a precaution and not as a proven benefit.

In the brief:

- The acceptance criteria, verbatim from the design.
- The design excerpt the reviewer needs, verbatim.
- The list of changed files, and the diff of tracked files.
- The test, lint and type-check output.
- The locked paths and the result of the hash comparison.
- The fixed task paragraph for that reviewer.
- The reporting line as the last line, because a reviewer only reports steps when its brief asks it to, and the line carries no judgement about the work.

Out of the brief:

- Your summary of what you did, and why you did it.
- Any statement that something is fixed, correct, intentional or safe.
- Findings from earlier rounds, and the fact that there were earlier rounds beyond the round number.
- The conversation, and the user's opinions.

If a part is too long to include whole, say what was cut and name the files, so the reviewer can read them.
A truncated diff that is not marked as truncated misleads the reviewer.

## Building the parts

Take the parts from commands and files, so none passes through your own wording:

```bash
git diff HEAD -- . ':(exclude).implement'
git ls-files --others --exclude-standard
git diff HEAD --name-only
uv run pytest -q 2>&1 | tail -n 60
ruff check . 2>&1 | tail -n 40
uvx ty check 2>&1 | tail -n 40
shasum -a 256 <each locked path>
```

Use the project's own commands where `CLAUDE.md` names them.
Paste the output as it came, and do not summarise it.
The criteria and the design excerpt come from the design file by copying, and the locked paths come from `.implement/loop.json`.

The hash comparison reads: `unchanged` when every recomputed hash equals the one in the marker, and `CHANGED: <paths>` otherwise.
A changed locked test is a stop for you before the review, so a `CHANGED` line reaches a reviewer only if you are reporting a breach.

## The common brief

```text
Mode: change
This is review round <N>. Return the format in your instructions.

## Task
<the task paragraph for this reviewer>

## Acceptance criteria
<the criteria table from the design, verbatim>

## Design excerpt
<the sections for this reviewer, verbatim>

## Changed files
Tracked files that changed: <paths>
New files, not in git yet: <paths>

## Diff of tracked files
<output of git diff HEAD>

## Test output
<pytest, ruff and ty output as it came>

## Locked tests
Paths: <the protected globs>
Hash check before this round: <unchanged or CHANGED: paths>

Progress reporting: before any other work, call mcp__savvy-progress__step with total (your plan in 3-8 steps) and done: 0 and call it again with done and a few-word note as each step finishes. It only draws a progress bar.
```

The `Mode: change` line is for `implement:test-reviewer` and `implement:architecture-reviewer`, which read it.
Omit it from the brief for `implement:code-reviewer`.

## The pre-lock test review brief

The tests are written and failing, and no implementation exists, so the brief has no diff, no changed-file list and no lock status.
Take the test output from `uv run pytest -q 2>&1 | tail -n 60`, and paste it as it came.

```text
Mode: pre-lock
This is pre-lock test review round <N>. Return the format in your instructions.

## Task
Decide whether these tests prove every acceptance criterion before they are locked. Map each criterion ID to its tests, read the assertions, and report any test that cannot fail, any test that fails for a reason other than missing behaviour, any criterion without a test, and any test that asserts more than its criterion requires. The suite is red because no implementation exists, and that is expected. Read the files yourself.

## Acceptance criteria
<the criteria table from the design, verbatim>

## Design excerpt
<the interfaces the tests call, verbatim>

## Test files
<paths>

## Test output
<pytest output as it came>

Progress reporting: before any other work, call mcp__savvy-progress__step with total (your plan in 3-8 steps) and done: 0 and call it again with done and a few-word note as each step finishes. It only draws a progress bar.
```

## The task paragraph for each reviewer

Use these paragraphs word for word, for the review in Phase 4.

For `implement:test-reviewer`:

```text
Decide whether the tests prove every acceptance criterion. Map each criterion ID to its tests, read the assertions, read the implementation files listed above for special-casing, and report any test that cannot fail or any criterion without a test. Read the files yourself.
```

For `implement:code-reviewer`:

```text
Decide whether the implementation is correct against the acceptance criteria and the design, and whether it is simple and idiomatic Python. Read the changed files and the code around them yourself.
```

For `implement:architecture-reviewer`:

```text
Decide whether the change conforms to the design's structure, dependency direction, boundary checks and pattern decisions, and whether any architecture check was weakened. Read the changed files and the files they import yourself.
```

## What each reviewer receives

| Part | `test-reviewer` | `code-reviewer` | `architecture-reviewer` |
| --- | --- | --- | --- |
| Acceptance criteria | Yes | Yes | Yes |
| Design: structure, boundary checks, pattern decisions | No | Pattern decisions only | Yes, all three |
| Changed files and diff | Yes | Yes | Yes |
| Test output | Yes | Yes | Yes |
| Locked tests and hash check | Yes | No | No |

The pre-lock review gets the criteria, the interfaces and the failing test output only.
The test reviewer gets no design structure because its job is the tests against the criteria, and the extra material invites it to review the architecture instead.

## The rounds log

Append one block per round to `.implement/rounds.md`, and do not rewrite earlier blocks.
The pre-lock rounds use the `Test review round N` heading and are kept apart from the implementation rounds, so the counts per round stay comparable:

```markdown
## Test review round 1

- test-reviewer (pre-lock): BLOCKED, 1 BLOCKING, 0 MINOR

| ID | Reviewer | Severity | Location | Summary | Status |
| --- | --- | --- | --- | --- | --- |
| T1 | test-reviewer | BLOCKING | tests/acceptance/test_cart.py:12 | AC-2 passes before any implementation exists | fixed |

## Round 1

- Tests: 14 passed, 0 failed, 0 skipped
- Lint and types: ruff clean, ty clean
- Locked tests: unchanged
- test-reviewer: BLOCKED, 1 BLOCKING, 2 MINOR
- code-reviewer: CLEAR, 0 BLOCKING, 1 MINOR
- architecture-reviewer: CLEAR, 0 BLOCKING, 0 MINOR

| ID | Reviewer | Severity | Location | Summary | Status |
| --- | --- | --- | --- | --- | --- |
| T1 | test-reviewer | BLOCKING | tests/acceptance/test_cart.py:31 | AC-3 has no assertion on the stored order | fixed |
| C1 | code-reviewer | MINOR | src/pkg/cart.py:58 | Parameter `mode` is never passed | open |
```

The `Status` column holds `fixed`, `open` or `raised to the user`.
The counts per round are the data that no source in the research provides, so keep them accurate.
