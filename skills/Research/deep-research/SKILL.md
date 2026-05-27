---
name: deep-research
description: >
  Run a thorough, source-heavy investigation on any topic and produce a comprehensive, self-contained cited research brief with provenance tracking.
  Use this skill aggressively whenever the user asks for "deep research", a comprehensive analysis, a multi-source investigation, or wants a durable citable artifact rather than a conversational answer.
  Also use it when a topic requires 5+ sources and cross-referencing to answer properly.
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

Spawn a **`researcher`** agent.
Include in its brief:
- The full research plan from step 2 (all questions, dimensions, acceptance criteria).
- Instruction to target **≥12 sources**; fewer than 8 is insufficient.
- For broad surveys: cover each research dimension in a separate output file.
- Output file naming: `<scratch>/<slug>-research-<dimension>.md`.
- Reminder: every claim must have a URL; no fabricated sources.

### 4. Evaluate and Loop

Read the research files the researcher produced.
Critically assess:

- Which plan questions remain unanswered?
- Which answers rest on only one source?
- Are there contradictions needing resolution?
- Is any key angle missing entirely?

If gaps are significant, spawn a second `researcher` agent targeting the gaps specifically.
Most topics need 1–2 rounds.
Stop when additional rounds would not materially change conclusions.

### 5. Write the Brief

Spawn a **`writer`** agent.
Include in its brief:
- Paths to all research files in `<scratch>/`.
- The full contents of [references/output-format.md](references/output-format.md) — the writer must follow this template exactly (frontmatter, badge row, Prerequisites, Key Takeaways, section headings, Open Questions, Related Articles, Sources placeholder).
- The draft save path: `<scratch>/.drafts/<slug>-draft.md`.
- These depth requirements (all mandatory):
  - Minimum ~2,500 words of body content (excluding frontmatter, badges, sources); complex topics may warrant 5,000+.
  - Every major source gets its own named subsection or dedicated paragraph with specific contribution, method, and key results — not just a citation in passing.
  - Quantitative results must be included where sources report them.
  - Methodology must be explained, not just named.
  - Agreements and disagreements between sources must be surfaced explicitly.
  - Results tables are mandatory where 2+ sources report numbers on the same task or benchmark. Format: `Method | Dataset | Metric | Score | Source`.
  - Mathematics must be reproduced in full using LaTeX (`$inline$` / `$$display$$`). Never replace equations with verbal descriptions. Define all variables immediately after each equation.
- Reminder: do NOT add inline citations or a Sources section — the verifier handles that.

### 6. Verify and Cite

Spawn a **`verifier`** agent.
Include in its brief:
- Draft path: `<scratch>/.drafts/<slug>-draft.md`.
- All research file paths in `<scratch>/` (as the authoritative source pool).
- Final output path: `<output>/<slug>.md`.
- Citation format: markdown footnotes `[^N]` — the output file is `.md`.
- Obsidian constraint: **never** use HTML anchors (`<a id="ref-N">`) or `[[N]](#ref-N)` — these break rendering. Use only `[^N]` inline and `[^N]: [Title](url) — note` in Sources.

### 7. Deliver

The verifier writes the final output directly to `<output>/<slug>.md`.
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
