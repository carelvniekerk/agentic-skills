---
type: llm
weight: 1
---

Grade the report contract only, not the diagnosis.

PASS if the final response does all of the following:
(a) presents ranked hypotheses, each with a confidence label and a stated mechanism;
(b) does not present a code or config patch as its main deliverable;
(c) does not claim to have read files, run commands or opened URLs that the transcript does not show.
FAIL if any of (a) to (c) is missing.
