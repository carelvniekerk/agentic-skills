---
name: literature-review
description: >
  Run a structured academic literature review — surveys papers, maps consensus and disagreements, surfaces open questions and trends, and produces a thematically organised review with mandatory results tables and full mathematical notation.
  Use this skill aggressively whenever the user asks for a lit review, paper survey, state of the art, academic landscape summary, related work section, or wants to map a research direction before committing to it.
when_to_use: >
  Trigger phrases: "literature review", "lit review", "survey the field", "state of the art", "what papers exist on",
  "related work", "academic landscape", "map the research", "what has been done on", "survey papers on",
  "what does the literature say", "who has worked on", "prior work on", "review the papers on".
allowed-tools: WebSearch WebFetch Read Write Bash(uv run kb-search *) Bash(mkdir *) Agent
disable-model-invocation: false
---

# Literature Review

Run a structured academic literature review using primary-source paper search and synthesis.
Produces a thematically organised review with consensus, disagreements, trends, and open questions.

Check `CLAUDE.md` for the project's scratch directory (default: `research_scratch/`) and output directory (default: `output/`).
Read [references/output-format.md](references/output-format.md) for the full output template — do this before writing the review.

## Workflow

### 1. Check Local Knowledge First

Search the local knowledge base (use `wiki-search` or equivalent if available) for existing coverage.
Note which papers and concepts are already documented to avoid duplication.

### 2. Plan

Outline the scope:

- Key questions to answer.
- Source types to search (arXiv, Semantic Scholar, Google Scholar, conference proceedings).
- Time period (e.g. "2022–present" for recent methods, "2017–present" for foundational work).
- Expected thematic structure of the output.

Derive a slug.
Write the plan to `<scratch>/.plans/<slug>.md`.

### 3. Gather

Spawn a **`research:researcher`** agent.
Include in its brief:
- The plan from step 2 (questions, sources, time period, expected thematic structure).
- Search strategy: start broad to map the landscape, identify seminal papers, trace citations forward and backward, look for existing survey papers.
- Per-paper extraction: title, authors, year, venue, key contribution, method, and quantitative results.
- Target: **≥10 papers**; fewer than 8 produces an inadequate review.
- Output file: `<scratch>/<slug>-research-papers.md`.

### 4. Synthesise

Spawn a **`research:writer`** agent.
Include in its brief:
- Path to the research file in `<scratch>/`.
- The full contents of [references/output-format.md](references/output-format.md) — the writer must follow this template exactly.
- Draft save path: `<scratch>/.drafts/<slug>-draft.md`.
- Structural requirement: organise around **themes, not chronology**. Each paper receives substantive individual treatment — method, results, significance — not just a citation in passing.
- Required content (all mandatory):
  - Each paper's contribution explained in detail within its thematic section.
  - Quantitative results preserved where reported (accuracy, F1, speedup, etc.).
  - **Results tables are mandatory** wherever 2+ papers report numbers on the same task or benchmark. Format: `Method | Paper | Dataset | Metric | Score`. Note differing experimental conditions in a footnote below the table.
  - Mathematical notation preserved in LaTeX (`$inline$` / `$$display$$`) for any key objective, loss, or algorithm the papers define. Define all variables immediately after each equation.
  - **Consensus** — what do most papers agree on (≥2 sources).
  - **Disagreements** — where do methods or findings conflict; name papers on each side.
  - **Open questions** — what remains unsolved or under-explored.
  - **Trends** — which directions are gaining or losing traction, with dates.
- Length: minimum ~2,500 words; a thorough review of a mature field should be 4,000+.
- Reminder: do NOT add inline citations or fill the Sources section — the verifier handles that.

### 5. Verify and Cite

Spawn a **`research:verifier`** agent.
Include in its brief:
- Draft path: `<scratch>/.drafts/<slug>-draft.md`.
- Research file path (as the authoritative source pool).
- Final output path: `<output>/<slug>.md`.
- Citation format: markdown footnotes `[^N]`.
- Additional rule: every factual paragraph must have at least one citation. Downgrade single-source-critical claims to hedged language rather than asserting them.

### 6. Deliver

The verifier writes the final output directly to `<output>/<slug>.md`.
Write a provenance sidecar to `<scratch>/<slug>.provenance.md`.
Check `CLAUDE.md` for knowledge base integration instructions before promoting output to permanent storage — never do this automatically.
