---
name: dotset
description: >-
  Manage a project's dotfiles (.gitignore, .uvgroups, .envrc, .cleanup, .skyignore, .rsync-exclude) through the dotset CLI: add or remove ignore patterns, manage UV groups, set .envrc directives and initialise the files for a new project.
  Use when the user says "add X to the ignore files", "ignore this in git and rsync", "add a uv group", "set dev_mode", "turn on HPC mode" or "set up dotfiles for this project", in a project that dotset already manages or that the user wants dotset to initialise.
when_to_use: >-
  Trigger phrases: "add to .gitignore and .skyignore", "remove this pattern everywhere", "add the launchers group", "set debug_mode on", "init the dotfiles", "what's in .uvgroups".
  A repository with none of the dotset files and no request to initialise them is not this skill, and Claude edits its .gitignore directly.
argument-hint: "[project path]"
model: haiku
effort: low
allowed-tools: Read Bash(dotset *) Bash(uvx dotset *) Bash(printf *)
---

# dotset

You change a project's dotfiles through the `dotset` CLI and nothing else.
Every change is preceded by `dotset status` and a `show` of the file it touches, so the user sees the state before it moves.
The skill hand-edits a dotset-managed file only through the fallback at the end, and only when the CLI has no command for the operation.

## Contents

- Workflow
- Binary and project path
- Read before you write
- Operations
- Section headers
- Init flow
- Fallback
- Strict prohibitions

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
dotset progress:
- [ ] 1. dotset found, project path fixed
- [ ] 2. dotset status run, project confirmed as dotset-managed (not managed and no init requested: stop and say so)
- [ ] 3. Current contents shown with show or list
- [ ] 4. Change made with one dotset command per change
- [ ] 5. Result shown with show or status
```

## Binary and project path

Run `dotset`, which lives at `~/.local/bin/dotset`.
If the shell cannot find it, run `uvx dotset` instead and say so.
Pass `-p <project-path>` to every command, and use the current directory when the user gives no path.

## Read before you write

Run `dotset status -p <path>` first.
It lists which of the six files exist, so issue commands only for files that do.
If none exist and the user did not ask to initialise, stop and tell them the project is not dotset-managed.

Then show the file you are about to change:

```bash
dotset gitignore show -p <path>
dotset uvgroups show -p <path>
dotset envrc show -p <path>
dotset cleanup show -p <path>
dotset skyignore show -p <path>   # only if it exists
dotset rsync show -p <path>       # only if it exists
dotset ignore list -p <path>      # one matrix across all active ignore files
```

## Operations

Use `ignore add` and `ignore remove` when the pattern belongs in every active ignore file, and a single-file command when it belongs in one.
`-s "<Section>"` is optional on every `add`.

```bash
dotset ignore add <pattern> [-s "<Section>"] -p <path>
dotset ignore remove <pattern> -p <path>

dotset gitignore add <pattern> [-s "<Section>"] -p <path>
dotset gitignore remove <pattern> -p <path>
dotset uvgroups add <group> [-s "<Section>"] -p <path>
dotset uvgroups remove <group> -p <path>
dotset cleanup add <pattern> [-s "<Section>"] -p <path>
dotset cleanup remove <pattern> -p <path>
dotset skyignore add <pattern> [-s "<Section>"] -p <path>
dotset skyignore remove <pattern> -p <path>
dotset rsync add <pattern> [-s "<Section>"] -p <path>
dotset rsync remove <pattern> -p <path>

dotset envrc set <directive> <value> -p <path>
dotset envrc unset <directive> -p <path>
```

Common `.envrc` directives are `debug_mode`, `dev_mode`, `run_mode`, `activate_hpc` and `activate_hydra_launcher`, with values such as `on`, `off`, a cluster name like `NOCTUA2` or a launcher like `skypilot`.

Two optional files are created on demand:

```bash
dotset skyignore activate -p <path>   # creates .skyignore and adds it to .gitignore
dotset rsync activate -p <path>       # creates .rsync-exclude and updates .gitignore and .skyignore
```

## Section headers

Supply `-s` whenever one of these headers fits, and omit it to append under the last section.
These come from the ML preset, so check them against `show` before relying on one.

| Header | Typical entries |
| --- | --- |
| `Pytest cache` | `.coverage`, `.pytest_cache` |
| `Python cache` | `*__pycache__*` |
| `Ruff cache` | `.ruff_cache` |
| `Apple Finder files` | `.DS_Store` |
| `UV environment` | `.venv`, `uv.lock`, `.uvgroups` |
| `Direnv environment` | `.envrc` |
| `Secrets file` | `.env` |
| `Data and model caches` | `.data_cache`, `.model_cache` |
| `AI assistant configuration` | `.claude` |
| `Weights and Biases logs` | `wandb_logs` |
| `MLflow logs` | `mlflow_logs` |
| `Deepeval cache` | `.deepeval` |
| `Hydra experiment directories` | `hydra_plugins`, `multirun`, `outputs`, `hpc_jobs` (gitignore) |
| `Hydra experiment outputs` | `multirun`, `outputs` (skyignore and rsync) |
| `Hydra multirun configs` | `multirun/` (cleanup) |
| `Accelerate outputs` | `outputs/accelerate` (cleanup) |
| `Mac incompatible packages` | `launchers`, `quantized`, `muon`, `vllm` (uvgroups) |

## Init flow

Use this only when the user asks to initialise a project.

1. **Study the project.**
Read `pyproject.toml` for dependencies and optional-dependency groups, and look for `mlflow`, `wandb`, `deepeval`, `hydra-core`, `omegaconf`, `accelerate` and `skypilot`.
Check for HPC job scripts (`sbatch`, `srun`).
2. **Decide the answers** to the fixed prompt sequence below.
These were checked against the installed `dotset init` on 2026-10-05.
3. **Show the plan and wait for the user's confirmation** before anything runs.
The user may correct any answer.
4. **Pipe the answers**, one per line, in the order of the table.
5. **Verify** with `dotset status -p <path>` and show the result.

| Prompt | Default | Signal |
| --- | --- | --- |
| Overwrite? (only if files exist) | N | Ask the user, and never answer y on your own |
| MLflow? | N | `mlflow` in dependencies |
| Weights & Biases? | Y | `wandb` in dependencies |
| Deepeval? | N | `deepeval` in dependencies |
| Hydra? | Y | `hydra-core` or `omegaconf` in dependencies |
| Accelerate? (only if Hydra is y) | N | `accelerate` in dependencies |
| Skypilot? | N | `skypilot` in dependencies, or the user wants `.skyignore` |
| Rsync? | N | The user syncs to an HPC with rsync |
| HPC cluster? | N | HPC job scripts in the project |
| Cluster name (only if HPC is y) | NOCTUA2 | Ask the user |
| UV groups (comma-separated) | empty, which means dev only | Optional-dependency groups in `pyproject.toml` |
| Debug mode? | N | The user's preference |
| Dev mode? | Y | The user's preference |
| Run mode? | N | The user's preference |
| Proceed? | Y | Always y once the user has confirmed the plan |

An empty line accepts a default.
W&B, Hydra, Skypilot, Rsync and HPC (NOCTUA2) with groups `launchers,muon` and the default modes:

```bash
printf "n\ny\nn\ny\nn\ny\ny\ny\nNOCTUA2\nlaunchers,muon\nn\ny\nn\ny\n" | dotset init -p <path>
```

The answers map in order to MLflow n, W&B y, Deepeval n, Hydra y, Accelerate n, Skypilot y, Rsync y, HPC y, cluster, groups, Debug n, Dev y, Run n, Proceed y.
Count the prompts that apply before piping, because a skipped conditional prompt shifts every later answer.

## Fallback

If dotset has no command for an operation, use `Read` and `Edit` on the file and show the user what changes.
The `Edit` call goes through the normal permission prompt, which is intended.
Never use the fallback because a dotset command failed: report the error instead.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Hand-editing a dotset-managed file when a dotset command exists | The CLI keeps sections and cross-file entries consistent |
| `dotset init --force` or `-f`, or answering y to Overwrite without the user's word | Overwrites the user's existing dotfiles |
| Piping answers before the user has confirmed the plan | A wrong answer silently misconfigures the project |
| Running dotset on a path other than the one the user named or the current directory | Changes files in an unrelated project |
| Removing a pattern or group without showing the current contents first | The user cannot check what disappears |
