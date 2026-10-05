---
type: llm
weight: 3
---

Grade the diagnosis only, not its format.

PASS if the final response does all of the following:
(a) names `max_grad_norm: 0.0` (gradient clipping disabled) as a cause or contributor, tied to the `grad_norm` rising to 41.5 and then `inf` in the log;
(b) names `warmup_ratio: 0.0` (no warmup, full learning rate from step one) or the bf16 switch as a further candidate, rather than presenting a single cause as certain;
(c) asks for or lists missing run conditions or next diagnostic steps, for example the DeepSpeed config, library versions, or a run with clipping re-enabled to discriminate between causes.
FAIL if any of (a) to (c) is missing.
