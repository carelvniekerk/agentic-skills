---
name: paper-draft
description: >-
  Turn research findings, notes or evidence into a paper-style draft with sections, equations and explicitly scoped claims, in Markdown (the research brief format) or LaTeX (a project template or the bundled article template), using the research:writer and research:verifier agents.
  Use when the user asks to write a paper, draft a report, write up results or turn notes into a paper.
argument-hint: <topic or slug> [--latex | --markdown]
disable-model-invocation: true
allowed-tools: WebSearch WebFetch Read Glob Write Bash(mkdir *) Agent
---

# Paper draft

You turn the user's material into a paper-style draft and deliver it at `<output>/<slug>.md` or `<output>/<slug>.tex`.
The draft states only what the material supports, and every number traces to a source or is removed.

Take from the project's `CLAUDE.md` the output directory (default `papers/`), the scratch directory (default `research_scratch/`) and any `latex_template:` path.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, the outline and your messages included, and pass its full contents in every agent brief.

If the material does not support a paper, or the contribution the user wants to claim is not what the evidence shows, say so in your first message rather than drafting around the gap.
The register is formal and precise, reached with plain sentences in the active voice: "we train the model on", not "the model was trained on", unless the agent is genuinely irrelevant.

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Paper draft progress:
- [ ] 1. Format decided (Markdown or LaTeX)
- [ ] 2. Source material gathered
- [ ] 3. Outline written, claims mapped to material
- [ ] 4. Draft written by research:writer
- [ ] 5. Draft verified and cited by research:verifier
- [ ] 6. Delivered with the claims weakened or cut
```

## 1. Decide the format

Use `--latex` or `--markdown` from the arguments, then a default in `CLAUDE.md`.
If neither settles it, ask the user.

## 2. Gather the material

Collect the research files in the scratch directory, relevant knowledge-base articles (through the `kb-query:wiki` skill when available), results and tables the user provided, and any earlier draft.

## 3. Plan the structure

Write an outline to `<scratch>/.plans/<slug>-draft-plan.md` with the title, the section headings, the key claims and the material behind each claim.
The default sections are title and abstract, introduction (problem, motivation, contributions), related work, method, experiments, discussion with limitations, conclusion and references, adapted to the paper type.

## 4. Draft

Spawn a `research:writer` agent with:

- The source material paths and the outline.
- The template:
  - Markdown: the full contents of `${CLAUDE_PLUGIN_ROOT}/references/brief-format.md`.
  - LaTeX: the full contents of `${CLAUDE_SKILL_DIR}/references/latex-article-template.tex`, or of the project's `latex_template:` file, with the instruction to fill its sections rather than create a parallel file.
- The draft path `<scratch>/.drafts/<slug>-draft.md` or `.tex`.
- The full contents of `house-style.md`, which binds LaTeX as well as Markdown.
- These rules:
  - One sentence per line in the source.
  - Tentative results labelled as tentative, and any number without a source removed.
  - LaTeX maths wherever an equation helps, in either format, with each variable defined straight after the equation.
  - The paper's own notation, and one name for each method, dataset and symbol throughout.
  - Active voice for anything the authors did.
  - No citations and no bibliography, because the verifier adds them.

## 5. Verify and cite

Spawn a `research:verifier` agent with:

- The draft path (its extension selects the citation track) and all source material as the source pool.
- The final path: `<output>/<slug>.md`, `<output>/<slug>.tex`, or the project's `latex_template:` file.
- For LaTeX, the instruction to add entries to the project's existing `.bib` file, or create `references.bib` beside the `.tex` file if there is none.
- The rules: anchor every factual claim to the pool, weaken or remove any claim stronger than its evidence, and keep limitations and open questions explicit.
- The full contents of `house-style.md`.

## 6. Deliver

Report the path, the material used and the gaps that remain.
List the claims you weakened or cut for lack of support, and flag implausible numbers, results that are not comparable across sources and sections resting on one source.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A number, result or citation the material does not contain | Fabrication in a paper is misconduct |
| Overwriting the project's LaTeX template or `.bib` entries the user wrote | Loses their work |
| Claiming a contribution the evidence does not show | The reviewer will find it |
