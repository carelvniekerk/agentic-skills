---
description: Peer review of a pasted paper excerpt with test-set checkpoint selection and an all-benchmarks claim its own table contradicts.
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write]
tags: [peer-review, reviewer, effect, hard]
---

Peer review this before I submit it to NeurIPS. It's the abstract, setup and main table of my draft.

> **Abstract.** We introduce GateLoRA, a gated low-rank adapter that routes each token through one of four LoRA experts. GateLoRA achieves state-of-the-art results on all five reasoning benchmarks we evaluate, outperforming full fine-tuning while training 0.4% of the parameters.
>
> **Setup.** We fine-tune Llama-3-8B on MetaMathQA for 3 epochs with learning rate 2e-4. For each method we keep the checkpoint with the best accuracy on the benchmark test sets. All results are from a single run with seed 0.
>
> **Table 2.** Accuracy (%).
>
> | Method | GSM8K | MATH | ARC-C | StrategyQA | BBH |
> | --- | --- | --- | --- | --- | --- |
> | Full fine-tuning | 71.2 | 24.8 | 79.6 | 68.9 | 51.3 |
> | LoRA | 69.8 | 23.9 | 78.1 | 69.4 | 50.2 |
> | GateLoRA (ours) | 72.5 | 25.6 | 79.1 | 69.7 | 52.0 |
