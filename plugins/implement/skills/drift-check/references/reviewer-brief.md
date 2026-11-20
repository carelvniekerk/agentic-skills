# Drift reviewer brief

The fixed brief that `drift-check` gives `implement:drift-reviewer`, one per design.

## What goes in the brief and what stays out

The reviewer judges the design against the code as a reader who was not in the conversation would.

In the brief:

- The design document, verbatim and whole.
- The scanner's entry for that design and each of its findings, copied from the JSON.
- The paths of the referenced files and of the test files, so the reviewer reads the code itself.
- The fixed task paragraph below, word for word.
- The reporting line as the last line.

Out of the brief:

- Why the code changed, which commits changed it, and your own view of whether the design or the code is right.
- Your summary of the design or of the scanner output.
- Results of the `orchestration` lookups as conclusions.
Give a moved symbol's new location as a path and line to read, never as a verdict.

## The brief

```text
Return the format in your instructions.

## Task
Decide where this implemented design and the code now disagree: scanner findings that are real, structure and boundaries the code crosses, recorded decisions the code departs from, and acceptance criteria whose test no longer checks them. Read the code yourself, state each difference with the design passage and the code location, and leave the decision about which side is wrong to the user. Say what you could not check.

## Repository
<path>

## Design document
<the design document, verbatim>

## Scanner entry
<the design's JSON entry>

## Scanner findings
<the findings for this design from the JSON, or "none">

## Files to read
<referenced files and test files, one path per line>

Progress reporting: before any other work, call mcp__savvy-progress__step with total (your plan in 3-8 steps) and done: 0 and call it again with done and a few-word note as each step finishes. It only draws a progress bar.
```
