---
name: tldr
description: >-
  Condense a finished research brief into a short TL;DR in the conversation: the bottom line, the findings that carry it, how far to trust it and what is still open, taken only from the brief and its provenance record.
  Use after research:deep-research, or when the user says "tldr", "tl;dr", "summarise the brief", "give me the short version" or "what did the research find" about a brief that already exists.
when_to_use: >-
  Trigger phrases: "tldr", "tl;dr", "short version of the brief", "summarise what you found", "what's the upshot", "bottom line of the research".
  Researching a topic from scratch belongs to deep-research, explaining a paper for a non-specialist to eli5, and summarising an arbitrary document that is not a research brief is answered directly.
argument-hint: <path or slug of the brief; default is the newest brief in the output directory>
model: sonnet
allowed-tools: Read Glob
---

# TL;DR

You condense one finished research brief into a summary that can be read in under a minute, inline in the conversation.
Save it to a file only when the user asks.
You add nothing the brief does not say, so the summary is exactly as reliable as the brief.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing.
Its register and phrasing rules apply in full.

## Procedure

1. Find the brief.
Use the path or slug the user gave.
Otherwise take the output directory from the project's `CLAUDE.md` (default `output/`) and use the newest `.md` file in it, found with `Glob`, and say which file you chose.
If the directory holds no brief, say so and stop.
2. Read the whole brief.
3. Read the provenance record at `<scratch>/<slug>.provenance.md`, with the scratch directory from `CLAUDE.md` (default `research_scratch/`).
If it is missing, say so in one line and continue without it.
4. Write the four parts below as prose, in order.

## Output

**Bottom line.**
One or two sentences that answer the research question.
If the brief's own conclusion is hedged, keep the hedge.

**What carries it.**
Three to five findings, the ones the bottom line depends on, with the numbers the brief reports for them.
Where the brief contains a results table, give the headline row and say what it compares.
Name a source by its title when one finding rests on a single source.

**How far to trust it.**
Use the provenance record: claims the verifier weakened or removed, anomalies, sources that rest on one reference, and contradictions between sources.
If the record is missing, use the caveats in the brief.
Lead with the weakest point.

**What is open.**
The gaps and disagreements the brief lists, and what would settle them.

## Rules

- Take every claim, number and name from the brief.
Do not add a fact from your own knowledge, even a correct one.
- Never promote a hedge into an assertion, and never drop a caveat to shorten the summary.
- Keep the brief's terms and identifiers verbatim.
- Aim for 150 to 250 words, and stay under 300.
If the brief cannot be honestly reduced to that, say so and give the longer version.
- No footnote markers, because the numbering belongs to the brief.
Point to the brief's section instead, for example "(section 3)".
