---
name: deep-research
description: >-
  Run a multi-source investigation of a research topic and produce a self-contained, cited research brief with a provenance record, using the research:researcher, research:writer and research:verifier agents.
  Use when the user asks for deep research, a research brief, a thorough multi-source investigation or everything known on a topic, or wants a durable cited document rather than a chat answer, even if they do not say "research".
when_to_use: >-
  Trigger phrases: "deep research", "research this thoroughly", "write me a research brief on", "multi-source investigation", "I want a full picture of", "research and write up", "give me everything on".
  A survey of academic papers belongs to literature-review, a comparison of named options to source-comparison, and a quick lookup to external-research.
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
---

# Deep research

You run a multi-source investigation and deliver a cited research brief at `<output>/<slug>.md`, with a provenance sidecar in the scratch directory.
Research files, plan and draft stay in the scratch directory; only the verified brief goes to the output directory.
The skill does not add the brief to the knowledge base unless the user asks.

Take the scratch directory (default `research_scratch/`) and the output directory (default `output/`) from the project's `CLAUDE.md`.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, the plan and your messages included.
It carries the advisor stance, the truthfulness rules and the register that bind every artefact here, and every agent brief below includes its full contents.

If the question is mis-framed or too broad for one brief, say so in your first message, before any search.
If the conclusions rest mostly on inference rather than on sources read, say so in the first line of the delivery message.

## Contents

- Workflow
- 1. Check local knowledge
- 2. Plan
- 3. Gather evidence
- 4. Evaluate and loop
- 5. Write the brief
- 6. Verify and cite
- 7. Deliver
- Strict prohibitions

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Deep research progress:
- [ ] 1. Local knowledge checked
- [ ] 2. Plan written and shown
- [ ] 3. Evidence gathered by research:researcher
- [ ] 4. Gaps assessed (significant gaps: return to 3, at most two extra rounds)
- [ ] 5. Draft written by research:writer
- [ ] 6. Draft verified and cited by research:verifier
- [ ] 7. Provenance written, judgement calls and anomalies reported
```

## 1. Check local knowledge

Search the knowledge base with the `kb-query:wiki` skill and note what is already covered and what is missing.
If that skill is not available, say so in one line and continue.

## 2. Plan

Write down the key questions, the evidence types needed (papers, web, repositories, docs), the time period that matters and the acceptance criteria that would make the answer sufficient.
Derive a slug of at most five lowercase hyphenated words from the topic.
Save the plan to `<scratch>/.plans/<slug>.md`, show it to the user, then continue without waiting.

## 3. Gather evidence

Spawn a `research:researcher` agent with:

- The full plan from step 2.
- A target of at least 12 sources, and the rule that fewer than 8 is insufficient.
- For a broad topic, one output file per research dimension, named `<scratch>/<slug>-research-<dimension>.md`.
- The full contents of `house-style.md`.

## 4. Evaluate and loop

Read the research files and check which plan questions remain unanswered, which answers rest on one source, which sources contradict each other and which angle is missing.
If a gap would change the conclusions, spawn another `research:researcher` aimed at that gap.
Stop when another round would not change the conclusions, and after at most two extra rounds.

## 5. Write the brief

Spawn a `research:writer` agent with:

- The paths of all research files.
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/brief-format.md`, which the writer follows exactly.
- The full contents of `house-style.md`.
- The draft path `<scratch>/.drafts/<slug>-draft.md`.
- These depth requirements:
  - At least about 2,500 words of body text, and 5,000 or more for a complex topic.
  - Each major source gets its own subsection or paragraph covering its contribution, method and key results.
  - Quantitative results where the sources report them, and methods explained rather than named.
  - Agreements and disagreements between sources stated explicitly.
  - A results table (`Method | Dataset | Metric | Score | Source`) wherever two or more sources report numbers on the same task.
  - Equations reproduced in LaTeX (`$inline$`, `$$display$$`), each variable defined straight after the equation.
- The instruction to add no citations and no Sources section, because the verifier adds them.

## 6. Verify and cite

Spawn a `research:verifier` agent with:

- The draft path and every research file path, as the authoritative source pool.
- The final path `<output>/<slug>.md`.
- Citation format: Markdown footnotes `[^N]`, never HTML anchors or `[[N]](#ref-N)`, which break Obsidian rendering.
- The full contents of `house-style.md`, which binds any wording the verifier rewrites.

## 7. Deliver

Write the provenance sidecar to `<scratch>/<slug>.provenance.md`:

```markdown
# Provenance: <topic>

- **Date:** YYYY-MM-DD
- **Rounds:** <evidence-gathering rounds>
- **Sources consulted:** <unique sources>
- **Sources accepted:** <sources that survived verification>
- **Sources rejected:** <dead links, unverifiable or removed>
- **Local knowledge before:** <what the wiki already covered>
- **Plan:** <scratch>/.plans/<slug>.md
- **Research files:** <intermediate files>
- **Judgement calls:** <scoping decisions, exclusions, contradictions resolved by preferring one source>
- **Anomalies:** <implausible numbers, metrics that are not comparable, claims resting on one source>
```

In the delivery message, give the brief's path, then the judgement calls and anomalies, and the claims the verifier weakened or removed.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A source, quote, number or bibliographic field the research files do not contain | The brief is only as good as its provenance |
| Citing or describing a source nobody fetched | A title is not evidence of content |
| Writing scratch files, plans or drafts into the output directory | The output directory holds deliverables only |
| Integrating the brief into the knowledge base without being asked | The wiki is the user's to curate |
