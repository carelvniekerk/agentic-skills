---
name: paper-code-audit
description: >
  Compare a research paper's claims against its public codebase — identifies mismatches, omissions, undocumented deviations, and reproducibility risks.
  Use this skill whenever the user asks to audit a paper, check code-claim consistency, verify reproducibility, or wants to know whether an implementation actually matches what was published.
when_to_use: >
  Trigger phrases: "audit this paper", "check the code", "does the implementation match", "verify reproducibility",
  "code vs paper", "is the code consistent with the paper", "check the repo against the paper",
  "reproducibility check", "what deviates from the paper", "does the code do what the paper claims".
argument-hint: <paper-url-or-arXiv-ID> <repo-url>
allowed-tools: WebSearch WebFetch Read Write Bash(mkdir *) Agent
disable-model-invocation: true
---

# Paper–Code Audit

Compare a research paper's claims against its public codebase.
Identifies mismatches, omissions, and reproducibility risks.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing anything, including your messages to the user.
It carries the advisor stance, the truthfulness and confidence rules, the register and the phrasing blacklist that govern every artefact this skill produces.

Two consequences for how you run this workflow.
Lead with the worst finding: if a CRITICAL mismatch exists, it goes in the first line of your message to the user and in the opening paragraph of the audit, not in a table halfway down.
Distinguish what you read from what you inferred. A deviation you confirmed at `file:line` is a finding; a deviation you suspect because a file is absent is labelled `[Likely]` or `[Guessing]` and named as unverified.

Check `CLAUDE.md` for the project's output directory (default: `output/`).

## Workflow

### 1. Identify Targets

Determine:

- The paper — arXiv ID, URL, or local file path.
- The code repository — GitHub URL, or locate it from the paper's text.

If the user provided both as arguments (`$ARGUMENTS`), parse them directly.
If only one was provided, locate the missing one before proceeding.

### 2. Gather Evidence

Spawn a **`research:researcher`** agent.
Include in its brief:
- The paper (URL, arXiv ID, or path) and the repo (URL or path).
- Task: extract from the paper — claimed methods, architectures, algorithms, default hyperparameters, training details, reported metrics, datasets, evaluation protocols, data handling, ablations/variants.
- Task: inspect the repository and document, for each paper claim, the corresponding code behaviour with `file:line` references.
- Output files: `<scratch>/<slug>-claims.md` (paper claims) and `<scratch>/<slug>-code.md` (code behaviours mapped to claims).
- Reminder: every claim and every code reference must include a verifiable URL or `file:line` location.

### 3. Classify Findings

Read both research files.
For each paper claim, compare against the documented code behaviour and label by severity:

| Severity | Meaning |
| -------- | ------- |
| **CRITICAL** | The code does something materially different from the paper's core claim — results may not be reproducible |
| **MODERATE** | A meaningful deviation (e.g. different default hyperparameter, undocumented preprocessing step) |
| **MINOR** | Small inconsistency unlikely to affect results (e.g. naming difference, cosmetic variation) |
| **MISSING** | Something described in the paper has no corresponding code |
| **MATCH** | Claim confirmed by the code |

Classification is Claude's judgment call — it is not delegated.
Save the classified finding list to `<scratch>/<slug>-findings.md`.

### 4. Write the Audit

Spawn a **`research:writer`** agent.
Include in its brief:
- The findings file from step 3 and both research files from step 2.
- Draft save path: `<scratch>/.drafts/<slug>-audit-draft.md`.
- The full audit template below — the writer must follow it exactly.
- Writing rules: each sentence on its own line; preserve `file:line` references verbatim; do not weaken or reorder findings; do not add citations (the verifier handles that).
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/house-style.md`. The register, phrasing blacklist and punctuation rules bind the writer. Name each hyperparameter, function and file exactly as the code does, and each symbol exactly as the paper does; never paraphrase an identifier.

Audit template:

```markdown
---
tags: [paper-audit, reproducibility]
type: notes
date_added: YYYY-MM-DD
date_updated: YYYY-MM-DD
sources: 2
source_type: technical
---

# Audit: [Paper Title]

![Type](https://img.shields.io/badge/type-paper--audit-orange) ![Added](https://img.shields.io/badge/added-YYYY--MM--DD-lightgrey)

One paragraph summarising the paper's central claim and the overall reproducibility verdict.

## 🎯 Key Takeaways

- 3–5 bullets summarising the most important audit findings.

## Paper and Repository

- **Paper:** [Title — Authors (Year)](https://url)
- **Repository:** [org/repo](https://github.com/url)
- **Commit audited:** `<git-sha>` (if determinable)

## ✅ Matches

- **[M1]** Claimed X; code implements X correctly. `file.py:line`

## ❌ Mismatches

- **[CRITICAL — X1]** Paper claims Y, but code does Z. `file.py:line`
- **[MODERATE — X2]** Default learning rate is 1e-4 in paper, 3e-4 in code. `config.py:42`
- **[MINOR — X3]** Variable named differently from paper notation. `model.py:17`

## 🕳️ Missing

- **[G1]** No evaluation script provided for the main benchmark.
- **[G2]** Data preprocessing pipeline described in §3.2 is not in the repository.

## 🔬 Reproduction Risk Assessment

**Overall verdict:** High / Medium / Low reproducibility risk.

Explain which findings drive the verdict and what a practitioner would need to do to successfully reproduce the results despite the gaps.

## 🔮 Open Questions

- Questions raised by the audit that the paper and code together do not answer.

## Sources

- [Paper title](https://url)
- [Repository](https://github.com/url)
```

### 5. Verify and Cite

Spawn a **`research:verifier`** agent.
Include in its brief:
- Draft path: `<scratch>/.drafts/<slug>-audit-draft.md`.
- Source pool: both research files from step 2 plus the paper URL and repo URL.
- Final output path: `<output>/<slug>-audit.md`.
- Citation format: markdown footnotes `[^N]`. The paper URL and repo URL must be verified to resolve.
- Internal `file:line` references must not be modified — they are not external citations and the verifier should leave them in place.
- The full contents of `${CLAUDE_PLUGIN_ROOT}/references/house-style.md`. Any wording the verifier rewrites must still obey the register and punctuation rules.

### 6. Deliver

Report the verdict to the user with the blocking findings first.
List the judgement calls behind the severity labels, and say explicitly which claims you could not check at all, for instance because the repository omits the code path or because the audited commit does not match the paper's version.
