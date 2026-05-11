---
name: source-comparison
description: >
  Compare multiple sources, papers, tools, approaches, frameworks, or methods on a topic and produce a grounded comparison matrix that distinguishes agreement, disagreement, and uncertainty clearly.
  Use this skill aggressively whenever the user asks to compare things, evaluate competing approaches, or asks "X vs Y", "how do these differ", or "which is better".
when_to_use: >
  Trigger phrases: "compare", "X vs Y", "how do these differ", "which is better", "evaluate these options",
  "comparison matrix", "compare papers", "compare tools", "compare frameworks", "compare methods",
  "what are the trade-offs", "side by side", "how does X stack up against Y".
argument-hint: <topic or list of things to compare>
allowed-tools: WebSearch WebFetch Read Write Bash(uv run kb-search *) Bash(mkdir *)
disable-model-invocation: false
---

# Source Comparison

Compare multiple sources, papers, tools, or methods and produce a grounded comparison matrix.
Distinguishes agreement, disagreement, and uncertainty clearly — never collapses genuine conflict into a false consensus.

Check `CLAUDE.md` for the project's scratch directory (default: `research_scratch/`) and output directory (default: `output/`).
Read [references/output-format.md](references/output-format.md) for the full output template.

## Workflow

### 1. Check Local Knowledge First

Search the local knowledge base (use `wiki-search` or equivalent if available) for existing coverage on each item being compared.

### 2. Plan

Outline:

- Which sources, tools, papers, or approaches to compare.
- Which **dimensions** to evaluate (performance, method, cost, limitations, maturity, reproducibility, etc.).
- Expected output structure.

Derive a slug.
Write the plan to `<scratch>/.plans/<slug>.md`.

### 3. Gather

Collect evidence on each item being compared.
**Ensure comparable coverage across all items** — do not let one item have many sources and another have one.
If evidence is thin for one item, say so explicitly in the matrix rather than padding with inference.

Write research files to `<scratch>/<slug>-research-*.md`.

### 4. Build the Matrix

Structure the matrix around dimensions, not items.
For each cell, record the evidence and its confidence level.

| Dimension | Item A | Item B | Item C | Confidence |
| --------- | ------ | ------ | ------ | ---------- |
| Method | ... | ... | ... | high |
| Performance | ... | ... | ... | medium |
| Limitations | ... | ... | ... | low |

**Confidence levels:**

- `high` — supported by ≥2 independent primary sources per cell.
- `medium` — supported by 1 primary source or multiple secondary sources.
- `low` — inferred, single tertiary source, or the claim could not be independently verified.

### 5. Surface Agreements, Disagreements, and Gaps

**Agreements** — where sources align across items, with evidence citations.
**Disagreements** — where sources conflict; name which source says what.
**Gaps** — dimensions or items where no reliable evidence was found; state this explicitly rather than guessing.

### 6. Verify and Cite

- Every cell in the matrix must trace to a source citation.
- Use markdown footnote citations `[^N]` inline and `[^N]: [Title](url) — note` in the Sources section.
- **Never use HTML anchors** (`<a id="ref-N">`) or bracketed anchor links (`[[N]](#ref-N)`).
- Verify every source URL resolves.
- Downgrade any cell to `low` confidence if only a single unverified source supports it.

### 7. Deliver

Read [references/output-format.md](references/output-format.md) for the full template and frontmatter spec.
Save to `<output>/<slug>-comparison.md` using the standard article structure, with the comparison matrix as a dedicated section.

Section order for a comparison document:

1. Frontmatter + badge row
2. One-paragraph framing of what is being compared and why
3. 🔗 Prerequisites (if needed)
4. 🎯 Key Takeaways (3–5 bullets on the most important findings)
5. Comparison Matrix
6. Agreements
7. Disagreements
8. Gaps
9. 🔮 Open Questions
10. Sources
