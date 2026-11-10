# English reference

How English client documents at MULTIPLAI should read, and how to get a draft there.
The rules are British English in a German business context.
The exemplars are anonymised from a signed statement of work and a 90-page data architecture assessment that the team considers good writing.
Where the two documents slip, the slip is shown as a before and after.

## Contents

- 1. Register by genre
- 2. Calibrating claims
- 3. Patterns with before and after
- 4. Vocabulary
- 5. Locale and mechanics
- 6. German interference in English
- 7. Contract language
- 8. What good looks like

## 1. Register by genre

| Genre | Actor | Verbs | Qualifiers | Lists | Notes |
| --- | --- | --- | --- | --- | --- |
| Contract or statement of work | The defined parties: "MULTIPLAI", "the client", "the parties" | Present tense for services ("MULTIPLAI validates"), "shall" for obligations | None on commitments | Closed, parallel, verb-first | Restating a clause can be deliberate, so leave it and flag it |
| Proposal | "we" and the client by name | "will" for what we commit to | Only on assumptions and dependencies | Closed for scope and deliverables | Order each section as client need, then what we do, then proof |
| Assessment or report | "we" or "the assessment", one of the two throughout | Past tense for what was measured, present for what holds | On hypotheses and on evidence gaps, said once | Parallel, open lists allowed in prose | Every finding carries its evidence and a cross-reference |
| Executive summary | "we" | Present and imperative | As in the body, never fewer | Short, ranked | Answer in the first two sentences, plainer words than the body |
| Email | "I" or "we" | Imperative for requests, with a date | Minimal | Rarely | Recommendation or request in the first two lines |
| Slide text | Implicit | Titles are full assertions of at most about 15 words | As in the source | Bullets prove the title | Every bullet supports its title, and the titles read in sequence tell the story |

Write MULTIPLAI in capitals in every genre.
Humour, exclamation marks and analogies used for colour stay out of client documents.
An analogy that explains a mechanism is allowed in a report or a workshop document, but never in a contract.

## 2. Calibrating claims

The test for every sentence is what the evidence supports.

| Kind | Overstated | Softened | Calibrated |
| --- | --- | --- | --- |
| Commitment | "MULTIPLAI guarantees a seamless migration." | "MULTIPLAI can usually support the migration." | "MULTIPLAI delivers the migration plan by 2026-10-09." |
| Finding | "The platform is fundamentally broken." | "The platform might have some reliability issues." | "Three of 30 nightly runs finished in under ten minutes while reporting success." |
| Hypothesis | "The runs skip their sensors." | "It could potentially be the case that sensors may be skipped." | "A skipped sensor chain would explain this. It is a hypothesis, and we recommend verifying it first." |
| Recommendation | "The client must immediately replace Airflow." | "It might be worth considering looking at alternatives." | "Keep Airflow for orchestration and move the transformations to a framework during the Data Vault build." |
| Evidence gap | "Costs are attributed correctly." | "Costs may not be fully attributed." | "Resource-level cost was not available to the assessment, so spend cannot be attributed to datasets." |

Two habits do the most damage.
Adding "often", "usually", "might" or "can" to every claim makes the whole document sound unsure, including the parts that are measured.
Dropping a qualifier during editing turns a hypothesis into a finding, which the client may act on.

A stakeholder statement and an observation are different evidence.
Keep them apart in wording: "The client's team states that the maintainer has moved on. We could not confirm the date of the last commit."

## 3. Patterns with before and after

### Words

| Pattern | Before | After |
| --- | --- | --- |
| Intensifier | "has enabled a genuinely broad portfolio of use cases" | "has enabled a broad portfolio of use cases" |
| Intensifier as evidence substitute | "This is a really important dependency." | "Two staging tables gate 96 downstream objects." |
| Copula avoidance | "The workbook serves as the reconciliation contract." | "The workbook is the reconciliation contract." |
| Nominalisation | "MULTIPLAI performs an evaluation of the options." | "MULTIPLAI evaluates the options." |
| Inflated vocabulary | "a pivotal step in the client's data journey" | "the step that the SAP cutover depends on" |
| Metaphor where the noun works | "a permanent tax on developer machines" | "a permanent cost on every developer machine: emulation and architecture workarounds" |
| Vague magnitude | "significant savings" | "a saving of 35 to 70 % on the affected datasets" |
| Invented label in quotes | "the so-called 'flat load curve'" | "a flat load curve, meaning compute spread evenly across the day" |

### Sentences

| Pattern | Before | After |
| --- | --- | --- |
| Antithesis with no live alternative | "The largest opportunity is not a platform migration and not a tooling purchase. It is the move to incremental updates." | "The largest opportunity is the move from nightly full rebuilds to incremental updates. It needs neither a new platform nor a new tool." |
| Punchline ending | "The concern is the supply chain, not the concept." | "The approach is sound. The risk is in how the binary is obtained: it is downloaded at build time without a checksum." |
| Rhetorical beat with no mechanism | "The pattern is the deliverable, not the domain." | "The pilot is meant to prove a pattern that other domains can reuse." |
| Defensive negation | "This is a sequencing decision and not an argument against the capability." | "We recommend the capability, after the Explores are consolidated." |
| Signpost | "One point deserves emphasis before the detail begins." | Delete it and start with the point. |
| Trailing participle comment | "Costs fell by 21 %, highlighting the value of the change." | "Costs fell by 21 %." |
| Colon-then-reveal | "The result: chaos." | "As a result, 12 tiles titled AOV resolve to 11 different definitions." |
| Impersonal evaluation | "It is recommended that retention is shortened." | "We recommend shortening retention to 48 hours." |
| Hidden actor | "The decision was taken to defer the bridge tables." | "The BI team deferred the bridge tables." |
| Contradiction | "Underneath both problems lies one technical pattern among others." | "Underneath both problems lies one technical pattern." Report the contradiction if the author meant several patterns. |
| Broken sentence | "The mechanism could be is a skipped sensor chain." | "The mechanism could be a skipped sensor chain." |
| Compression | "Rebuild-heavy-dataset retention-window shortening precedes billing-model switching." | "Shorten the retention window on rebuild-heavy datasets before switching their billing model." |

### Verbs and subjects

The lint cannot find these, because the sentences contain no listed word.
They read as fluent and say less than they seem to, so the diagnosis step in the skill looks for them sentence by sentence.

| Pattern | Before | After |
| --- | --- | --- |
| Human verb on a thing | "Each box carries the slide's wording, and its panel names the suggested technology." | "Each box repeats the slide's wording, and its panel gives the suggested technology." |
| Human verb on a thing, actor available | "Each tool receives two scores from 1 to 5 for the feature that carries the capability." | "We score each tool twice on a scale of 1 to 5, for the feature that provides the capability." |
| Layout described instead of the fact | "Four columns, eight numbered zones, drawn from the 2026-09-14 target slide." | "The diagram has four columns and eight numbered zones, taken from the target slide of 2026-09-14." |
| Reading rule in borrowed verbs | "Bold marks a tool that covers more than one zone or job." | "A tool in bold supports more than one zone or job." |
| Position described | "Options with the same scores sit side by side, and Cloud Run appears under both Zone 2 and Zone 4 because it serves both." | "Options with the same scores are listed side by side. Cloud Run is listed under Zone 2 and Zone 4 because it supports both." |

Verbs to check when the subject is a thing, a part of the document or a feature: carries, holds, names, receives, sits, lives in, covers, houses, hosts (for a non-technical subject), serves, marks, lands, feeds, gates, backs, answers, speaks to, reads as, stands for, appears under, drawn from.
They are `check` candidates and not errors.
"Cloud Run hosts applications" and "the server stores runs" describe what the system does and stay.
"A box carries wording" and "a panel names a technology" do not.

Replacements, in order of preference:

1. The person as subject, where the source supports one: "we score", "the team reviews".
2. A literal verb that keeps the thing as the subject: is, has, shows, lists, repeats, gives, contains, uses, supports, provides.
3. A sentence about the fact instead of the structure, when the sentence only describes the layout.

A sentence that opens a section or caption without a verb ("Four columns, eight numbered zones.") becomes a full sentence.
A fragment is fine in a list item, a table cell and a slide title.

Do not move the subject to a person without checking the source: a slide that names a technology and a team that names it are different statements.

### Paragraphs

- A one-sentence paragraph used for emphasis joins the paragraph it belongs to, or becomes its first sentence.
- A closing sentence that is shorter and punchier than the rest of its paragraph usually goes, and the previous sentence becomes the ending.
- A paragraph that only previews what follows ("This section describes...") goes when the heading already says it.
- A section that ends on an ironic or fatalistic note ends instead on what the reader can do, with an owner where one exists.
- A closing paragraph that restates the whole document goes, except in an executive summary or a closing observation that the template requires.

### "Rather than" and its relatives

One 90-page assessment used "rather than" about five times per 1,000 words.
Each instance reads well alone, and together they give the text a fixed rhythm of claim and foil.
Keep "rather than" where the alternative is one the reader would otherwise assume ("fixed price rather than time and materials").
Elsewhere, state the claim alone, or use "instead of" once or twice for variety.

## 4. Vocabulary

### Banned, with replacements

| Word | Use instead |
| --- | --- |
| delve, deep dive | examine, analyse, a detailed review |
| leverage, harness | use, apply, build on |
| unlock, elevate, empower | enable, raise, allow, or the concrete effect |
| seamless | without manual steps, without downtime, or the specific property |
| holistic | end-to-end, across all five layers, or the actual scope |
| robust | reliable, tested against X; keep "robust" for statistics |
| pivotal, crucial | the consequence: "the cutover depends on it" |
| underscore, showcase, testament to | show, or cut the sentence |
| foster | build, encourage, or the concrete mechanism |
| landscape, ecosystem, realm, tapestry | estate, set of systems, environment, or the list |
| journey | programme, transformation, or the phases by name |
| game-changer, transformative, cutting-edge, state-of-the-art, best-in-class, world-class, future-proof | the measurable advantage, or nothing |
| synergy | the specific saving or shared component |
| navigate, tackle, streamline | handle, resolve, simplify, or the action |
| boasts | has |
| meticulous, intricate, multifaceted, vibrant | careful, detailed, complex, or cut |
| quietly, steady, dependable | cut, or give the measurement |

### Watch words

Keep these only in their precise sense: key (legitimate in "primary key"), significant (statistical significance), substantial, critical (critical path), comprehensive, actionable (legitimate in a module name), insights, evolving, notably, moreover, furthermore, additionally, overarching, drive (as a verb of causation it is fine: "this pattern drives both halves of the bill").

### Filler and bureaucratic phrases

| Phrase | Use instead |
| --- | --- |
| in order to | to |
| with regard to, with respect to, in terms of | about, for, or restructure |
| the fact that | that |
| a number of | several, or the number |
| in the context of | in, for, during |
| it is worth noting that, it is important to note that, it should be noted that | delete |
| the aforementioned | the, this, or the name |
| in the event that | if |
| going forward, moving forward | from now on, from Q3, or delete |
| that said | but, however, or delete |

## 5. Locale and mechanics

**Spelling.**
British spelling with -ise endings: organisation, prioritise, standardised, analyse, modelling, labelled, cancelled, travelled, behaviour, favourable, colour, centre, catalogue, defence, artefact, judgement, fulfil, enrol, towards.
"Programme" for a body of work, "program" for software.
"Licence" is the noun and "license" the verb.
A client who requires US spelling or Oxford -ize spelling overrides this, and the report says so.

**Dates and times.**
YYYY-MM-DD in running text and tables: 2026-07-31, never "July 31st, 2026" or "31.07.2026".
Ranges with a hyphen: 2026-09-01 to 2026-11-30, or 2019-2024 for years.
24-hour clock: 07:00, 23:30.
A contract template that prescribes another date format is a client convention, so keep it consistent and say so.

**Numbers.**
Thousands with a comma and decimals with a point: 1,250 and 43.7.
Spell out zero to nine in running text, but use digits with units, in tables, in ranges and in names such as Phase 1.
Do not start a sentence with digits.
Round consistently within a table and between a table and the text that cites it.

**Percentages and currency.**
Use one percentage form per document: "%" by default, or "per cent" if the document uses it throughout.
Write currency as "EUR 24,450" or "€24,450", one form per document, and never the German "€ 24.450,-" in English text.

**Punctuation.**
No em or en dashes as punctuation, and no spaced hyphen as a substitute.
Avoid semicolons in client prose by splitting the sentence or using a colon before a list.
Use the serial comma only where a sentence is ambiguous without it.
No exclamation marks.
Straight or curly quotation marks, one style per document, with single quotes inside double.

**Headings.**
Sentence case, keeping the capitals of proper nouns and the client's defined terms ("Data Vault", "Semantic Layer").
Headings may carry an idea ("Pre-production cannot yet verify a significant change") where the template allows it.
Check heading numbering for gaps such as 8.9 followed by 8.11.

## 6. German interference in English

Native German writers produce predictable errors in English, and a German author's draft is worth checking for each of these.

| German | Error in English | Correct |
| --- | --- | --- |
| aktuell | actual | current |
| eventuell | eventual, eventually | possible, possibly |
| sensibel | sensible | sensitive |
| realisieren | realise (in the sense of carry out) | implement, deliver |
| Konzept | concept (for a design document) | design, plan, approach paper |
| Konzern | concern | group, corporate group |
| Controlling | controlling | financial planning and analysis, management accounting |
| Management Summary | management summary | executive summary |
| im Rahmen von | in the frame of | as part of, during |
| seit drei Monaten | since three months | for three months |
| bis Freitag | until Friday (for a deadline) | by Friday |
| Mai, E-Mail | Mai 1, E-Mail | May 1 (or 2026-05-01), email |
| 1.250 / 43,7 | 1.250 / 43,7 | 1,250 / 43.7 |

German sentence habits also carry over: long sentences with the main point in the middle, systematic passive with no actor ("the decision was taken"), noun chains ("the realisation of the implementation of the migration"), and understatement of a good result ("results were satisfactory").
Split the sentence so the main point comes first, name the actor, and use the verb.

Converted company data needs the same care.
A German address keeps its German spelling, but write it the same way everywhere: one of "Mergenthalerallee" and "Mergenthaler Allee", and one of "Bahnhofstraße" and "Bahnhofstrasse".

## 7. Contract language

A statement of work mixes a description of services with obligations, and the verbs show which is which.

- "MULTIPLAI validates", "MULTIPLAI delivers": present tense describes the services.
- "shall" imposes an obligation on the subject of the sentence: "Invoices shall be paid within 30 calendar days of receipt" is weaker than "The client shall pay each invoice within 30 calendar days of receipt", because the second names who is obliged.
- "may" grants discretion: "Either party may terminate".
- "is deemed" or "shall be considered" creates a legal fiction, as in deemed acceptance after five business days.

[Likely] This follows the categories of contract language in Kenneth Adams' A Manual of Style for Contract Drafting.
The categories were not checked against the book when this reference was written, so treat this as a summary of the convention and verify a contested case in the source.

What the copyedit does in a contract:

- It fixes typos, inconsistent defined terms, number formats that do not match, and arithmetic that does not reconcile (reported, never silently corrected).
- It flags, but does not change, an obligation without a named party, a capacity figure that is ambiguous ("up to 200 % FTE" for one role), and a clause restated three times.
- It leaves negotiated vagueness alone: "reasonable", "timely", "adequately qualified" and "material" are agreed words.

Check every price table: module prices, discount, total and the invoice schedule must reconcile, and a discount reallocated between milestones has to be stated.

## 8. What good looks like

These lines are anonymised from the two exemplar documents, with the reason each one works.

**Answer first.**
"The objective of this engagement is to establish the decision foundation for the client's future AI and ML platform: an actionable requirements baseline, a validated platform direction with a target architecture, and a target operating model that defines who owns, builds and runs the platform."
The reader knows the outcome, the three outputs and their order before any background.

**Concrete complication.**
"Experiment tracking relies on local MLflow instances, and there is no model registry, promotion pipeline or model monitoring."
Named tools and named gaps do the work that "immature MLOps capabilities" would only claim.

**Closed scope with a pointer.**
"This Statement of Work covers advisory services only. No installation, configuration or deployment work is in scope. Implementation and rollout can be scoped separately."
The exclusion carries the same weight as the inclusion, and the reader knows where the excluded work goes.

**A reason before the activities.**
"Before any decision on architecture and technology, MULTIPLAI structures the starting point and engineers an actionable requirements list. This ensures the evaluation is driven by the client's needs and not by vendor narratives."
Then three verb-first bullets: capture, structure, prioritise.

**Honest sizing.**
"The module is deliberately lightweight and fast, given the client's timeline."
It admits a constraint and ties it to the client's reason.

**Decision logic the reader can predict.**
"Where the preferred platform is good enough, it remains the default. Where material gaps exist, MULTIPLAI assesses their severity and the options to close them."

**Status kept apart from recommendation.**
"None of the items in this table is a recommendation of this report."
One caption stops the client from reading work already under way as advice.

**Evidence labelled by kind.**
"The stakeholder statement and the observed evidence are deliberately kept separate."
"This is offered as an observation to be verified and not as a settled finding."

**Fair to the people who built the system.**
"None of this is a criticism of the engineering. The existing system works, and several of the design choices were defensible when they were made."
It states the finding at its actual size, and the client's team keeps reading.

**Method and limitations stated.**
A known-limitations list that names what the analysis could not see, why, and whether it changes a finding ("The comparison between billing models is sound. The absolute saving requires billing data.").

**Arithmetic shown once.**
"Adding all rows together counts the same work twice and overstates compute by about 60 %. Every compute figure in this report counts each unit of work exactly once."
