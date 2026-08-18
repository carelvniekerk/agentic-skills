# Output Format — Research Brief

Full template and frontmatter specification for deep-research output documents.
Use this when writing the final brief in step 7 of the deep-research workflow.

---

## Frontmatter Fields

```yaml
---
tags: [tag1, tag2, tag3]          # lowercase, hyphenated; 3–6 tags
type: notes                        # or paper-summary, concept, discussion, etc.
date_added: YYYY-MM-DD
date_updated: YYYY-MM-DD
sources: <integer>                 # count of source documents
source_type: technical             # technical | discussion | experiment | meeting
---
```

---

## Full Document Template

```markdown
---
tags: [tag1, tag2]
type: notes
date_added: YYYY-MM-DD
date_updated: YYYY-MM-DD
sources: <N>
source_type: technical
---

# Research Brief: [Topic]

![Type](https://img.shields.io/badge/type-research--brief-blue) ![Added](https://img.shields.io/badge/added-YYYY--MM--DD-lightgrey)

One or two paragraphs introducing the topic, its significance, and how this brief is organised.

## 🔗 Prerequisites

- [Related article or resource](./relative/path-or-url.md) — what concept is needed and why

## 🎯 Key Takeaways

- 5–8 bullet points capturing the most important findings.
Each should be substantive and self-contained — a reader skimming takeaways gets the core message.
Include quantitative results where available.

## [Section 1: Themed Heading]

Detailed exposition — multiple paragraphs per section.
Every factual claim carries a footnote citation [^N].
Explain methods, not just names.
Include numbers.
Surface disagreements between sources.

## [Section 2: Themed Heading]

...

## [Results / Comparison Table]

Reproduce numeric results from the papers' own tables.
Do not paraphrase numbers into prose when a table is clearer.

| Method | Paper | Dataset | Metric | Score |
| ------ | ----- | ------- | ------ | ----- |
| Method A | [^1] | Benchmark X | Accuracy | 84.2 |
| Method B | [^2] | Benchmark X | Accuracy | 87.1 |
| Baseline | [^3] | Benchmark X | Accuracy | 79.0 |

*Note: [^1] reports on test split; [^2] reports on validation split — direct comparison is approximate.*

## 🔮 Open Questions

- Unresolved questions from the sources themselves.
- Gaps revealed by cross-referencing multiple sources.
- Speculative "what if?" extensions and imaginative research directions.

## Related Articles

- [Related article](./relative/path.md)

## Sources

[^1]: [Title — Authors (Year)](https://url) — one sentence on what this source contributes to this brief
[^2]: [Title — Authors (Year)](https://url) — one sentence on what this source contributes to this brief
```

---

## Badge Reference

**Mandatory badge row** (immediately after the title paragraph):

For a research brief:
```markdown
![Type](https://img.shields.io/badge/type-research--brief-blue) ![Added](https://img.shields.io/badge/added-YYYY--MM--DD-lightgrey)
```

For an arXiv paper summary (add the arXiv badge first):
```markdown
[![arXiv](https://img.shields.io/badge/arXiv-XXXX.XXXXX-b31b1b?logo=arxiv)](https://arxiv.org/abs/XXXX.XXXXX) ![Type](https://img.shields.io/badge/type-paper--summary-orange) ![Added](https://img.shields.io/badge/added-YYYY--MM--DD-lightgrey)
```

**Contextual badges** (add in the section where they apply, not all in the header):

| Category | When to add | Example |
| -------- | ----------- | ------- |
| Hardware target | Paper reports results on specific hardware | `![A100](https://img.shields.io/badge/A100-73%25_peak-blue)` |
| Model adoption | Technique used in named production models | `![Llama](https://img.shields.io/badge/Llama-Meta-blue)` |
| Algorithm comparison | Article directly compares two or more algorithms | `![PPO](https://img.shields.io/badge/PPO-critic_required-red)` |
| Version constraint | Tool/library has a known good/bad version range | `![Use](https://img.shields.io/badge/use-v0.16_or_≥v0.19-brightgreen)` |
| Scale | Paper evaluates at specific model sizes | `![Scale](https://img.shields.io/badge/models-7B--70B-yellow)` |
| Pipeline stages | Multi-stage recipe where order matters | `![Stage 1](https://img.shields.io/badge/①-SFT-lightgrey) → ![Stage 2](https://img.shields.io/badge/②-DPO-orange)` |

---

## Citation Rules

- **Inline:** `[^N]` — markdown footnote reference. Renders as a superscript link in Obsidian with round-trip navigation.
- **Bibliography:** `[^N]: [Title — Authors (Year)](https://url) — one-line contribution note` — one per line under `## Sources`.
- **Never use** `<a id="ref-N">` (HTML anchor — Obsidian ignores it) or `[[N]](#ref-N)` (parsed as a wikilink, creates a phantom file named `N`).

---

## Section Emoji Conventions

| Section | Emoji |
| ------- | ----- |
| Prerequisites | 🔗 |
| Key Takeaways | 🎯 |
| Open Questions | 🔮 |
