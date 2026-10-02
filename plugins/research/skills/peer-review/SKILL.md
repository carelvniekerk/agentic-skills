---
name: peer-review
description: >-
  Write a severity-graded peer review (FATAL, MAJOR, MINOR) of a research paper, preprint, draft or research brief, with quoted passages, questions for the authors, a verdict and a revision plan, using the research:reviewer agent.
  Use when the user asks to peer review a paper, says "what would reviewers say", "reviewer 2 this", "pre-submission check" or "would this pass review at NeurIPS", or wants feedback on a paper draft before submission.
when_to_use: >-
  Trigger phrases: "peer review this paper", "review my paper", "what would reviewers say", "pre-submission check", "simulate a reviewer", "reviewer 2 this", "would this pass review", "critique this preprint".
  Code review, pull request review and reviewing a function or diff are not this skill.
argument-hint: <paper path, arXiv ID or URL>
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
---

# Peer review

You produce a tough, fair review of a research artefact and save it at `<output>/<slug>-review.md`, with the slug taken from the artefact's title.
The `research:reviewer` agent writes the review and has no write access, so you save what it returns.

Take the output directory (default `output/`) from the project's `CLAUDE.md`.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, your messages included, and pass its full contents in the reviewer's brief.

The recommendation and the blocking weakness go in your first line to the user, before any strength.
Hold the verdict under pushback: revise it for a new fact or a better argument, never because the author repeats a position, and after three exchanges state the disagreement plainly.
Name what the review could not judge, such as a claim resting on data or code you do not have, instead of grading it as checked.

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Peer review progress:
- [ ] 1. Artefact identified and readable
- [ ] 2. research:reviewer briefed and returned a review
- [ ] 3. Review checked against the format (quotes present, severities honest)
- [ ] 4. Review saved, verdict reported
```

## 1. Identify the artefact

Take it from the arguments or the conversation: a local `.md`, `.tex` or `.pdf` file, an arXiv ID or URL, or text pasted into the conversation.
For a PDF, convert it with the `markitdown:markitdown` skill when it is available.

## 2. Brief the reviewer

Spawn a `research:reviewer` agent with:

- The artefact: a path or URL, or the pasted text in full.
- Permission to search for key cited papers to check claims independently.
- The full contents of `${CLAUDE_SKILL_DIR}/references/review-format.md`, the shape to return.
- The full contents of `house-style.md`.
- These checks, in addition to the reviewer's own list:
  - Substance: novelty, sufficiency of evidence, complete and fair quantitative reporting, honest limitations, negative results.
  - Technical correctness: derivations, experimental protocol, reproducibility of hyperparameters and implementation details.
  - Related work: completeness, fairness and accuracy of positioning.
  - Clarity: contribution stated early, terms defined before use, figures and tables self-contained, abstract accurate.
- The rule to refer to each section, table, figure, method and symbol by the name the paper uses.

## 3. Check the review

Before saving, confirm that every weakness quotes the passage it criticises, that FATAL is used only for what blocks acceptance, and that each strength is tied to evidence.
If the review fails a check, send it back to the reviewer with the failing points rather than editing the verdict yourself.

## 4. Save and report

Write the review to `<output>/<slug>-review.md`.
Report the recommendation and the blocking weakness first, then the path, and then what the review could not judge.

## Gotchas

- `research:reviewer` cannot write files, so a brief that asks it to save the review produces nothing on disk.
- A review that only lists faults is not credible, and one that pads the strengths to soften the verdict is not honest, so both fail step 3.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A weakness without the quoted passage | The authors cannot find or answer it |
| Grading a claim as checked when the data or code was unavailable | False assurance |
| Inventing related work the reviewer did not find | Fabricated citations |
