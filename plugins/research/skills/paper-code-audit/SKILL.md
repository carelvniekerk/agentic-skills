---
name: paper-code-audit
description: >-
  Audit a research paper's claims against its code repository: clones the repository, maps every method, hyperparameter, metric and data-handling claim to file:line evidence, and classifies mismatches, omissions and reproducibility risks by severity.
  Use when the user asks to audit a paper against its code, check whether an implementation matches what was published, or assess whether a paper is reproducible from its repository.
argument-hint: <paper URL, arXiv ID or path> <repository URL>
effort: high
disable-model-invocation: true
allowed-tools: WebSearch WebFetch Read Glob Grep Write Bash(mkdir *) Bash(git clone *) Bash(git -C * rev-parse HEAD) Agent
---

# Paper-code audit

You compare a paper's claims with the code that is meant to implement them and deliver an audit at `<output>/<slug>-audit.md`.
Every mismatch cites `file:line` in a clone of the repository at a recorded commit, so the evidence is the code itself, never a web summary of it.
The skill reads and clones, and it never runs the repository's code or installs its dependencies.

Take the scratch directory (default `research_scratch/`) and the output directory (default `output/`) from the project's `CLAUDE.md`.
Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, your messages included, and pass its full contents in every agent brief.

The worst finding goes in the first line of your message and the opening paragraph of the audit.
A deviation confirmed at `file:line` is a finding.
A deviation suspected because a file is absent is labelled `[Likely]` or `[Guessing]` and listed as unverified.

## Contents

- Workflow
- 1. Identify the targets
- 2. Clone the repository
- 3. Gather evidence
- 4. Classify findings
- 5. Write the audit
- 6. Verify and cite
- 7. Deliver
- Gotchas
- Strict prohibitions

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Audit progress:
- [ ] 1. Paper and repository identified, paper version noted
- [ ] 2. Repository cloned, commit recorded
- [ ] 3. Claims and code evidence gathered by research:researcher
- [ ] 4. Findings classified by you, saved to the findings file
- [ ] 5. Audit drafted by research:writer
- [ ] 6. Draft verified and cited by research:verifier
- [ ] 7. Delivered, blocking findings first, unchecked claims named
```

## 1. Identify the targets

Take the paper (arXiv ID, URL or path) and the repository from the arguments.
If only one is given, find the other: the repository link is usually in the paper's abstract page, footnotes or code availability statement.
Note the paper version you audit, for example arXiv v2, because later versions often change hyperparameters.

## 2. Clone the repository

```bash
mkdir -p <scratch>
git clone --depth 1 <repository-url> <scratch>/<slug>-repo
git -C <scratch>/<slug>-repo rev-parse HEAD
```

Record the commit hash for the audit.
If the repository has a tag or release named for the paper or its venue, say so and ask whether to audit that instead of the default branch.

## 3. Gather evidence

Spawn a `research:researcher` agent with:

- The paper reference and the local clone path `<scratch>/<slug>-repo`.
- Task one: extract from the paper the claimed methods, architectures, algorithms, default hyperparameters, training details, metrics, datasets, evaluation protocols, data handling and ablations, each with its section, table or equation number.
- Task two: for each claim, find the corresponding code in the clone with `Glob`, `Grep` and `Read`, and record it as `path:line` with the relevant lines quoted.
- The rule that code evidence comes from the clone only, never from `WebFetch` of the repository's web pages.
- Output files: `<scratch>/<slug>-claims.md` and `<scratch>/<slug>-code.md`.
- The full contents of `house-style.md`.

## 4. Classify findings

Read both files and label each claim yourself, because classification is the judgement this audit exists for:

| Severity | Meaning |
| --- | --- |
| CRITICAL | The code does something materially different from a core claim, so the results may not reproduce |
| MODERATE | A meaningful deviation, such as a different default hyperparameter or an undocumented preprocessing step |
| MINOR | An inconsistency unlikely to affect results, such as naming |
| MISSING | Described in the paper with no corresponding code |
| MATCH | Confirmed by the code |

Before labelling a CRITICAL or MODERATE finding, open the cited `path:line` yourself and confirm it.
Save the classified list to `<scratch>/<slug>-findings.md`.

## 5. Write the audit

Spawn a `research:writer` agent with:

- The findings file and both evidence files, and the draft path `<scratch>/.drafts/<slug>-audit-draft.md`.
- The full contents of `${CLAUDE_SKILL_DIR}/references/audit-format.md`, which the writer follows exactly.
- The full contents of `house-style.md`.
- The rules: preserve every `path:line` verbatim, do not weaken or reorder findings, name each hyperparameter, function and file as the code does and each symbol as the paper does, and add no citations.

## 6. Verify and cite

Spawn a `research:verifier` agent with:

- The draft path, both evidence files, the paper URL and the repository URL as the source pool, and the final path `<output>/<slug>-audit.md`.
- Citation format: Markdown footnotes `[^N]`, with the paper and repository URLs checked.
- The rule that `path:line` references are internal evidence, not citations, and stay untouched.
- The full contents of `house-style.md`.

## 7. Deliver

Report the verdict with the blocking findings first, then the judgement calls behind the severity labels, then the claims you could not check and why.

## Gotchas

- A shallow clone has no history, so `git log` cannot tell you when a hyperparameter changed; say so if the paper's version predates the commit.
- Defaults in a config file can be overridden by a launch script or command-line flags in a `README`, so check both before calling a hyperparameter a mismatch.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Running the repository's code, scripts or installers | Executes untrusted code as the user |
| A `file:line` reference not read from the clone | `WebFetch` summaries invent line numbers |
| A CRITICAL label you did not confirm at the cited line | The audit's verdict rests on it |
| Auditing without recording the commit | The findings cannot be reproduced |
