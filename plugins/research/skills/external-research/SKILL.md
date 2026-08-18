---
name: external-research
description: >
  Web and academic evidence gathering — searches the open internet, arXiv, Semantic Scholar, GitHub, and official documentation for sources not available locally.
  Use this skill when the user asks about recent developments, current state-of-the-art, latest releases, benchmarks, or anything time-sensitive.
  Also use it when conducting literature reviews, deep research, or source comparisons, and when verifying claims that need external corroboration.
  Always check local knowledge (wiki-search or equivalent) before reaching for this skill.
when_to_use: >
  Trigger phrases: "search for", "look up online", "find papers on", "what does the web say about",
  "recent research on", "state of the art", "what's the latest on", "find sources for",
  "are there any papers on", "search arXiv", "what's current in", "find implementations of".
allowed-tools: WebSearch WebFetch
---

# External Research (Web + Academic)

Search the open internet and academic literature for evidence not yet available locally.
This skill is for **external** evidence gathering only — check local knowledge sources first before invoking this.

## Tool Routing

| What you need | Tool to use | Notes |
| --- | --- | --- |
| Current topics: products, releases, benchmarks, docs, pricing | `WebSearch` | Always for "latest/current/recent" queries |
| Academic papers, methods, theoretical results | `WebSearch` → arXiv, Semantic Scholar, Google Scholar | Background literature |
| Code repositories, implementations | `WebSearch` → GitHub | Reproducibility checks |
| Official documentation, vendor specs | `WebFetch` with specific URL | When the URL is known |
| Mixed topics | Combine web + academic | Most research tasks |

## Rules

- **Never answer a "latest/current" question from training knowledge alone.**
Always fetch recent web sources.
- **For AI model or product claims**, prefer official docs and vendor pages plus recent web sources over old papers.
- **For mixed topics**, combine both: web sources for current reality, academic sources for background literature.
- **Cite everything.**
Every factual claim needs a source URL.
A claim without a URL is not a finding — it is a guess.
- **Verify URLs resolve.**
Before including a source, confirm the page actually loads and contains what you expect.
- **Prefer primary sources.**
Vendor docs and original papers beat blog summaries and secondhand writeups.

## Evidence Quality Tiers

1. **Primary** — original paper, official docs, vendor announcement, code repository.
2. **Secondary** — reputable technical blog, peer-reviewed survey, conference talk with slides.
3. **Tertiary** — news article, forum post, social media. Use only to corroborate, never as sole source.

## Output

Write evidence to scratch files named `<slug>-research-<source-type>.md` in the **project's designated scratch directory**.
Check `CLAUDE.md` for the project's scratch directory convention; if none is defined, default to `research_scratch/`.
These are intermediate files — final deliverables are written by the calling skill or workflow.

Structure each scratch file as:

```markdown
# Evidence: <topic> — <source-type>

## Source 1: [Title](url)
- **Type:** primary / secondary / tertiary
- **Date:** YYYY-MM-DD
- **Key finding:** one sentence
- **Relevant excerpt or notes:**
  ...

## Source 2: ...
```
