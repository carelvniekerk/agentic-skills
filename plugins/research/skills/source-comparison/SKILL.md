---
name: source-comparison
description: >-
  Compare named papers, methods, models, libraries or frameworks against each other from external sources and produce a cited comparison matrix with a confidence label per cell, separating agreement, disagreement and gaps, using the research:researcher, research:writer and research:verifier agents.
  Use when the user asks to compare two or more named research methods, papers, models or tools on evidence, such as "compare DPO and PPO", "vLLM vs TGI for serving" or "how do these papers differ", and wants a sourced comparison rather than a quick opinion.
when_to_use: >-
  Trigger phrases: "compare these papers", "compare these methods", "X vs Y" for named methods or tools, "how do these approaches differ", "comparison matrix", "which of these frameworks", "side by side comparison of", "how does X stack up against Y".
  Comparing code, functions or implementation choices inside the current project is not this skill, and Claude answers that directly.
argument-hint: <the items to compare, and optionally the dimensions>
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
---

# Source comparison

You compare named items on chosen dimensions and deliver a cited matrix at `<output>/<slug>-comparison.md`.
Each cell carries a confidence label, and genuine conflict between sources stays visible instead of collapsing into a consensus no source states.

Take the scratch directory (default `research_scratch/`) and the output directory (default `output/`) from the project's `CLAUDE.md`.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, the plan and your messages included, and pass its full contents in every agent brief.

Lead with the recommendation the evidence supports, or with the objection that the items are not comparable on the dimensions asked for, before building a matrix nobody can act on.
A `low` confidence cell that decides the comparison belongs in the first paragraph, not a footnote.

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Source comparison progress:
- [ ] 1. Local knowledge checked for each item
- [ ] 2. Items and dimensions planned
- [ ] 3. Evidence gathered per item (uneven coverage: gather again for the thin item)
- [ ] 4. Matrix drafted by research:writer
- [ ] 5. Draft verified and cited by research:verifier
- [ ] 6. Delivered: what the evidence decides, what it does not
```

## 1. Check local knowledge

Search the knowledge base with the `kb-query:wiki` skill for each item.
If that skill is not available, say so in one line and continue.

## 2. Plan

Name the items and the dimensions (for example performance, method, cost, limitations, maturity, reproducibility).
Derive a slug and save the plan to `<scratch>/.plans/<slug>.md`.

## 3. Gather

Spawn a `research:researcher` agent with:

- The items and dimensions.
- The requirement of comparable coverage across items: if evidence is thin for one item, the file says so instead of padding with inference.
- One output file per item, `<scratch>/<slug>-research-<item>.md`.
- The full contents of `house-style.md`.

## 4. Build the comparison

Spawn a `research:writer` agent with:

- All research file paths and the draft path `<scratch>/.drafts/<slug>-comparison-draft.md`.
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/brief-format.md` for frontmatter, badges and citation conventions.
- The full contents of `house-style.md`.
- One name per item in every row, header and paragraph.
- The matrix: dimensions as rows, items as columns, a confidence label per cell:
  - `high`: two or more independent primary sources.
  - `medium`: one primary source or several secondary ones.
  - `low`: inferred, a single tertiary source, or not independently checked.
- Section order: framing paragraph, 🔗 Prerequisites if needed, 🎯 Key Takeaways (at most five bullets), Comparison matrix, Agreements, Disagreements, Gaps, 🔮 Open Questions, Sources placeholder.
- Agreements and disagreements name which source says what, and Gaps state the dimensions with no reliable evidence.
- The instruction to add no citations and no Sources section.

## 5. Verify and cite

Spawn a `research:verifier` agent with:

- The draft path, the research files as the source pool and the final path `<output>/<slug>-comparison.md`.
- Citation format: Markdown footnotes `[^N]`.
- The rule that every matrix cell traces to a citation, and a cell resting on one unchecked source is downgraded to `low`.
- The full contents of `house-style.md`.

## 6. Deliver

Report the path, the dimensions the evidence decides and those it does not, and the judgement calls behind the dimensions and confidence labels.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A cell filled from inference without a `low` label | The matrix would claim evidence it lacks |
| Averaging conflicting sources into one value | Hides the disagreement the user needs to see |
| Uneven evidence presented as an even comparison | The thinly covered item loses by default |
