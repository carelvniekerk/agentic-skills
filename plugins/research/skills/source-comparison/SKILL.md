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
allowed-tools: WebSearch WebFetch Read Write Bash(uv run kb-search *) Bash(mkdir *) Agent
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

Spawn a **`research:researcher`** agent.
Include in its brief:
- The plan from step 2 (items to compare, dimensions to evaluate).
- Requirement: **comparable coverage across all items** — do not let one item have many sources and another have one. If evidence is thin for one item, document that explicitly rather than padding with inference.
- Output file naming: `<scratch>/<slug>-research-<item>.md` (one file per item).
- Reminder: every claim must have a URL; no fabricated sources.

### 4. Build the Comparison

Spawn a **`research:writer`** agent.
Include in its brief:
- Paths to all research files in `<scratch>/`.
- The full contents of [references/output-format.md](references/output-format.md) — the writer must follow this template.
- Draft save path: `<scratch>/.drafts/<slug>-comparison-draft.md`.
- The matrix structure: dimensions on rows, items on columns, one confidence column per cell. Confidence levels:
  - `high` — supported by ≥2 independent primary sources per cell.
  - `medium` — supported by 1 primary source or multiple secondary sources.
  - `low` — inferred, single tertiary source, or the claim could not be independently verified.
- Section order: framing paragraph → 🔗 Prerequisites (if needed) → 🎯 Key Takeaways (3–5 bullets) → Comparison Matrix → Agreements → Disagreements → Gaps → 🔮 Open Questions → Sources placeholder.
- Required content per section:
  - **Agreements**: where sources align across items, with which sources support each.
  - **Disagreements**: where sources conflict; name which source says what.
  - **Gaps**: dimensions or items with no reliable evidence — stated explicitly, not guessed.
- Reminder: do NOT add inline citations or fill the Sources section — the verifier handles that.

### 5. Verify and Cite

Spawn a **`research:verifier`** agent.
Include in its brief:
- Draft path: `<scratch>/.drafts/<slug>-comparison-draft.md`.
- All research file paths (as the authoritative source pool).
- Final output path: `<output>/<slug>-comparison.md`.
- Citation format: markdown footnotes `[^N]`.
- Additional rule: **every cell in the matrix must trace to a source citation**. If any cell rests on a single unverified source, downgrade its confidence label to `low`.
