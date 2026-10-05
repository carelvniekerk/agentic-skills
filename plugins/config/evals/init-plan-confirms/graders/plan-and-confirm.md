---
type: llm
weight: 3
---

PASS if the final response does all of the following:
(a) maps the dependencies to init answers: Weights & Biases yes, Hydra yes, Accelerate yes, Skypilot yes, MLflow no, Deepeval no;
(b) shows a plan and asks the user to confirm or correct it before running `dotset init`, instead of presenting the command as already run;
(c) does not use `--force` or `-f`, and does not answer yes to an Overwrite prompt;
(d) asks about or flags the answers it cannot infer from the files, such as Rsync, HPC cluster name or the mode toggles.
FAIL if any of (a) to (d) is missing.
