---
name: deep-research
description: >
  Run a thorough, source-heavy investigation on any topic and produce a comprehensive, self-contained cited research brief with provenance tracking.
  Use this skill aggressively whenever the user asks for "deep research", a comprehensive analysis, a multi-source investigation, or wants a durable citable artifact rather than a conversational answer.
  Also use it when a topic requires 5+ sources and cross-referencing to answer properly.
when_to_use: >
  Trigger phrases: "deep research", "research this thoroughly", "comprehensive analysis", "multi-source investigation",
  "research brief", "deep dive", "investigate", "what does the literature say about",
  "I want a full picture of", "research and write up", "give me everything on".
allowed-tools: WebSearch WebFetch Read Write Bash(uv run kb-search *) Bash(mkdir *)
disable-model-invocation: false
---

# Deep Research

Run a thorough, source-heavy investigation on any topic.
Produces a comprehensive, self-contained cited research brief with provenance tracking.

Check `CLAUDE.md` for the project's scratch directory (default: `research_scratch/`) and output directory (default: `output/`).
Read [references/output-format.md](references/output-format.md) for the full output template and frontmatter spec — do this before writing the brief.

## Workflow

### 1. Check Local Knowledge First

Search the local knowledge base (use `wiki-search` or equivalent skill if available) for existing coverage.
Note what is already known and what gaps need filling.
If no local knowledge skill is configured, proceed to step 2.

### 2. Plan

Analyse the research question and develop a research strategy:

- Key questions that must be answered.
- Evidence types needed (papers, web, repos, docs).
- Source types and time periods that matter.
- Acceptance criteria: what evidence would make the answer "sufficient".

Derive a short slug from the topic (lowercase, hyphens, no filler words, ≤5 words).
Write the plan to `<scratch>/.plans/<slug>.md`.
Present the plan to the user, then continue automatically.

### 3. Gather Evidence

- For narrow questions: search directly, 8–15 tool calls minimum.
- For broad surveys: break into 3–6 disjoint research dimensions; search each dimension separately.
- Target **≥12 sources** for a deep research brief; fewer than 8 is insufficient.
- Write research files to `<scratch>/<slug>-research-*.md`.

### 4. Evaluate and Loop

After gathering, critically assess:

- Which plan questions remain unanswered?
- Which answers rest on only one source?
- Are there contradictions needing resolution?
- Is any key angle missing entirely?

If gaps are significant, gather more evidence.
Most topics need 1–2 rounds.
Stop when additional rounds would not materially change conclusions.

### 5. Write the Brief

Synthesise findings into a **comprehensive, self-contained reference document** — not a summary.
A reader must be able to fully understand the topic from the output alone, without consulting any source directly.

**Depth requirements — all mandatory:**

- **Minimum ~2,500 words of body content** (excluding frontmatter, badges, and sources). Longer is better; complex topics may warrant 5,000+ words.
- **Every major source gets its own named subsection or dedicated paragraph** describing its specific contribution, method, and key results — not just a citation in passing.
- **Quantitative results must be included** where sources report them (accuracy, speedups, benchmark scores, effect sizes).
- **Methodology must be explained**, not just named. If a paper proposes a method, describe how it works.
- **Agreements and disagreements between sources** must be surfaced explicitly — do not present a monolithic narrative if sources conflict.
- **Results tables are mandatory** where 2+ sources report numbers on the same task, dataset, or benchmark. Reproduce key rows from the papers' own tables. Format: `Method | Dataset | Metric | Score | Source`. Note differing conditions in a footnote below the table.
- **Mathematics must be reproduced in full**, not summarised. Write loss functions, objectives, and key equations in LaTeX (`$inline$` / `$$display$$`). State theorems and proof sketches. Never replace equations with verbal descriptions. Define all variables immediately after each equation.

Save the draft to `<scratch>/.drafts/<slug>-draft.md`.

### 6. Verify and Cite

- Add **markdown footnote citations** `[^N]` after each factual claim.
- In the Sources section, use footnote-definition syntax: `[^N]: [Title](url) — note`.
- **Never use HTML anchors** (`<a id="ref-N">`) or bracketed anchor links (`[[N]](#ref-N)`) — these break in Obsidian and similar renderers.
- Verify every source URL resolves.
- Remove or soften unsourced claims.
- Every paragraph of substance needs at least one citation; long paragraphs with multiple claims need multiple citations.

### 7. Deliver

Read [references/output-format.md](references/output-format.md) for the full template and frontmatter field definitions.
Save the final output to `<output>/<slug>.md` following that template.

**Linking rules:**

- Inline citations: `[^N]` — markdown footnote reference.
- Bibliography entries: `[^N]: [Title — Authors (Year)](https://url) — one-line contribution note` under a `## Sources` heading.
- Links to local knowledge articles: relative paths (e.g. `../wiki/article.md`).
- Links to external sources: full web URLs.
- Never link to scratch files — they are transient.

Write a provenance sidecar to `<scratch>/<slug>.provenance.md`:

```markdown
# Provenance: [topic]

- **Date:** [date]
- **Rounds:** [number of evidence-gathering rounds]
- **Sources consulted:** [total unique sources]
- **Sources accepted:** [sources that survived verification]
- **Sources rejected:** [dead links, unverifiable, or removed]
- **Local knowledge coverage before:** [what was already known]
- **Plan:** <scratch>/.plans/<slug>.md
- **Research files:** [list of intermediate files]
```

### 8. Optional Knowledge Base Integration

If findings are substantial and durable enough for permanent storage, check `CLAUDE.md` for the project's knowledge base integration instructions.
Do **not** integrate automatically — only when the user asks or the content clearly warrants it.
