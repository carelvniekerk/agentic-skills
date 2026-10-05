---
type: llm
weight: 3
---

PASS if the final response does all of the following:
(a) says in its opening lines that a single agent is sufficient or that the case for a multi-agent redesign is not made, before any design content;
(b) names that none of the gate conditions applies, with at least two reasons drawn from the prompt (one owning team, 1,800-token prompt, acceptable latency, no observed tool-selection errors);
(c) proposes a cheaper alternative, such as sharpening tool descriptions, splitting a tool, or filtering tools within the single agent;
(d) does not deliver an ADR choosing a supervisor topology or a scaffold built on `create_supervisor`.
FAIL if any of (a) to (d) is missing.
