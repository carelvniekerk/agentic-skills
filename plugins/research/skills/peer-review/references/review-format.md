# Review format

The template for the review file that `research:peer-review` saves at `<output>/<slug>-review.md`.
The `research:reviewer` agent returns the review in this shape, and the skill writes it to disk.

````markdown
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

**Recommendation:** Accept, Minor Revision, Major Revision or Reject, with the blocking weakness in one sentence.

## Summary

One paragraph on what the paper does and claims, in the reviewer's own words, to show the paper was understood before it is critiqued.

## 🎯 Key Takeaways

- At most five bullets on the most important strengths and weaknesses together.

## Weaknesses

- **[FATAL, W1]** The paper cannot be accepted without addressing this.
  > "The exact passage."

  Why it is fatal, and what would fix it.
- **[MAJOR, W2]** A weakness that substantially weakens the paper.
- **[MINOR, W3]** An issue to fix that does not change the verdict.

## Strengths

- **[S1]** A strength tied to specific evidence in the paper.

## Questions for the authors

1. A question the authors must answer in a rebuttal or revision.

## Inline annotations

> "We achieve state-of-the-art results on all benchmarks"

**[W1] FATAL:** Table 3 shows lower scores on two of the five benchmarks.

## Verdict

One paragraph justifying the recommendation through the specific weaknesses, stating which block acceptance and which do not, and naming what the review could not judge.

## Revision plan

- [ ] **[W1]** The concrete step that resolves it.
- [ ] **[W2]** The concrete step.

## 🔮 Open Questions

- Broader questions the paper raises outside the scope of a revision.

## Sources

- [Paper title or arXiv ID](https://url)
- [Any cited paper consulted during the review](https://url)
````
