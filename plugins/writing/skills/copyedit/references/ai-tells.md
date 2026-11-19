# AI tells in English

A catalogue of wording and sentence patterns that make a client document read as machine-written, each with the reason it is a tell, a replacement and a before and after.
Read it in passes 2 and 3 of the copyedit, and whenever a lint hit needs a second opinion.
It extends [english.md](english.md), which keeps the register, the calibration table and the locale rules.
The lint rule that finds each pattern is named in brackets where one exists.

Every example is illustrative and was written for this file.
Names, figures and dates in them are invented.
A word in the lists below is a candidate, never a verdict: "robust" in statistics and "key" in "primary key" stay.

## Contents

- 1. Vocabulary, with the reason each word is a tell
- 2. Phrases
- 3. Sentence openers and closers
- 4. Patterns with before and after
- 5. Plain-word substitutions
- 6. Worked examples
- 7. Extra questions for the sentence diagnosis
- 8. Sources

## 1. Vocabulary, with the reason each word is a tell

The words already listed in section 4 of english.md (delve, leverage, seamless, holistic and the rest) stay there.
This table adds the words that file does not have, and gives the reason, because a reason lets you judge the borderline case.
[banned-en, watch-en]

| Word | Why it reads as a tell | Use instead |
| --- | --- | --- |
| utilise, utilize | A longer form of "use" with the same meaning | use |
| facilitate | Names no action: who does what to whom? | help, enable, or the action itself |
| innovative | Claims novelty and does not say what is new | what is new, in one clause |
| sophisticated | Claims quality or complexity and states neither | what is complex, or cut |
| groundbreaking, revolutionary | Asserts a size of change that the evidence has to show | the measured change |
| bombshell | Newsroom drama in a business document | the finding, stated plainly |
| rich (before a noun) | Pads the noun: "rich ecosystem", "rich history" | cut, or the specific property |
| comprehensive | Asserts completeness the text rarely proves | what it covers: "covers all 14 source systems" |
| paradigm | In business prose it seldom describes a change in the underlying model | model, approach, or the change itself |
| substantial, critical | Size words with no figure or consequence behind them | the figure, or what depends on it |

Keep "critical" in "critical path", "substantial" in a legal sense, and "comprehensive" only where a list of what it covers follows.

## 2. Phrases

### Throat-clearing

Delete these and start with the content.
[filler-en, signpost-en, stock-en]

- "It's important to note that", "it is worth mentioning that", "it goes without saying"
- "In today's [anything] landscape"
- "Let's dive into", "let's delve into", "without further ado"
- "In this article we will", "in this document we will", "as we all know"

### Empty hedges and framing

[empty-transition-en, filler-en]

- "To be fair", "to be honest"
- "At the end of the day"
- "When it comes to", "in terms of", "with respect to"

### AI enthusiasm

[stock-en]

- "This is a game-changer"
- "And that's a good thing", "and that's okay"
- "Here's the thing"
- "That makes a lot of sense", "there are several ways to look at this"
- "I'm here for it"

### Corporate padding

[filler-en]

- "Moving forward", "going forward"
- "At this point in time", "due to the fact that", "in order to"

## 3. Sentence openers and closers

A sentence that opens with one of these has not started yet.
[opener-en, closer-en]

| Opener | Before | After |
| --- | --- | --- |
| So, | "So, the migration finished on schedule." | "The migration finished on schedule." |
| Well, | "Well, the estimate is rough." | "The estimate is rough." |
| Now, | "Now, the second option costs more." | "The second option costs more." |
| Look, / Listen, | "Look, the data does not support that." | "The data does not support that." |
| Basically, | "Basically, the table is rebuilt every night." | "The table is rebuilt every night." |
| Essentially, | "Essentially, two teams own one process." | "Two teams own one process." |

"Now" is correct when it is about time: "Now the contract is signed, the work starts."

A closing tag turns a statement into a bid for agreement.
Cut "right?", "you know?" and "if you will": "This is the better option, right?" becomes "This is the better option."

## 4. Patterns with before and after

### Antithesis

Covered in the main skill and in english.md.
Both forms below are the same tell.
[antithesis-en]

| Before | After |
| --- | --- |
| "This is not just a migration, it is a rethink of how data is owned." | "The migration moves ownership of 40 datasets from IT to the business domains." |
| "It's not about the tool, it's about the people." | "The tool works. Adoption stalls because no team owns the metric definitions." |

Keep the contrast only where it is the point, such as a scope boundary.

### Fundamental change

[fundamental-en]

| Before | After |
| --- | --- |
| "This fundamentally transforms how analysts work." | "Analysts query one certified table and no longer reconcile three exports by hand." |
| "This represents a fundamental shift in how we plan." | "Planning moves from a yearly cycle to a quarterly one." |

State what changes, for whom, and from what to what.

### Inflated claims

[inflated-claim-en, banned-en]

| Before | After |
| --- | --- |
| "A groundbreaking assessment and a major milestone for the client." | "The assessment covers 14 source systems and delivered its roadmap on 2026-11-02." |
| "A bombshell finding." | "Retained previous versions make up 41.2 % of the physical footprint." |
| "A real turning point for the platform." | "The platform ran without an unplanned outage for the first time in 14 months." |

Let the facts carry the weight.
The reader decides how large the finding is.

### Empty transitions and framing openers

[empty-transition-en]

| Before | After |
| --- | --- |
| "With that in mind, we turn to costs." | "Compute is the largest cost item." |
| "Building on this foundation, the next step is the semantic layer." | "The semantic layer comes next." |
| "Taking this a step further, we also looked at retention." | "Retention adds a second saving." |
| "The reality is that most teams cannot staff a platform group." | "Most teams cannot staff a platform group." |
| "The truth is, the estimate is rough." | "The estimate is rough: it rests on one week of billing data." |
| "To be honest, the sample was small." | "The sample was 30 runs." |
| "When it comes to security, the tool is weak." | "The tool has no audit log." |

"The reality is" and "the truth is" imply that the surrounding text is not, and the claim needs no opener.

### Reflexive triples

Three items read as complete, so a model reaches for three whether or not three exist.
The density figure in the lint output counts "a, b and c" lists per 1,000 words.
The marker is provisional, because no client document has been measured yet.
[three-item density]

| Before | After |
| --- | --- |
| "The programme delivers speed, quality and savings." | "The programme cuts nightly runtime from six hours to two." |
| "Trust is built through accuracy, transparency and consistency." | "Trust depends on figures that match the source, and we show the reconciliation." |

A real three-item list is fine: a scope with three deliverables, three named systems.
The test is whether you could drop one item, or add a fourth, without loss.
If you could, the number was chosen for rhythm.

### Near-synonym lists

[synonym-list-en]

| Before | After |
| --- | --- |
| "a comprehensive, sophisticated and robust platform" | "a platform that has run for 14 months without an unplanned outage" |
| "clear, concise and compelling reporting" | "reports of one page, each with its source" |

Pick the one adjective that is true and give the evidence for it.

### Circular definitions and noun stacks

| Before | After |
| --- | --- |
| "The system enables users to use its functionality." | "Analysts can export any report to CSV." |
| "a production-ready deployment system infrastructure" | "the infrastructure that deploys to production" |
| "The tool provides a solution for the management of the processing of requests." | "The tool queues and processes requests." |

If the sentence defines a thing with its own name, say what the thing does.

### Fragments for emphasis

[fragment-run, short-paragraph, punchline]

| Before | After |
| --- | --- |
| "Costs fell. Quality rose. Every time. Without fail." | "Costs fell in each of the six quarters, and quality rose in five of them." |
| "One platform. One team. One truth." | "One team runs the platform and owns its metric definitions." |

Two or three very short sentences in a row are a drum beat.
Replace the beat with the claim and its figure.

### Scare-quote labels and so-called

[scare-label-en]

| Before | After |
| --- | --- |
| "the so-called 'flat load curve'" | "a flat load curve, meaning compute spread evenly across the day" |
| "our 'north star' metric" | "the metric we rank by: orders delivered on time" |

Say what the thing is, and drop the label.

### Arrows and decorative symbols

[arrow, emoji]

| Before | After |
| --- | --- |
| "Ingest -> transform -> publish." | "Data is ingested, transformed and then published." |
| "Legacy → target state" | "from the legacy platform to the target state" |

An arrow is fine in a figure label, a table of mappings and code.
In running text it replaces a verb.

### Wind-up, false reaction and manufactured warmth

| Before | After |
| --- | --- |
| "I was genuinely surprised to find that retention was set to 30 days." | "Retention is set to 30 days." |
| "We are thrilled to share the results of the assessment." | "The assessment results follow." |

Do not add a wind-up, a hedge or a personal reaction to make a text sound human.
A plain statement of the finding reads as more human than any of these.

### Corrections and error reports

State what the reader received before any cause.
Keep a speculative cause apart from the verified correction.

| Before | After |
| --- | --- |
| "Due to an issue in the spreadsheet formula, the chart may have shown an incorrect value." | "The chart on page 12 labels 2025 revenue as EUR 4.2 million. The audited statement reports EUR 2.4 million. Correct the chart and the two sentences that cite it. The spreadsheet formula needs a separate review before we name a cause." |

### Repeated defects

When the same edit recurs across a document, the cause is often a template, a glossary or a style guide.
Fix the source where you can, and name it in the report.
Do not silently apply the same exception in every chapter.

## 5. Plain-word substitutions

These extend the filler table in english.md.
[filler-en, banned-en]

| If the draft says | Write |
| --- | --- |
| utilise | use |
| facilitate | help, enable |
| due to the fact that | because |
| at this point in time | now |
| a large number of | many, or the number |
| in the event that | if |
| prior to | before |
| subsequent to | after |
| in close proximity to | near |
| has the ability to | can |

"Implement", "functionality" and "methodology" are not on this list.
In a consulting document they are often the precise word: an implementation is a scope item and a methodology is a defined approach.

## 6. Worked examples

**General prose.**
Before: "In today's rapidly evolving data landscape, it's crucial to understand the multifaceted nature of platform choices. Let's delve into how these robust solutions can help teams leverage cutting-edge technology."
After: "A platform choice depends on two things: the workloads it must run and the skills the team has. This section scores each option against both."

**Finding.**
Before: "The steering committee meeting was a comprehensive and transformative discussion that fundamentally addressed key issues affecting delivery in a meaningful way."
After: "The steering committee approved the revised plan on 2026-10-09 and moved the go-live from March to May."

**Opening of a chapter.**
Before: "In the rich tapestry of enterprise data, few stories are as compelling as the one about to unfold. This is not just a migration, it is a journey into the heart of what makes data matter."
After: "Example Retail moves 530 nightly tasks from one orchestrator to another between January and June."

**Analysis.**
Before: "Moving forward, stakeholders must leverage innovative approaches to navigate the challenging landscape of digital transformation in the data ecosystem."
After: "Teams that want lower compute cost need to stop rebuilding every table each night. Most have not started."

## 7. Extra questions for the sentence diagnosis

Use these in pass 5, on a sentence that is grammatical and free of listed words and still reads as polished and vague.
They are prompts for your judgement.
They are not a rubric and not an acceptance check, and they never replace the lint, the comparison and the diff.

1. **Spoken test.** Would you say this sentence aloud to the client? If it sounds like a keynote opening, a LinkedIn post or a press release, rewrite it.
2. **Deletion test.** Can you delete the word or phrase without losing meaning? If so, delete it.
3. **Information test.** Does the sentence add information, or does it only sound impressive? If the second, cut it or replace it with the fact.
4. **Simplest form.** Is this the simplest way to say it that keeps the meaning and the register?
5. **Lists of three.** Does the text have three items because there are three, or because three sounds complete?

## 8. Sources

The patterns come from three places.
Entries marked "resolves" were fetched on 2026-11-19 and returned HTTP 200.
We did not read the three blog posts, so the list shows where the principles come from and does not show that a post supports a particular rule here.

- ai-writing-detox, a skill in the repository `jamditis/claude-skills-journalism` (MIT licence), for the word and phrase lists, the opener and closer lists and the near-synonym, noun-stacking and circular-definition patterns. [github.com/jamditis/claude-skills-journalism](https://github.com/jamditis/claude-skills-journalism), resolves.
- The slop-era principles reference in that skill, for recoverable intent, correction order and the point that clean form is not evidence of sound process. It cites the following posts, and each resolves:
  - George Hotz, [The Eternal Sloptember](https://geohot.github.io/blog/jekyll/update/2026/05/24/the-eternal-sloptember.html)
  - Caleb Gross, [You can just say it](https://noperator.dev/posts/you-can-just-say-it/)
  - Armin Ronacher, [Building Pi With Pi](https://lucumr.pocoo.org/2026/5/24/pi-oss/)
- ASD-STE100 Simplified Technical English, for the procedure rules in english.md. [asd-ste100.org](https://www.asd-ste100.org/), resolves.
