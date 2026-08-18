---
name: peer-review
description: >
  Simulate a tough but constructive peer review of a research paper, draft, or technical document.
  Produces a structured review with severity-graded feedback (FATAL/MAJOR/MINOR), inline annotations quoting specific passages, and a concrete revision plan.
  Use this skill aggressively whenever the user asks for a review, critique, or feedback on a paper or draft, wants a pre-submission sanity check, or asks "what would reviewers say".
when_to_use: >
  Trigger phrases: "review this paper", "critique this", "peer review", "what would reviewers say",
  "pre-submission check", "what's wrong with this paper", "give me feedback on this draft",
  "review my paper", "sanity check before submission", "simulate a reviewer", "what are the weaknesses",
  "would this pass review", "reviewer 2 this".
argument-hint: <paper-path, arXiv-ID, or URL>
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
disable-model-invocation: false
---

# Peer Review

Simulate a rigorous but constructive peer review of a research artifact.
Produces a structured review with severity-graded feedback and a concrete revision plan.

Check `CLAUDE.md` for the project's output directory (default: `output/`).

## Workflow

### 1. Identify the Artifact

Determine what is being reviewed from `$ARGUMENTS` or the conversation:

- A local file (`.md`, `.tex`, `.pdf`) → read it directly.
- An arXiv ID or URL → fetch and read it.
- Text pasted in the conversation → use that directly.

### 2. Conduct the Review

Spawn a **`research:reviewer`** agent.
Include in its brief:
- The artifact location (file path, arXiv ID, URL, or pasted text from the conversation).
- Permission to search for key cited papers and consult local knowledge if available, to verify claims independently.
- Final output path: `<output>/<slug>-review.md` (derive the slug from the artifact's title).
- Severity grading: FATAL / MAJOR / MINOR — the reviewer agent already enforces these definitions.
- Review checklist to apply (the reviewer agent has its own checklist; these additions complement it):
  - **Substance**: novelty, sufficiency of evidence, complete and fair quantitative reporting, honest limitations, presence of negative results.
  - **Technical correctness**: proofs/derivations/equations, soundness of experimental protocols, reproducibility of hyperparameters and implementation details.
  - **Related work**: completeness and fairness of citations; accuracy of positioning relative to prior art.
  - **Clarity**: contribution stated early; all technical terms defined before use; figures/tables self-contained; abstract accurate.
  - **Presentation**: structure, notation consistency, English and formatting.
- The output template below — the reviewer must wrap its structured-review and inline-annotations output in this template, including the frontmatter and badge row.

Output template:

```markdown
---
tags: [peer-review]
type: notes
date_added: YYYY-MM-DD
date_updated: YYYY-MM-DD
sources: 1
source_type: technical
---

# Review: [Paper Title]

![Type](https://img.shields.io/badge/type-peer--review-red) ![Added](https://img.shields.io/badge/added-YYYY--MM--DD-lightgrey)

## Summary

One paragraph describing what the paper does and what it claims, in the reviewer's own words.
This confirms the reviewer understood the paper before critiquing it.

## 🎯 Key Takeaways

- 3–5 bullets on the most important strengths and weaknesses combined.

## Strengths

- **[S1]** ...
- **[S2]** ...

## Weaknesses

Label each weakness with a severity:

- **[FATAL — W1]** The paper cannot be accepted without addressing this. > "Quote the specific passage." Explanation of why this is fatal.
- **[MAJOR — W2]** Significant weakness that substantially weakens the paper. > "Quote." Explanation.
- **[MINOR — W3]** Small issue that should be fixed but does not affect the verdict. > "Quote." Explanation.

## Questions for the Authors

Numbered questions the authors must answer in a rebuttal or revision:

1. ...
2. ...

## Verdict

**Recommendation:** Accept / Minor Revision / Major Revision / Reject

One paragraph justifying the recommendation in terms of the specific weaknesses found.
Be direct — state which weaknesses are blocking and which are not.

## Revision Plan

Concrete, actionable steps the authors should take to address the weaknesses:

- [ ] **[W1]** What specifically to do to resolve this.
- [ ] **[W2]** What specifically to do.
- [ ] **[W3]** What specifically to do.

## 🔮 Open Questions

- Broader questions the paper raises that are outside the scope of a revision.

## Sources

- [Paper title or arXiv ID](https://url)
- [Any cited papers consulted during review](https://url)
```

## Review Principles

- **Quote specifically.** Every weakness must quote the exact passage being criticised.
Do not paraphrase when the original text can be shown.
- **Be severity-honest.** FATAL means the paper should be rejected as-is — do not use it for minor annoyances.
MINOR means the verdict does not change if unresolved.
- **Separate what is shown from what is claimed.** If a claim exceeds the evidence, say so precisely.
- **Never smooth away genuine uncertainty.** If the reviewer cannot verify a claim, say so.
- **Acknowledge strengths genuinely.** A review that only finds faults is not credible.
