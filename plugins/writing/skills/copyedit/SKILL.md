---
name: copyedit
description: Copyedit a finished client deliverable or business document in English or German so it reads as written by an experienced consultant, fixing wording, AI tells, punctuation, locale formats and consistency while keeping every number, claim and commitment intact, then report the changes and the weak points left. Use when the user asks to copyedit, proofread, polish, tighten, clean up or fix the language of a report, assessment, proposal, statement of work, executive summary, memo, email or slide text, says a draft reads like AI or ChatGPT, or asks to Korrektur lesen, sprachlich überarbeiten, glätten or lektorieren, even if they do not say copyedit. Not for drafting from notes, translating or building the branded file.
license: MIT
compatibility: The lint script needs Python 3.10 or later and only the standard library. It runs with uv run, or with python3 when uv is not installed.
allowed-tools: Read Edit Write Grep Glob Bash(uv run *) Bash(python3 *) Bash(cp *) Bash(diff *) Bash(git diff *) Bash(git status *)
metadata:
  source: "github.com/carelvniekerk/agentic-skills, plugins/writing/skills/copyedit"
---

# Copyedit

You copyedit a finished draft that is about to go to a client.
The output is the same file with the language fixed, and a short report in the conversation.
You change words, sentences, punctuation, locale formats and consistency.
You do not change what the document says: numbers, findings, commitments, scope, defined terms, quotations, citations, code and table data stay as they are.
Structural weaknesses, such as an argument in the wrong order, a recommendation without evidence or figures that do not reconcile, go into the report rather than into a rewrite, unless the user asks for the rewrite.
A client brief, glossary or style guide overrides this skill wherever the two conflict.

## Contents

- Workflow
- The rules most often broken
- What never changes
- Input formats
- Report
- Gotchas
- Strict prohibitions
- Files in this skill

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Copyedit progress:
- [ ] 1. Language, genre and overrides settled
- [ ] 2. Original kept
- [ ] 3. Original linted
- [ ] 4. Whole document read once, nothing edited yet
- [ ] 5. Sentence diagnosis listed, then four editing passes done
- [ ] 6. Edited file linted and compared (an unexplained difference sends you back to 5)
- [ ] 7. Independent check done
- [ ] 8. Report written
```

**1. Settle language, genre and overrides.**
Read [references/english.md](references/english.md) for English text and [references/german.md](references/german.md) for German text, and both for a bilingual document.
Each opens with a register table: find the genre (contract or statement of work, proposal, assessment or report, executive summary, email, slide text) and apply its row.
Look for a client brief, glossary or style guide in the conversation and beside the file.
Where the client requires a convention that differs from the reference, such as US spelling, keep the client's convention and say so in the report.

**2. Keep the original.**
If the file is tracked by git and `git status` shows it unmodified, git holds the original.
Otherwise copy it before the first edit, so the compare step and the user's review have something to compare against:

```bash
cp report.md report.orig.md
```

**3. Lint the original.**

```bash
uv run "${CLAUDE_SKILL_DIR}/scripts/prose-lint.py" report.md
```

Use `python3` in place of `uv run` when uv is missing.
Add `--lang en` or `--lang de` when automatic detection gets a mixed document wrong.
The hits are candidates, never verdicts.
A `fix` hit breaks a rule and is almost always changed.
A `check` hit needs your judgement, and many will be right as written.
The two density lines matter more than any single hit: a "rather than" tic or a uniform rhythm says the whole text needs attention, not one sentence.

**4. Read the whole document once before editing.**
Note the canonical form of each defined term, the actor convention, the number and date formats in use, and which statements are findings, hypotheses, recommendations or commitments.
Note every anomaly for the report as you meet it: figures that do not add up, a broken sentence, a numbering gap, a claim with no evidence, a heading that promises more than its section delivers.

**5. Diagnose every sentence, then edit in four passes, in this order.**

The lint finds listed tells and cannot find a sentence that is vague without containing one.
Before the first edit, go through each chapter sentence by sentence and write down, in your working notes, every sentence that fails one of these four tests:

- **Actor and action.** Name who or what does the thing, and what the thing is. If the subject is a box, a column, a table, a tool, a panel, a section or a feature, and the verb is one a person would use (carries, receives, names, sits, speaks to), the sentence fails.
- **Layout or fact.** If the sentence tells the reader how the figure, table or page is built instead of stating what is true, it fails. Cut it when the heading or caption already says it, and otherwise state the fact.
- **Full sentence.** A verbless fragment that opens a section or caption ("Four columns, eight numbered zones, drawn from the slide.") fails, unless it is a list item or a table cell.
- **Plain restatement.** Say in plain words what the sentence claims. If you cannot, or the plain version is much shorter, the sentence fails.

A sentence that is grammatical, free of banned words and still fails a test gets rewritten.
Write the note as "sentence, test failed", then fix the sentences in passes 2 and 3.
The notes are working material and do not go into the report except as counts.

1. Mechanics: dashes, locale formats applied across the whole document including tables, spelling variety, heading case, MULTIPLAI in capitals, punctuation and quotation marks.
2. Words: banned and watch vocabulary, intensifiers, filler, copula avoidance, nominalisation, figurative or human verbs on things (the verb list is in the reference), and in German Floskeln, Amtsdeutsch and Anglicisms.
3. Sentences: every sentence on the diagnosis list, then antithesis framing, colon-then-reveal, trailing participle clauses, signposts, punchline endings, one-line aphorism paragraphs, vague authority, impersonal evaluation, hidden actors, layout descriptions, verbless fragments and compression that needs a second read.
4. Consistency: one form per defined term, one actor convention, one tense per section, parallel lists and closed scope lists.

Edit minimally.
Change the phrase, not the paragraph, and keep the author's vocabulary level and sentence order wherever nothing is wrong with them.
A passage with no problems stays as it is, because editing to a quota makes the text read as if a second author wrote it.
A sentence is a problem when it fails a diagnosis test, even if it is grammatical and uses no listed word, so "nothing is wrong with it" is judged by the four tests and not by whether the lint was silent.
In Markdown and LaTeX keep one sentence per line and leave frontmatter, Marp directives, code, links and LaTeX commands untouched.

**6. Lint the edited file and compare it with the original.**

```bash
uv run "${CLAUDE_SKILL_DIR}/scripts/prose-lint.py" report.md
uv run "${CLAUDE_SKILL_DIR}/scripts/prose-lint.py" --compare report.orig.md report.md
```

Every `fix` hit that remains must be deliberate and named in the report with its reason.
In the comparison, each missing or added number, each change in the count of negations, modals or hedges, each changed quotation and each missing term needs an explanation.
Revert any change you cannot explain.

**7. Get an independent check.**
In Claude Code with the advisor tool on (`/advisor`), consult the advisor before you write the report, and ask one question: did any edit change a claim, a number, a commitment or the strength of a statement?
Without the advisor, read the word diff yourself with that question and nothing else (`git diff --word-diff` or `diff`).
Do not score the text with a rubric or ask a model to rate it.
The acceptance checks are the lint, the comparison and the diff.

**8. Write the report** in the format below.

## The rules most often broken

**Calibrate, do not soften.**
Sort every claim into one of four kinds and write each at its actual strength.
A commitment is firm: "MULTIPLAI delivers", "will", "liefert".
A finding is stated with its evidence and no qualifier: "212 of 530 nightly tasks rebuild their table in full."
A hypothesis is labelled once, in plain words: "This is a hypothesis, and we recommend verifying it first."
A recommendation is an imperative with its condition: "Switch the second group of datasets once retention has expired."
Never add "often", "might" or "can" to make a claim sound modest, and never remove a qualifier the evidence needs.
Promoting a hedge into an assertion is the worst error this skill can make.

**Replace a cut rhetorical beat with its mechanism.**
Deleting a punchy line is half the edit.
Write the sentence that says what is happening.
"The pattern is the deliverable, not the domain." becomes "The pilot is meant to prove a pattern that other domains can reuse: certified KPI, consolidated Explore, grounded answer."

**Keep antithesis only where the contrast is the point.**
A scope boundary is such a case: "The focus is a fit-for-purpose gate, not a broad vendor selection."
Everywhere else, state the positive claim and drop the foil.
More than about one "rather than" per 1,000 words is a tic, so keep the instances where the alternative is one the reader would otherwise assume.

**Name the actor.**
Use the active voice, and the passive only where the actor is irrelevant or unknown.
In contracts and statements of work the company name is the subject ("MULTIPLAI validates").
In reports MULTIPLAI is "we" and the client appears by name.
Replace "it is recommended" and "es wird empfohlen" with the party that recommends.

**Give things literal verbs.**
A person decides, scores, names and receives.
A box, a panel or a feature does not, so name the person or use a verb that is literally true: is, has, shows, lists, repeats, gives, contains, uses, supports.
"Each box carries the slide's wording" becomes "Each box repeats the slide's wording".
"Each tool receives two scores" becomes "We score each tool twice".
Technical verbs that describe what a system does in its own field stay: a service stores, runs, writes, reads and sends.
The test is whether the verb describes what the subject does or is only borrowed for variety.

**State the fact, not the layout.**
Do not describe how the figure, table or page is built when the caption or heading does that already.
"Four columns, eight numbered zones, drawn from the 2026-09-14 target slide." becomes "The diagram has four columns and eight numbered zones, taken from the target slide of 2026-09-14."
Keep a statement of source or reading rule that the reader acts on, in full sentences.

**Hold terms constant.**
One form per defined term, product name and proper noun, everywhere in the document.
No elegant variation, and "it" only where a single referent is in reach.

**Punctuation and headings.**
No em or en dashes as punctuation, and no spaced hyphen standing in for one.
Avoid semicolons in client prose.
No exclamation marks and no emoji.
Sentence case for headings, keeping the capitals of proper nouns and defined terms.
Use the serial comma only where a sentence is ambiguous without it.

**Lists.**
Activity and deliverable lists are parallel and start with a verb or a noun consistently.
Scope, deliverable and requirement lists are closed: "including" followed by the complete list, never "etc.".

**State facts at their actual size.**
Remove "key", "significant", "substantial" and "critical" unless a figure or a consequence follows.
Do not upgrade a modest result, and do not understate a strong one ("results were satisfactory" for a 40 % reduction).

## What never changes

| Element | Why |
| --- | --- |
| The value of a number, a date, a price or a unit | Formatting may change, the value may not |
| Negations, and modals of obligation (shall, must, will, muss, wird) | They decide what the client is promised |
| Findings, scope, assumptions and exclusions | Changing them is authoring, not copyediting |
| Quotations, verbatim requirements and stakeholder statements | They belong to the person quoted |
| Defined terms, client terminology and product names | The client's spelling wins, Title Case included |
| Citations, cross-references, figure and table numbers | Other documents point at them |
| Code, configuration, identifiers and table data | They are not prose |
| Negotiated contract wording such as "reasonable" or "timely" | Its vagueness was agreed, so flag it instead of sharpening it |

## Input formats

Markdown, Marp, LaTeX and plain text are edited in place.
For a Word or PowerPoint file, edit through the matching docx or pptx skill so formatting survives, use tracked changes when the user wants to review them, and lint a Markdown conversion made with markitdown.
A PDF cannot be edited: convert it with markitdown, lint the result and return a change list keyed by page or section, with the original phrase and the replacement.
A signed contract is never edited, only commented on.

## Report

Lead with the weak points, then the changes.
Write plain prose and short lists, with no closing summary.

````markdown
Copyedit of report.md (English, assessment)

Weak points the copyedit did not fix:
- <structural problem, unsupported claim, figure that does not reconcile, numbering gap>

Changes:
- Mechanics (n): <two or three representative examples>
- Words (n): <examples>
- Sentences (n): <examples>
- Consistency (n): <examples>

Judgement calls:
- <a convention you kept or chose, a lint hit you left on purpose and why>

Checks: fix-level hits a -> b; "rather than" x -> y per 1,000 words; numbers, negations and modals unchanged (or the explained differences); advisor consulted or diff reviewed.
Original kept at report.orig.md.
````

## Gotchas

- Lint false positives are common and expected: "robust" in statistics, "key" in "primary key", "landscape" in "system landscape", a legitimate "rather than", Title Case flags on defined terms, and page-number noise from converted PDFs.
Judge each one in context.
- Convert number separators only across the whole document, tables included, and only when the document is consistently in the other convention.
"1,250" is one thousand two hundred and fifty in English and one point two five in German.
The comparison ignores separators, so it cannot catch a misread: check every converted number that has a decimal part by eye.
- Spell out numbers under ten only in running text, never with a unit, in a table or in a name such as "Phase 1" or "Module 2".
- In contracts keep "shall" for obligations and restated survival clauses, never merge clauses, and never turn "shall" into "will" or the reverse.
- Long documents lose attention towards the end.
Work chapter by chapter, about 1,500 words at a time, and lint each chapter as you finish it.
- A heading may be the client's own section name in their template, so check the template before sentence-casing it.
- Do not remove a qualifier just because the lint flagged a hedge.
The question is whether the evidence supports the stronger claim, and the report says when it does not.
- When you replace a figurative verb, do not change who does what.
"The slide names the technology" and "we name the technology" are different claims, so check the source before you choose the new actor, and prefer a verb that keeps the thing as the subject ("The panel gives the technology") when you are unsure.
- The lint does not detect figurative verbs, layout descriptions or fragments yet, so a clean lint says nothing about them.
- Several copyediting habits from personal-voice style guides are wrong here: pervasive softening, exclamation marks, humour, a spaced hyphen as a dash and "etc." in closed lists.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Editing without a copy of the original or a clean git state | The comparison and the user's review need the original |
| Changing a number's value, a negation, an obligation or a quotation without saying so | It changes what the client is told or promised |
| Adding claims, figures, sources or examples | The author would answer for text they did not write |
| Editing a PDF or a signed contract in place | A PDF has no editable source, and a signed contract is a legal record |
| Using a model's score or rating as the acceptance check | The acceptance checks are deterministic: lint, comparison and diff |
| Committing, pushing, uploading or sending the document | Hand over to the user |

## Files in this skill

- [references/english.md](references/english.md): register by genre, calibration, before and after patterns, vocabulary lists, British locale rules, German interference in English, contract language and annotated exemplars.
Read it for any English text.
- [references/german.md](references/german.md): the same structure for German, with Sie, Nominalstil, Floskeln, Anglicisms, DIN 5008 formats and German exemplars.
Read it for any German text.
- `scripts/prose-lint.py`: the deterministic lint and the `--compare` check.
Run it, do not read it.
