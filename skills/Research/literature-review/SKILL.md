---
name: literature-review
description: >
  Run a structured academic literature review — surveys papers, maps consensus and disagreements, surfaces open questions and trends, and produces a thematically organised review with mandatory results tables and full mathematical notation.
  Use this skill aggressively whenever the user asks for a lit review, paper survey, state of the art, academic landscape summary, related work section, or wants to map a research direction before committing to it.
when_to_use: >
  Trigger phrases: "literature review", "lit review", "survey the field", "state of the art", "what papers exist on",
  "related work", "academic landscape", "map the research", "what has been done on", "survey papers on",
  "what does the literature say", "who has worked on", "prior work on", "review the papers on".
allowed-tools: WebSearch WebFetch Read Write Bash(uv run kb-search *) Bash(mkdir *)
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

Search academic sources systematically:

- Start with broad queries to map the landscape.
- Identify seminal papers, then trace citations forward and backward.
- Look for survey papers that might already summarise the area.
- For each paper, extract: title, authors, year, venue, key contribution, method, and quantitative results.
- Target **≥10 papers**; fewer than 8 produces an inadequate lit review.

Write research files to `<scratch>/<slug>-research-papers.md`.

### 4. Synthesise

Structure the review around **themes**, not chronology.
Each paper must receive substantive individual treatment — its method, results, and significance explained — not just a citation in passing.

**Required structural elements — all mandatory:**

- **Each paper's contribution** explained in detail within its thematic section.
- **Quantitative results** preserved where reported (accuracy, F1, speedup, etc.) — never paraphrase numbers into prose when a table is clearer.
- **Results tables are mandatory** wherever 2+ papers report numbers on the same task, dataset, or benchmark. Reproduce key rows from the papers' own result tables. Format: `Method | Paper | Dataset | Metric | Score`. Note differing experimental conditions in a footnote below the table.
- **Mathematical notation** preserved in LaTeX (`$inline$` / `$$display$$`) for any key objective, loss, or algorithm the papers define.
- **Consensus:** what do most papers agree on? Supported by evidence from ≥2 sources.
- **Disagreements:** where do methods or findings conflict? Name the papers on each side.
- **Open questions:** what remains unsolved or under-explored?
- **Trends:** which directions are gaining or losing traction? With dates.

Minimum body length: ~2,500 words.
A thorough review of a mature field should be 4,000+ words.
Where useful, propose concrete next experiments or follow-up reading.

Save the draft to `<scratch>/.drafts/<slug>-draft.md`.

### 5. Verify and Cite

- Replace all provisional references with **markdown footnote citations** `[^N]`.
- Convert every Sources entry to a footnote definition: `[^N]: [Title — Authors (Year)](https://url) — note`.
- **Never use HTML anchors** (`<a id="ref-N">`) or bracketed anchor links (`[[N]](#ref-N)`) — these break in Obsidian and similar renderers.
- Verify every URL resolves.
- Every factual paragraph must have at least one citation.
- Downgrade anything inferred or single-source-critical to hedged language.

### 6. Deliver

Read [references/output-format.md](references/output-format.md) for the full template and frontmatter field definitions.
Save to `<output>/<slug>.md` following that template.

**Linking rules:**

- Inline citations: `[^N]` — markdown footnote reference.
- Bibliography: `[^N]: [Title — Authors (Year)](https://url) — one-line contribution note` under `## Sources`.
- Links to local knowledge articles: relative paths.
- Links to external sources: full web URLs.
- Never link to scratch files — they are transient.

Write a provenance sidecar to `<scratch>/<slug>.provenance.md`.
Check `CLAUDE.md` for knowledge base integration instructions before promoting output to permanent storage — never do this automatically.
