# Audit format

The template for the audit that `research:paper-code-audit` delivers at `<output>/<slug>-audit.md`.
The `research:writer` agent follows it exactly.

````markdown
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

One paragraph stating the overall reproducibility verdict and the worst finding first, then the paper's central claim.

## 🎯 Key Takeaways

- At most five bullets on the most important findings, CRITICAL ones first.

## Paper and repository

- **Paper:** [Title, Authors (Year)](https://url), version audited (for example arXiv v2)
- **Repository:** [org/repo](https://github.com/org/repo)
- **Commit audited:** `<git-sha>`

## ❌ Mismatches

- **[CRITICAL, X1]** The paper claims Y, and the code does Z. `train.py:118`
- **[MODERATE, X2]** The paper gives a learning rate of 1e-4, and the default is 3e-4. `config.py:42`
- **[MINOR, X3]** The variable name differs from the paper's notation. `model.py:17`

## 🕳️ Missing

- **[G1]** No evaluation script for the main benchmark.
- **[G2]** The preprocessing described in §3.2 is not in the repository.

## ✅ Matches

- **[M1]** The paper claims X, and the code implements X. `file.py:line`

## Not checked

- Claims the audit could not test, and why (code path absent, data unavailable, paper version and commit do not correspond).

## 🔬 Reproduction Risk Assessment

**Overall verdict:** High, Medium or Low reproducibility risk.

Which findings drive the verdict, and what a practitioner would need to do to reproduce the results despite the gaps.

## 🔮 Open Questions

- Questions the paper and the code together do not answer.

## Sources

- [Paper title](https://url)
- [Repository](https://github.com/org/repo)
````
