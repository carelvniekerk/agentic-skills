---
description: NaN loss under bf16 with ZeRO-3 and gradient checkpointing. The skill should diagnose with ranked hypotheses and ask for missing run conditions, not patch.
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
tags: [bug-discovery, diagnosis, ml]
---

My SFT run goes NaN and I can't see why. It's fine for the first ~300 steps, then the loss jumps and goes nan. Started after I switched from fp16 to bf16 and turned on gradient checkpointing. You can't see my machine, so here's what I have.

```text
$ accelerate launch --config_file configs/zero3.yaml train.py --config configs/sft_qwen.yaml
...
[2026-10-01 14:02:11] WARNING  `use_cache=True` is incompatible with gradient checkpointing. Setting `use_cache=False`.
[2026-10-01 14:02:12] UserWarning: torch.utils.checkpoint: the use_reentrant parameter should be passed explicitly.
{'loss': 1.8412, 'grad_norm': 3.12, 'learning_rate': 1.9e-05, 'epoch': 0.08}
{'loss': 1.7020, 'grad_norm': 2.87, 'learning_rate': 2.0e-05, 'epoch': 0.16}
{'loss': 1.6551, 'grad_norm': 41.5, 'learning_rate': 2.0e-05, 'epoch': 0.24}
{'loss': 9.8813, 'grad_norm': inf, 'learning_rate': 2.0e-05, 'epoch': 0.26}
{'loss': nan, 'grad_norm': nan, 'learning_rate': 2.0e-05, 'epoch': 0.27}
```

```yaml
# configs/sft_qwen.yaml
model_name_or_path: Qwen/Qwen2.5-7B
bf16: true
gradient_checkpointing: true
learning_rate: 2.0e-5
warmup_ratio: 0.0
max_grad_norm: 0.0
per_device_train_batch_size: 4
gradient_accumulation_steps: 8
```

What's going on?
