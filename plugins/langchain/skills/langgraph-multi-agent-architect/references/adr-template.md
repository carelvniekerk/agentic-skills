# ADR template

The structure for the architecture decision record.
It stays close to a conventional ADR so it can be committed with the code and read by people who were not in the conversation.
The section list is fixed, and a section with nothing to say states "none" and why.

## Contents

- Template
- Notes per section

## Template

```markdown
# ADR-NNN: <system name> multi-agent architecture

## Status
Proposed | Accepted | Superseded by ADR-NNN

## Context
The workload in two or three sentences.
The binding constraint from Phase 0, named explicitly.
The request mix.
Any latency, cost, residency or audit target, with numbers.

## Decision
<Pattern>, because <the ladder rule that fired>.

## Rejected alternatives
For each pattern seriously considered, one line on what it would have cost or broken.
Include "single agent with better tools" every time.

## Cost model
A table of calls per turn and tokens per turn for the chosen pattern and the runner-up, across the request mix.
Show the arithmetic, state the assumptions, and mark each number measured or estimated.

## Architecture
A Mermaid diagram with nodes, edges and where state is written.
Mark every boundary where context is filtered or dropped.

## State schema
The typed state, with a note on which keys are shared between agents and which are private.
Name the reducer for any key written by more than one node.

## Failure modes and controls
A table of failure mode, detection signal and control.
Cover at least: routing loops, malformed message history at handoff or composition boundaries, a subagent returning work that is absent from its final message, partial failure during parallel fan-out, and unbounded recursion.

## Observability and evaluation
What is traced, what is asserted in CI, and what the regression suite covers.
State the routing-accuracy target and how it is measured.

## Compliance notes
Only where applicable.
Read `eu-compliance.md` before writing this section.

## Consequences
What becomes easy, what becomes hard, and what must be revisited, and on what trigger.
```

## Notes per section

- **Context and Decision** are prose. The Decision sentence names the ladder rule that fired, because a reviewer can then challenge the rule or the input.
- **Cost model** shows inputs separately from conclusions, so a reviewer can disagree with an input. Do not quote three significant figures from estimated inputs.
- **Rejected alternatives** records any disagreement the user kept after three exchanges.
- **Failure modes** are specific to the chosen pattern, and a generic list is a sign the section was not thought through.
