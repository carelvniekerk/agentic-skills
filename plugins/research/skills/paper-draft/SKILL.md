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
allowed-tools: WebSearch WebFetch Read Write Bash(find *) Bash(mkdir *) Agent
disable-model-invocation: true
---

# Paper Draft

Turn research findings into a polished paper-style draft.
Supports Markdown and LaTeX output formats.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, including the outline and your messages to the user.
It carries the advisor stance, the truthfulness and confidence rules, the register and the phrasing blacklist that govern every artefact this skill produces.

Two consequences for how you run this workflow.
If the material does not support a paper, or the contribution the user wants to claim is not what the evidence shows, say so in your first message rather than drafting around the gap.
Formal and precise is the target register, and it is reached with plain sentences in the active voice: prefer "we train the model on" to "the model was trained on" unless the agent is genuinely irrelevant, and prefer "we evaluate" to "an evaluation is performed".

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

Spawn a **`research:writer`** agent.
Include in its brief:
- Paths to all source material identified in step 2 (research files, wiki articles, prior drafts, user-provided data).
- The outline from step 3.
- Output format (Markdown or LaTeX) and the corresponding template:
  - **Markdown:** the full contents of [references/output-format.md](references/output-format.md) — the writer must follow this template exactly.
  - **LaTeX:** the full contents of [references/latex-article-template.tex](references/latex-article-template.tex), OR, if `CLAUDE.md` defines a `latex_template:` path, the contents of that project template. The writer must insert content into the appropriate sections rather than creating a parallel file.
- Draft save path: `<scratch>/.drafts/<slug>-draft.md` (or `.tex`).
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/house-style.md`. The register, phrasing blacklist and punctuation rules bind the writer, in LaTeX as well as Markdown.
- These writing rules (all mandatory):
  - Keep each sentence on its own line in the source (semantic line breaks — clean diffs, identical rendering).
  - State claims precisely; flag tentative results as tentative.
  - Remove unsupported numerics — if a number has no source, remove it.
  - Include LaTeX math (`$inline$` / `$$display$$`) wherever equations materially help, regardless of output format.
  - Define all variables immediately after each equation is introduced.
  - Use the paper's own notation and the same term for the same thing throughout. Do not vary the name of a method, dataset or symbol for stylistic relief.
  - Active voice for anything the authors did. The passive belongs only where the agent is genuinely irrelevant or unknown.
- Reminder: do NOT add inline citations or a Sources/Bibliography section — the verifier handles that.

### 5. Verify and Cite

Spawn a **`research:verifier`** agent.
Include in its brief:
- Draft path: `<scratch>/.drafts/<slug>-draft.md` (or `.tex`) — the file extension drives the citation track.
- All source material paths (as the authoritative source pool).
- Final output path:
  - **Markdown:** `<output>/<slug>.md`.
  - **LaTeX:** `<output>/<slug>.tex`, OR the project template path if `latex_template:` is defined in `CLAUDE.md` (verifier inserts citations into the existing template).
- For LaTeX: check whether the project already has a `.bib` file; if so, add new entries there. If not, create `references.bib` alongside the `.tex` file.
- Reminders for the verifier:
  - Every factual claim must be anchored to a source from the supplied pool.
  - No claim should be stronger than its supporting evidence — weaken or remove rather than fabricate.
  - Mark limitations and open questions explicitly — do not smooth them away.
  - The full contents of `${CLAUDE_PLUGIN_ROOT}/references/house-style.md`. Weakened or rewritten claims must still obey the register and punctuation rules.

### 6. Deliver

The verifier writes the final output directly to the path determined in step 5.
Summarise to the user: what was written, which source materials were used, and what gaps or open questions remain.
List the judgement calls you made, in particular claims you weakened or cut for lack of support, and flag anything off in the underlying material: implausible numbers, results that are not comparable across sources, or a section resting on a single source.
