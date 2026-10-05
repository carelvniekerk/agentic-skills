---
description: Dotfile init request for a project whose pyproject shows wandb, hydra, accelerate and skypilot. The skill should map dependencies to answers and ask for confirmation before piping anything.
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [dotset, init]
---

Set up the dotfiles for this project with dotset. You can't see my machine, so here is the state. Don't run anything yet if you'd need to ask me something, just tell me what you'd do.

```text
$ ls -a
.  ..  pyproject.toml  src  scripts  README.md

$ cat pyproject.toml
[project]
name = "sft-experiments"
dependencies = ["torch", "transformers", "trl", "wandb", "hydra-core", "accelerate", "skypilot"]

[project.optional-dependencies]
launchers = ["skypilot[aws]"]
dev = ["pytest", "ruff"]

$ ls scripts
train.py  sync_to_cluster.sh
```
