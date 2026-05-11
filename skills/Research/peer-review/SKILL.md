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
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *)
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

### 2. Gather Context

If the artifact cites external work, search for key cited papers to verify claims independently.
Check the local knowledge base (if available) for related coverage that might inform the review.

### 3. Review Checklist

Evaluate the artifact against all of the following:

**Substance**
- Is the core claim novel and non-trivial?
- Is the evidence sufficient to support the claims?
- Are quantitative results complete, clearly reported, and fairly compared against baselines?
- Are limitations acknowledged honestly?
- Are negative results reported rather than suppressed?

**Technical correctness**
- Are proofs, derivations, and equations correct?
- Are experimental protocols sound (train/test splits, random seeds, significance tests)?
- Are hyperparameters and implementation details reproducible?

**Related work**
- Is prior work cited fairly and completely?
- Is the positioning of this work relative to prior art accurate?

**Clarity**
- Is the contribution stated clearly and early?
- Are all technical terms defined before use?
- Are figures and tables self-contained with complete captions?
- Is the abstract an accurate summary of the paper?

**Presentation**
- Is the paper well-structured and easy to follow?
- Are there inconsistencies in notation or terminology?
- Are there obvious English or formatting issues?

### 4. Deliver

Derive a slug from the paper title.
Save the review to `<output>/<slug>-review.md` using this template:

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
