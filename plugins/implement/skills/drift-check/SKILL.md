---
name: drift-check
description: >-
  Check whether implemented design documents still match the code: a script runs the mechanical checks (missing paths and identifiers, acceptance criteria without a test, boundary contracts), then a read-only reviewer in a clean context judges only the designs the script flags or whose referenced files changed.
  Use when the user asks whether their design docs are still accurate, up to date or stale, whether the code has drifted from a design, or runs /implement:drift-check after a SessionStart message says a check is due, even if they do not say "drift".
  Reports differences only and edits nothing.
when_to_use: >-
  Trigger phrases: "check my designs for drift", "are my design docs still accurate", "has the code drifted from the design", "which design docs are stale".
  Reviewing a new design belongs to implement:architecture-design, and reviewing a diff or a change is not this skill.
argument-hint: "[scan-only <base branch>]"
allowed-tools: Read Grep Glob Write Agent Bash(uv run *) Bash(git diff *) mcp__savvy-progress__progress
effort: high
---

# Drift check

You find where implemented designs and the code now disagree, and you report the differences.
You never edit a design or a source file, because only the user knows whether the document or the code is wrong.

Only a design with `status: implemented` is checked.
`implement:implement` sets that status when its loop ends.
A design that is only `approved` is skipped and the report says why, so mark an older, already built design by hand with `status: implemented` and a `tests:` list of its acceptance test files if you want it checked.

## Scan only

With the argument `scan-only <base>`, as `git:pr` passes it, run Phase 2 and nothing else first.
Skip the `ignore` command, because nothing is written.
Keep the designs that have findings, or whose `referenced_files` appear in `git diff --name-only <base>...HEAD`, and show the scanner summary for those only.
Name the designs that were left out because nothing they reference changed on the branch.
Stop there when nothing is flagged, with one line saying so.
When a design is flagged, ask the user whether to continue with Phases 3 to 6 for it, and do not spawn a reviewer before a yes.
Never run Phase 7 in this mode, because the pass is not complete and the branch is not merged.

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Drift check progress:
- [ ] 1. Worst-case reviewer count stated, and .implement/ kept out of git
- [ ] 2. drift-scan.py run and its output shown
- [ ] 3. Designs to review chosen (findings, or references changed since the last pass)
- [ ] 4. Symbol lookups for MISSING identifiers done through the orchestration agents
- [ ] 5. One implement:drift-reviewer per chosen design, in parallel
- [ ] 6. Report written, differences only
- [ ] 7. Pass recorded with drift-scan.py record
```

## Stance

You are an advisor, not an assistant.
Start the report with the drift that matters most, and say plainly when a design is clean.
Tag a load-bearing inference with `[Likely]` or `[Guessing]`.
List the judgement calls you made, and surface anything odd: a scanner finding that looks like a false positive, a skipped design, a tool that did not run.

## Phase 1: cost and setup

The scanner is free.
Each `implement:drift-reviewer` is one Sonnet run at high effort, and nobody has measured its cost yet [Guessing].
The worst case is one reviewer per implemented design.
State that number to the user before you spawn any, and ask first when it is more than five.

Run `uv run --script ${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift-scan.py ignore` before you write anything under `.implement/`.
It adds `.implement/` to `.git/info/exclude` unless a gitignore already covers it, so the report and the state file stay out of the repository.
Do not edit `.gitignore`, because the project may manage it through `config:dotset`.
Tell the user which of the two happened.

## Phase 2: scan

```bash
uv run --script ${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift-scan.py scan
```

Pass a design path or directory to scan less.
The design directory comes from the project's `CLAUDE.md` and defaults to `docs/design/`.
Show the stderr summary to the user.
The JSON on stdout holds each design's findings, its referenced files, its digest and `changed_since_last_pass`.

Exit code 0 means clean, 1 means findings, and 2 means an error that is not a finding, so stop and report the error.
A `NOT RUN` entry means a boundary tool was absent.
Report it and do not install anything.
A `state_error` means the state file is unreadable, so every design counts as changed.

## Phase 3: choose designs

Review a design when it has findings or when `changed_since_last_pass` is true.
A design with neither gets one line in the report.
Skipped designs get one line with the scanner's reason.

## Phase 4: lookups

For each `MISSING` identifier, spawn `orchestration:call-sites` or `orchestration:repo-map` with a brief that states the task, what to return and what to leave out, as in `orchestration:delegate`.
Ask where the identifier moved or what replaced it, and for paths and line numbers only.
Treat the answer as a lead and read the file yourself before you put it in a reviewer brief.
Start independent lookups in the same message.

## Phase 5: review

Spawn one `implement:drift-reviewer` per chosen design, all in one message so they run in parallel.
Use the brief in `${CLAUDE_SKILL_DIR}/references/reviewer-brief.md`.
It holds the design document verbatim, the scanner's entry and findings for that design and the referenced file paths.
Leave out why the code changed, your summary and your opinion, because the reviewer is meant to judge as a fresh reader.
Do not pass an `effort` override, because the agent definition sets `effort: high`.

A reviewer cannot ask you anything, so a `BLOCKED` verdict for a missing brief part means you fix the brief and spawn a new one.
A `BLOCKED` verdict for BLOCKING findings is a result, so report it.

## Phase 6: report

Write `.implement/drift-report-YYYY-MM-DD.md` with today's date.
Ask before you overwrite an existing file of that name.
Report differences only, in this order:

1. The worst drift first, as `design path, finding, design says X, code does Y, where`.
2. Scanner findings no reviewer confirmed, marked as unconfirmed.
3. Designs that were clean, one line each, and designs that were skipped, one line each.
4. What was not judged, including every `NOT RUN` tool.

Tell the user the path and the verdict counts, and do not repeat the report in chat.

## Phase 7: record the pass

Run `uv run --script ${CLAUDE_PLUGIN_ROOT}/skills/drift-check/scripts/drift-scan.py record` once the report is written.
It stores the digests of the referenced files and the time, so the SessionStart hook proposes the next check only when a referenced file changes and at least seven days have passed.
The hook also stays quiet for 24 hours after each proposal, using `.implement/drift-gate.json`, which it writes itself and which holds nothing but that time.
Recording marks the pass as done and not the drift as resolved, so say that in one line.

## Gotchas

- The scanner reads `tests:` in the design frontmatter to map criteria to tests, and reports the mapping as skipped when the list is missing.
- The identifier check looks only at `name()` calls and CamelCase names in backticks outside code fences, so a renamed function the design mentions without parentheses goes unreported.
- A missing path is not reported when it points into a sibling directory of the repository, when it is a data file (json, csv, yaml, txt, sql, ttl), or when it looks like an example (`a/x.ext`), because these are runtime output, other repositories and illustrations more often than drift.
A path that drops a leading package (`pkg/ports.py` for `src/pkg/ports.py`) still matches.
- The digest covers the files named by path in the design and the files in `tests:`, and not every file that mentions an identifier.
- The reviewers share the implementer's model and may share its blind spots [Guessing], and a `CLEAR` verdict does not show the design is right.
- The scanner's boundary check runs the project's own tool and reports its output verbatim, so a failure there can come from the code and not from drift.

## Progress reporting

Report to savvy-progress from the main session only, through `mcp__savvy-progress__progress`.
If the tool is deferred, load it with `ToolSearch select:mcp__savvy-progress__progress`, and skip reporting silently if it is absent.
Never call `mcp__savvy-progress__step` here, because only the agents report steps.
Send `title: "Drift check"`, `total` equal to the number of reviewers, `phase: "delegate"` and one task `{title: "Review drift", tier: "medium", after: []}` per reviewer once Phase 3 has chosen the designs.
Send `done` as each verdict is accepted, and close the flow with `finished: true` and `phase: "close"` under the same title.
Send nothing when no reviewer is needed.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Editing a design or a source file | The user decides whether the document or the code is wrong |
| Writing the report or the state file anywhere but `.implement/` | The user keeps tool state out of the repository |
| Editing `.gitignore` | The project may manage it through `config:dotset` |
| Installing a boundary tool to make it run | Installing changes the project's dependencies |
| Passing your summary, intent or the reason for a change to the reviewer | It carries your framing into the clean context |
| Recording a pass before the report is written | The hook would stop proposing a check for work that was never done |
| Committing or pushing | The user asks for that through `/git:commit` |
