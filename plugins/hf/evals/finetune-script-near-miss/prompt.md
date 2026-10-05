---
description: Near miss. A request to write a fine-tuning script shares the Hugging Face vocabulary but is a coding task, so the hf skill should not fire.
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
tags: [hf, negative]
---

Write me a short TRL script that fine-tunes Qwen/Qwen3-0.6B with LoRA on a local JSONL file called train.jsonl with a "messages" column. bf16, one epoch, save to ./out.
