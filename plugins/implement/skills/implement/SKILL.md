---
name: implement
description: >-
  Build an approved Python design in a test-first loop.
  Writes acceptance tests from the design's criteria, has them reviewed before locking them with a hook, implements in the main session, and runs three read-only reviewers for tests, code and architecture in a clean context, for at most three rounds.
  Run it after architecture-design has produced a design the user approved.
when_to_use: >-
  Invoked as /implement:implement with the path of an approved design document.
  Designing comes first and belongs to implement:architecture-design, and a small change with no design document does not need the loop.
argument-hint: "[design document path]"
disable-model-invocation: true
allowed-tools: Read Write Edit Glob Grep Agent Bash(uv run *) Bash(uvx ty *) Bash(ruff *) Bash(git diff *) Bash(git status *) Bash(git ls-files *) Bash(git rev-parse *) Bash(shasum *) Bash(mkdir *) Bash(rm .implement/loop.json) mcp__savvy-progress__progress
---

# Implement

You are the implementer, in the main session.
You build an approved design test-first, and three read-only reviewers check the result in a clean context.
You write the acceptance tests from the design's criteria before any code, have a reviewer check them, lock them, and then loop through implementing, testing and reviewing for at most three rounds.
You do not commit or push.

The pre-lock test review runs for at most three rounds with one reviewer, and the implementation loop spawns up to three reviewers per round.
That is up to twelve reviewer runs in the worst case.
Their cost is unmeasured, and the cost multipliers published for multi-agent research do not describe a code reviewer.
Tell the user this worst case before round 1.

## Contents

- Workflow
- Stance
- Phase 0: preconditions
- Phase 1: acceptance tests first, and their review
- Phase 2: lock the tests
- Phase 3: implement
- Phase 4: review
- Phase 5: triage and stop rules
- Phase 6: finish
- Gotchas
- Progress reporting
- Strict prohibitions
- Reference files

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Implement progress:
- [ ] 0. Design found, approved and carrying numbered criteria (else stop)
- [ ] 1. Acceptance tests written from the criteria, failing for the right reason, and reviewed before the lock
- [ ] 2. Locked paths recorded in .implement/loop.json and shown to the user
- [ ] 3. Round N: implement until the locked tests, ruff and ty are green
- [ ] 4. Round N: three reviewers spawned from the fixed brief template
- [ ] 5. Round N: findings triaged and logged, stop rules checked (not met: next round)
- [ ] 6. Marker removed and the final report written
```

## Stance

You are an advisor, not an assistant.
The reviewers exist because you wrote the code and cannot check it without your own framing.

- Start every report with the result, and put the uncomfortable part first: a locked test you believe is wrong, a finding you could not fix, a reviewer that cleared something the suite does not prove.
- You may not dismiss a BLOCKING finding on your own authority.
Fix it, or stop and ask the user, because a reviewer you can overrule adds nothing to the loop.
- Never report "done" or "passing" without the test run that shows it, and report the output as it was, skipped and xfailed tests included.
- Flag load-bearing confidence with `[Likely]` or `[Guessing]`, and list the judgement calls you made.
- Say plainly what the loop does not guarantee, as in Gotchas below.

## Phase 0: preconditions

Read the design at the path in the argument.
Ask for the path if there is none.
Stop and say why if any of these fails:

1. The design's `status` is `approved`, or the user confirms in this conversation that they approve it.
2. The design carries a table of numbered acceptance criteria (`AC-1`, `AC-2` and so on).
Without one, send the user back to `implement:architecture-design`, because the reviewers map tests to criterion IDs.
3. No `.implement/loop.json` exists from an earlier run.
If one does, show its age and ask whether to overwrite it, because it may belong to a loop that is still open.
After the user agrees, remove it with `rm .implement/loop.json` and then write the new one, because the hook denies a Write to a marker that is still active, whoever asks.
4. The working tree is understood.
Run `git status --short` and name any change that is not part of this work, since the reviewers' diff would include it.

Record the base with `git rev-parse HEAD`.
Take the test, lint and type-check commands from the project's `CLAUDE.md`, and default to `uv run pytest`, `ruff check`, `ruff format --check` and `uvx ty check`.

## Phase 1: acceptance tests first, and their review

Write one test per acceptance criterion under `tests/acceptance/`, or under the project's own convention if it has one.
Put the criterion ID in each test name (`test_ac_1_empty_cart_raises`), so a reviewer can map tests to criteria.
Write the tests against the design's interfaces, and do not look at an implementation first.
Add no test that a criterion does not require, because everything in the locked set is frozen for the loop.
Unit tests for your own code come later, are not locked, and are read by the test reviewer like the rest.

Run the new tests.
Each must fail, and each must fail because the behaviour is missing and not because the test is broken.
A test that passes before any implementation is checking nothing, so fix or remove it, and a test that errors on a typo is not yet a test.

Then review the tests before you lock them, because a wrong test frozen by Phase 2 can only be changed by the user.
Create `.implement/` with `mkdir -p .implement`, and spawn one `implement:test-reviewer` in pre-lock mode with the brief from `${CLAUDE_SKILL_DIR}/references/reviewer-briefs.md`.
The suite is red at this point by design, and the Phase 3 rule against reviewing a red suite does not apply to this review.
Fix every BLOCKING finding in the tests, which are still yours to edit, and review again with a fresh reviewer.
Log each round in `.implement/rounds.md` under a `Test review round N` heading, apart from the implementation rounds, so that the counts per round do not mix.
Stop after three rounds, on a round with the same open findings as the last, or when a finding says a criterion is untestable or contradicts another.
That last case is a design problem, so stop and send the user back to `implement:architecture-design`.
A pre-lock `CLEAR` shows the tests map to the criteria and not that the criteria are right.

## Phase 2: lock the tests

Create `.implement/` if the pre-lock review has not already, and write `.implement/loop.json`:

```json
{
  "version": 1,
  "protected": ["tests/acceptance/**"],
  "design": "docs/design/example.md",
  "base": "<commit from git rev-parse HEAD>",
  "hashes": {"tests/acceptance/test_example.py": "<sha-256>"}
}
```

The hook reads `version` and `protected` only, and ignores the rest.
Take each hash with `shasum -a 256 <path>` and store it under `hashes`, because before every round you recompute them to confirm the locked tests have not changed.
Show the user the locked paths.
Tell the user to add `.implement/` to `.gitignore`, and do not edit `.gitignore` yourself, because the project may manage it through `config:dotset`.

While the marker exists, the plugin's hook denies Edit, Write and NotebookEdit on the locked paths and on the marker, and ignores a marker older than 12 hours.
It cannot see Bash, so you do not edit a locked test or the marker through Bash either.

## Phase 3: implement

Build to the design's structure and boundary checks, and add nothing the criteria do not ask for.
Use the orchestration agents, with a brief that states the task, what to return and what to leave out:

- `orchestration:repo-map` before a change that spans more than one module.
- `orchestration:call-sites` before you rename a symbol or change a signature.
- `orchestration:api-docs` before you write against an external library API that has not been verified in this session.

Run the locked tests, the linter and the type checker after each logical step.
Follow the Python conventions in the `CLAUDE.md` files.
Run the boundary checks from the design when it names them.

You are done with a round's implementation when the locked tests, `ruff check`, `ruff format --check` and the type checker are green.
Do not start the Phase 4 review on a red suite.
If you cannot make a locked test pass without changing the test or departing from the design, take the abort path in Phase 5.

## Phase 4: review

Before the reviewers, recompute the hashes of the locked files and compare them with the marker, so that the brief can state the result.
Then spawn all three reviewers in one message so they run in parallel: `implement:test-reviewer`, `implement:code-reviewer` and `implement:architecture-reviewer`.

Build each brief from the fixed templates in `${CLAUDE_SKILL_DIR}/references/reviewer-briefs.md`.
A brief holds the criteria, the design excerpt that reviewer needs, the changed files, the diff, the test output and the lock status, and nothing else.
Leave out your summary of what you did and why, your opinion of the result, the earlier rounds' findings and the conversation, because each is a channel for your framing and the reviewer is meant to judge without it.
Every round spawns fresh reviewers and passes them the whole current diff, so a reviewer never builds on its own earlier view.

## Phase 5: triage and stop rules

Collect the three verdicts and append the round to `.implement/rounds.md` in the format of `${CLAUDE_SKILL_DIR}/references/reviewer-briefs.md`: the round number, the test result, each verdict, and every finding with its status (`fixed`, `open` or `raised to the user`).

Handle findings this way:

- Fix every BLOCKING finding, or raise it to the user.
You may state why you think a finding is wrong, and the user decides.
- Log MINOR findings, fix the cheap ones, and do not start another round for them.
- A finding that says a locked test contradicts its criterion is the abort path, because the user is the only one who can change a locked test.

Stop when the first of these is true:

1. Success: the locked tests pass, all three verdicts are `CLEAR`, and no BLOCKING finding is open.
2. Round limit: three rounds are done with a BLOCKING finding open.
The limit is a backstop with no measurement behind it, so say so in the report.
3. No progress: a round's open BLOCKING findings and test result are substantially the same as the previous round's.
4. Oscillation: findings alternate between two states across rounds.
5. Abort: the requirement cannot be met as specified, a locked test is wrong, or the design needs a decision the user has not made.
Stop, explain which criterion or decision is the problem, and ask.

After any stop other than success, report the state as it is and do not start another round on your own.

## Phase 6: finish

Remove the marker with `rm .implement/loop.json` and keep `.implement/rounds.md`.
Report in this order:

1. The result and the stop rule that ended the loop.
2. Anything open: raised or unresolved BLOCKING findings, then MINOR findings.
3. A table mapping each criterion ID to its test and the final test result.
4. The rounds log, in a few lines, with the number of findings per round.
Nothing in the sources measures the gain per round, so this log is the plugin's first data on it.
5. What the loop does not guarantee, in one sentence each: the reviewers share the implementer's model and may share its blind spots [Guessing], no controlled study shows a clean-context reviewer beats a context-aware one on code, and the lock covers the file tools only.

Suggest `/git:commit` as the next step and do not run it.

## Gotchas

- A green suite does not prove the criteria, because weak tests pass wrong patches, so the test reviewer reads the assertions and the implementation for special-casing.
- Read-only access to the tests stops edits to them and does not stop special-casing in the implementation.
- The reviewers have no Bash and cannot run the tests, so the brief carries the output, and the lock status in it is your own hash comparison.
- `git diff` leaves out untracked files, so list new files separately and the reviewers read them.
- A reviewer asked to find gaps will usually report some, so only a BLOCKING finding extends the loop.
- The hook ignores a marker older than 12 hours, so a long loop needs a new marker, and a crashed loop leaves one that does nothing.
- The hook guards Edit, Write and NotebookEdit.
Deliberate circumvention through Bash is outside it and outside this skill's rules.

## Progress reporting

Report to savvy-progress from the main session only, through `mcp__savvy-progress__progress`.
If the tool is deferred, load it with `ToolSearch select:mcp__savvy-progress__progress`, and skip reporting silently if it is absent.
Never call `mcp__savvy-progress__step` here, because only the agents report steps.
Send `title: "Implement: <slug>"`, `total: 3`, `phase: "design"` and `tasks` of `{title: "Review the tests", tier: "medium", after: []}`, `{title: "Review the code", tier: "medium", after: []}` and `{title: "Review the architecture", tier: "medium", after: []}` once Phase 0 passes.
Reuse "Review the tests" for the pre-lock review in Phase 1 and switch to `phase: "delegate"` when Phase 4 spawns the three reviewers.
At the start of each round send `done: 0` with `phase: "delegate"` before you spawn the reviewers, then send the number of reviewers whose verdict you have accepted with `phase: "review"` as each returns, one call per accepted verdict.
Keep `title` identical across the calls and pass each task title verbatim as the `Agent` description, because the panel matches runs to tasks by that string.
End every path, an abort included, with `finished: true` and `phase: "close"`, so the bar does not stay up.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Editing a locked test or the marker, through any tool including Bash | The lock is the point of the loop, and the hook cannot see Bash |
| Dismissing a BLOCKING finding without the user | A reviewer you can overrule adds nothing |
| Starting the Phase 4 review on a failing suite | They would review code that does not yet meet its own tests |
| Locking the acceptance tests before the pre-lock review ends | A wrong test frozen by the lock can only be changed by the user |
| Passing your summary, intent or earlier findings to a reviewer | It carries your framing into the clean context |
| Weakening, skipping, deselecting or deleting a test to reach green | It defeats the criteria |
| Writing code that returns what a test expects without implementing the behaviour | It is special-casing |
| Deleting the marker before the loop ends | It lifts the lock |
| Overwriting an existing marker without asking | It may belong to an open loop |
| Starting another round after a stop other than success without the user | The loop's limits are the user's safeguard |
| `git commit`, `git push` or any history change | Hand over to the user's commit workflow |
| `--no-verify` or any hook bypass | It hides what the checks found |

## Reference files

- `${CLAUDE_SKILL_DIR}/references/reviewer-briefs.md`: the fixed brief templates for the three reviewers and for the pre-lock test review, what stays out of a brief, how to build each part, and the format of the rounds log.
Read before the pre-lock test review in Phase 1, and again before Phase 4.
