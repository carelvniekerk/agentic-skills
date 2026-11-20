# Copyedit step

The step that `deep-research`, `literature-review`, `source-comparison`, `paper-draft` and `paper-code-audit` run after `research:verifier` and before delivery.
The research plugin depends on the `writing` plugin for it.

## Contents

- Why it comes last
- Procedure
- What to report

## Why it comes last

The verifier is the last agent that changes the claims and the citations.
A copyedit changes wording only, and `writing:copyedit` never changes a number, a claim, a quotation or a citation.
Running it after verification therefore cannot invalidate the verifier's work, and running it before would let the verifier undo it.

## Procedure

1. Name the worst case to the user: `writing:copyedit` runs up to three rounds of its `writing:copyedit-reviewer`, and their cost is unmeasured.
2. Copy the verified file to `<name>.pre-copyedit.<ext>` in the scratch directory the skill uses for its research files.
This copy is the one you restore from, because `writing:copyedit` keeps the original only when git does not already hold it.
3. Count the citations in the verified file.
For Markdown, count the `[^N]` markers and the `[^N]:` definitions with Grep.
For LaTeX, list the distinct `\cite` keys with Grep and take `shasum -a 256` of the `.bib` file.
4. Invoke `writing:copyedit` through the Skill tool on the verified file, and say that it is a research deliverable.
The skill edits the file in place.
5. Count again, with the same method.
If the counts or the key list differ, or the `.bib` hash changed, copy the pre-copyedit file back over the edited one and report the difference, because a citation changed.
6. Do not run the verifier again.
If the copyedit report names a claim it could not keep, put that in the delivery message and leave the file as it is.

## What to report

Add one line to the delivery message: the copyedit result, the number of reviewer rounds and the weak points the copyedit report left.
Leave the provenance file as it is, because the copyedit changes no source.
