# Design document template

The structure of the document that `architecture-design` writes and `implement:implement` reads.
Fill in the sections that apply, delete the ones that do not, and keep each sentence on its own line in the source.
A section that has nothing to say is deleted and not filled with a placeholder.

## Contents

- Frontmatter
- Sections
- Acceptance criteria format
- What the implement skill reads

## Frontmatter

```yaml
---
title: <what is being designed>
status: draft
date: YYYY-MM-DD
approved-by: ""
---
```

`status` is `draft` until the user approves it, and then `approved`.
The implement skill refuses a design whose status is `draft` unless the user confirms in the conversation that they approve it.

## Sections

1. Context and goal.
What the system must do and why, in a short paragraph, with the constraints and the non-goals.
2. Forces.
The conflicts the design resolves, each with the quality attribute it affects and a measurable target.
3. Structure.
The packages and the layer each belongs to, the direction of every dependency, the ports and the composition root.
Add a diagram only where it shows something the prose does not, and use C4 level names if it does.
4. Boundary checks.
The import-linter contracts or equivalent checks that keep the structure, written so that a tool can run them.
5. Pattern decisions.
A table with one row per candidate: the pattern, the named force, the Python idiom considered, the decision (used, idiom instead, rejected) and the evidence tag of the row in the pattern guide.
State when no pattern is used.
6. Decisions and rejected alternatives.
One entry per significant decision, in the ADR shape: context, decision, consequences and the alternatives considered.
Record a disagreement the user and the design did not resolve.
7. Acceptance criteria.
The table below.
8. Unverified requirements.
Requirements that no test can check, such as a qualitative goal or a target that needs measurement, each with how it could be checked later.
9. Risks and open questions.
What could invalidate the design, and what the user still has to decide.
10. Evidence limits.
Which recommendations rest on a thin or single-source row of the guides, and which codebase facts the survey could not confirm.
11. Design review.
One block per review round, added by Phase 6 of the skill, in the format of `design-review-brief.md`.
Delete the section if no review ran, and say why under evidence limits.

## Acceptance criteria format

| ID | Given | When | Then | Test level |
| --- | --- | --- | --- | --- |
| AC-1 | An empty cart | The user checks out | The call raises `EmptyCartError` and no order is stored | Unit |
| AC-2 | A stored order | The order is loaded through the repository port | The loaded order equals the stored one | Integration |

Each criterion is one observable behaviour, written so that a failing test would show it broken.
Number the IDs in order and never reuse one, because the reviewers map tests to IDs.
State the test level (unit, integration or end to end) because it decides where the test lives.
Leave implementation detail out, so the criterion survives a change of structure.

## What the implement skill reads

The implement skill reads the acceptance criteria, the structure, the boundary checks, the pattern decisions and the unverified requirements.
It writes its acceptance tests from the criteria, builds to the structure, and gives the three reviewers the design excerpt that each needs.
A design without numbered criteria cannot be built through that loop, so the skill stops and asks for them.
