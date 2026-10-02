---
name: external-research
description: >-
  Look up current external evidence on the web and in academic sources (arXiv, Semantic Scholar, GitHub, official documentation) and answer in the conversation with a URL for every claim.
  Use when the user asks about a recent release, the current state of a model, library, benchmark or price, "what's the latest on", "is there a paper on", "find a paper that", or wants a claim checked against external sources, even if they do not say "search".
when_to_use: >-
  Trigger phrases: "look this up online", "what's the latest on", "is there a paper on", "find a paper that shows", "search arXiv for", "what's current in", "check whether this is still true", "find an implementation of".
  Searching the current repository or local files is not this skill. A full brief belongs to deep-research and a survey of papers to literature-review.
allowed-tools: WebSearch WebFetch
---

# External research

You answer a question from current external sources, in the conversation, with a URL behind every factual claim.
Write evidence to files only when the user asks for it, because a lookup in the middle of other work should not leave files in their repository.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing the answer.
Its truthfulness rules govern what counts as a finding, and its register governs the prose.

## Workflow

1. If the question touches something the user has written or read, search the knowledge base with the `kb-query:wiki` skill first, and say what it already covers.
2. Search with two to four differently angled queries at once, then narrow with the names and terms the first results give you.
3. Read the sources that carry the answer, preferring primary ones.
4. Answer: the finding first, then the supporting sources, then anything you could not establish.

| Need | Route |
| --- | --- |
| Releases, benchmarks, docs, pricing, anything "latest" or "current" | `WebSearch` for recent pages, then `WebFetch` the official source |
| Papers, methods, theoretical results | `WebSearch` on arXiv, Semantic Scholar or Google Scholar, then `WebFetch` the abstract or HTML version |
| Implementations | `WebSearch` on GitHub, then `WebFetch` the README |
| A known URL | `WebFetch` directly |

## Rules

- Never answer a "latest" or "current" question from training knowledge alone.
- Give every factual claim a URL you fetched.
A claim without one is labelled as unsourced or left out.
- Prefer primary sources: original papers, official docs, vendor announcements and repositories beat blog summaries.
Use news, forums and social media only to corroborate.
- `WebFetch` returns a model's answer about the page, so ask it for the verbatim passage when a quote or number matters, and call anything else a paraphrase.
- Mark your own inference `[Likely]` or `[Guessing]`, and do not tag what a source states.
- If the evidence does not exist, say so in the first line, and do not pad the answer with adjacent material to disguise the gap.
- Flag implausible numbers, results on different splits or metrics, undated pages and sources that contradict each other.

## Writing to files

When the user asks to keep the evidence, write `<scratch>/<slug>-research-<source-type>.md`, with the scratch directory from the project's `CLAUDE.md` (default `research_scratch/`):

```markdown
# Evidence: <topic>, <source type>

## Source 1: [Title](url)

- **Type:** primary, secondary or tertiary
- **Date:** YYYY-MM-DD
- **Key finding:** one sentence
- **Notes:** the relevant excerpt, marked verbatim or paraphrase
```

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| A source, title, author, number or quote you did not fetch | Fabrication |
| "Studies show" or "experts agree" without a linked source | Vague authority |
| Writing files the user did not ask for | Leaves debris in their repository |
