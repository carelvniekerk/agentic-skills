# Design review brief and log

The fixed brief that `architecture-design` gives `implement:architecture-reviewer` in design mode, and the format of the review log in the design document.

## Contents

- What goes in the brief and what stays out
- The brief
- The review log

## What goes in the brief and what stays out

The reviewer judges the document as a reader who was not in the conversation would.
The brief gives it the document and nothing about how the document was reached.

In the brief:

- The design document, verbatim and whole, including the acceptance criteria.
- The path of the repository, so that the reviewer can read the code the design touches.
- The fixed task paragraph below.
- The reporting line as the last line, because the reviewer only reports steps when its brief asks it to, and the line carries no judgement about the design.

Out of the brief:

- Your summary of the design, and why you chose it.
- Any statement that a decision is settled, correct or intentional.
- Findings from earlier rounds, and the fact that there were earlier rounds beyond the round number.
- The conversation, the user's opinions and the survey agents' reports.

The survey findings that matter are already in the document, under context and evidence limits.
If a claim in the document can only be checked against the survey, the reviewer reports it under `Not judged`, and that is acceptable.
Leave the `Design review` section out of the copy you paste, because an earlier round's findings would otherwise reach the reviewer.

## The brief

Use the task paragraph word for word.

```text
Mode: design
This is design review round <N>. Return the format in your instructions.

## Task
Decide whether this design is complete, testable and justified: dependency direction, boundary checks a tool can run, pattern decisions with a named force, measurable quality targets, and acceptance criteria that a test could check. Read the code the design touches yourself, and say what you could not check.

## Repository
<path>

## Design document
<the design document, verbatim, without its Design review section>

Progress reporting: before any other work, call mcp__savvy-progress__step with total (your plan in 3-8 steps) and done: 0 and call it again with done and a few-word note as each step finishes. It only draws a progress bar.
```

## The review log

Append one block per round to the `Design review` section of the design document, and do not rewrite earlier blocks:

```markdown
### Round 1

- Verdict: BLOCKED, 2 BLOCKING, 1 MINOR

| ID | Severity | Section | Summary | Status |
| --- | --- | --- | --- | --- |
| A1 | BLOCKING | Boundary checks | The `adapters` to `domain` boundary has no import-linter contract | fixed |
| A2 | BLOCKING | Pattern decisions | Factory has no named force | raised to the user |
| A3 | MINOR | Forces | The latency target has no measurement method | open |
```

The `Status` column holds `fixed`, `open` or `raised to the user`.
When the design keeps a decision a finding disputes, the status is `raised to the user` and the reason sits in the summary.
