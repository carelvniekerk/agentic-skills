---
name: literature-review
description: >-
  Survey the academic literature on a research question and produce a thematic literature review with results tables, notation, consensus, disagreements, trends and open questions, using the research:researcher, research:writer and research:verifier agents.
  Use when the user asks for a literature review, a survey of papers, a related work section, the state of the art in a research area or what has been published on a research question.
when_to_use: >-
  Trigger phrases: "literature review", "lit review", "survey the papers on", "related work section", "what papers exist on", "what does the literature say about", "prior work on", "who has published on", "state of the art in".
  A general multi-source brief belongs to deep-research, a critique of one paper to peer-review, and a quick paper lookup to external-research.
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
---

# Literature review

You survey the papers on a research question and deliver a thematic review at `<output>/<slug>.md`, organised by theme rather than chronology.
Plan, research file and draft stay in the scratch directory.
The skill does not add the review to the knowledge base unless the user asks.

Take the scratch directory (default `research_scratch/`) and the output directory (default `output/`) from the project's `CLAUDE.md`.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, the plan and your messages included, and pass its full contents in every agent brief.

If the field is too broad for one review, or the user's framing assumes a consensus that does not exist, say so in your first message, before searching.
A claim resting on one paper is labelled as such, never asserted as the field's view.

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Literature review progress:
- [ ] 1. Local knowledge checked
- [ ] 2. Scope planned
- [ ] 3. Papers gathered by research:researcher (fewer than 8 papers: gather again)
- [ ] 4. Review drafted by research:writer
- [ ] 5. Draft verified and cited by research:verifier
- [ ] 6. Delivered with judgement calls and anomalies
```

## 1. Check local knowledge

Search the knowledge base with the `kb-query:wiki` skill and note which papers and concepts are already documented.
If that skill is not available, say so in one line and continue.

## 2. Plan

Write down the key questions, the sources to search (arXiv, Semantic Scholar, Google Scholar, proceedings), the time period and the expected themes.
Derive a slug and save the plan to `<scratch>/.plans/<slug>.md`.

## 3. Gather

Spawn a `research:researcher` agent with:

- The plan from step 2.
- The search strategy: start broad, find the seminal papers and any existing surveys, then trace citations forwards and backwards.
- Per paper: title, authors, year, venue, contribution, method and quantitative results.
- A target of at least 10 papers, and the rule that fewer than 8 makes an inadequate review.
- The output file `<scratch>/<slug>-research-papers.md`.
- The full contents of `house-style.md`.

## 4. Synthesise

Spawn a `research:writer` agent with:

- The research file path and the draft path `<scratch>/.drafts/<slug>-draft.md`.
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/brief-format.md`, which the writer follows exactly.
- The full contents of `house-style.md`.
- The structure: themes, not chronology, with each paper's method, results and significance treated in its theme.
- Mandatory content:
  - Quantitative results where reported.
  - A results table (`Method | Paper | Dataset | Metric | Score`) wherever two or more papers report on the same task, with differing experimental conditions noted below it.
  - Key objectives, losses and algorithms in LaTeX, each variable defined straight after the equation.
  - Consensus (two or more papers), disagreements with the papers on each side, open questions, and trends with dates.
- Length: at least about 2,500 words, and 4,000 or more for a mature field.
- The instruction to add no citations and no Sources section.

## 5. Verify and cite

Spawn a `research:verifier` agent with:

- The draft path, the research file as the source pool and the final path `<output>/<slug>.md`.
- Citation format: Markdown footnotes `[^N]`.
- The rule that every factual paragraph carries at least one citation, and a claim that rests on a single source is hedged rather than asserted.
- The full contents of `house-style.md`.

## 6. Deliver

Write a provenance sidecar to `<scratch>/<slug>.provenance.md` with the papers excluded and why, how conflicting results were resolved, and which cross-paper comparisons are not like-for-like.
In the delivery message, give the review's path, then those judgement calls, the anomalies in the evidence and the claims the verifier weakened or removed.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A paper, author, venue, year or result the research file does not contain | Fabricated bibliography is the failure this plugin exists to prevent |
| "Recent work suggests" with no named paper | Vague authority |
| Comparing numbers across different splits or metrics without saying so | The table would mislead |
| Integrating the review into the knowledge base without being asked | The wiki is the user's to curate |
