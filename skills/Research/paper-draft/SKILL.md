---
name: paper-draft
description: >
  Turn research findings, notes, or evidence into a structured paper-style draft with proper sections, equations, and explicit claims.
  Supports both Markdown output (following the standard research brief format) and LaTeX output (using a project template or the bundled article template).
  Use this skill whenever the user asks to write a paper, draft a report, write up findings, or produce a structured technical document.
when_to_use: >
  Trigger phrases: "write a paper", "draft a paper", "write up findings", "turn this into a paper",
  "write up", "draft a report", "write the paper", "produce a writeup", "write the related work",
  "draft the introduction", "write up my results", "turn my notes into a paper".
argument-hint: <topic-or-slug> [--latex | --markdown]
allowed-tools: WebSearch WebFetch Read Write Bash(find *) Bash(mkdir *)
disable-model-invocation: true
---

# Paper Draft

Turn research findings into a polished paper-style draft.
Supports Markdown and LaTeX output formats.

Check `CLAUDE.md` for:
- The project's **output directory** (default: `papers/` for paper drafts).
- The project's **scratch directory** (default: `research_scratch/`).
- A **LaTeX template path** (`latex_template: path/to/template.tex`) — if defined, insert content there instead of using the bundled template.

## Workflow

### 1. Determine Output Format

Check whether the user specified `--latex` or `--markdown` in `$ARGUMENTS`.
If not specified, check `CLAUDE.md` for a preferred default format.
If still ambiguous, ask the user: **Markdown or LaTeX?**

### 2. Gather Material

Identify the source material:

- Research files in the project scratch directory.
- Local knowledge base articles with relevant coverage.
- Experimental results, tables, or data the user has provided.
- Any prior draft in the scratch directory.

### 3. Plan the Structure

Outline: proposed title, section headings, key claims, and which source material feeds each section.
Write the outline to `<scratch>/.plans/<slug>-draft-plan.md`.

Standard section structure (adapt as appropriate for the paper type):

1. Title + Abstract
2. Introduction — problem statement, motivation, contributions
3. Related Work — prior art, positioned against this work
4. Method / Approach — the core technical contribution
5. Experiments / Evidence — datasets, metrics, results
6. Discussion — interpretation, limitations
7. Conclusion
8. References / Bibliography

### 4. Draft

Follow these writing rules throughout:

- Keep each sentence on its own line in the source (semantic line breaks — clean diffs, identical rendering).
- State claims precisely; flag tentative results as tentative.
- Remove unsupported numerics — if a number has no source, remove it.
- Include LaTeX math (`$inline$` / `$$display$$`) wherever equations materially help, regardless of output format.
- Define all variables immediately after each equation is introduced.

**If writing Markdown:**
Read [references/output-format.md](references/output-format.md) and follow the standard document template exactly.
Save to `<output>/<slug>.md`.

**If writing LaTeX:**
Read [references/latex-article-template.tex](references/latex-article-template.tex) for the bundled template structure.
Check `CLAUDE.md` first — if `latex_template` is defined, open that file and insert the drafted content into the appropriate sections instead of creating a new file.
Save to `<output>/<slug>.tex` (or alongside the project template if inserting).

### 5. Verify and Cite

Sweep the full draft before delivery:

- Every factual claim must have a citation.
- No claim should be stronger than its supporting evidence.
- Mark limitations and open questions explicitly — do not smooth them away.

**Markdown:** use markdown footnote citations `[^N]` inline and `[^N]: [Title](url) — note` in the Sources section.
**LaTeX:** use `\cite{key}` throughout and populate the `.bib` file or bibliography section.

### 6. Deliver

Confirm the output path with the user before saving if the file is new.
Save the draft.
Summarise: what was written, which source materials were used, what gaps or open questions remain.
