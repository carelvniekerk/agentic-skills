---
name: dotset
description: Manages project dotfiles (.gitignore, .uvgroups, .envrc, .cleanup, .skyignore, .rsync-exclude) via the dotset CLI. Use when adding/removing ignore patterns, managing UV groups, setting .envrc directives, or initialising project dotfiles.
---

## Contract

This skill mutates project dotfiles **exclusively through the dotset CLI** — never by hand-editing the managed files unless dotset itself cannot perform the operation.
Every mutating run is preceded by a `dotset status` and the relevant `show` / `list` query, so the user sees the current state before any change.
For multi-step init flows, the plan is confirmed with the user before any answers are piped in.
Direct Read/Edit/Write of dotset-managed files (`.gitignore`, `.uvgroups`, `.envrc`, `.cleanup`, `.skyignore`, `.rsync-exclude`) is reserved for the explicit fallback in the *Fallback* section at the bottom.

## Binary

Always invoke dotset as `${CHEZMOI_COMMAND_DIR}/.venv/bin/dotset`.
Fall back to `/Users/vniekerk/.local/share/chezmoi/.venv/bin/dotset` if `CHEZMOI_COMMAND_DIR` is unset.

Pass `-p <project-path>` to every command.
Default to cwd if no path is given.

---

## Core Workflow

**Always check status first** — only issue commands for files that exist:

```bash
${CHEZMOI_COMMAND_DIR}/.venv/bin/dotset status -p <path>
```

**Read before you write** — show current contents before modifying:

```bash
dotset gitignore show -p <path>
dotset uvgroups show -p <path>
dotset envrc show -p <path>
dotset cleanup show -p <path>
dotset skyignore show -p <path>    # only if exists
dotset rsync show -p <path>        # only if exists
dotset ignore list -p <path>       # matrix across all ignore files
```

---

## Operations Reference

### Ignore patterns (gitignore + skyignore + rsync-exclude together)

Use `ignore add/remove` when the user wants a pattern in all active ignore files at once:

```bash
dotset ignore add <pattern> [-s "<Section>"] -p <path>
dotset ignore remove <pattern> -p <path>
```

### Single-file pattern operations

```bash
dotset gitignore add <pattern> [-s "<Section>"] -p <path>
dotset gitignore remove <pattern> -p <path>

dotset uvgroups add <group> [-s "<Section>"] -p <path>
dotset uvgroups remove <group> -p <path>

dotset cleanup add <pattern> [-s "<Section>"] -p <path>
dotset cleanup remove <pattern> -p <path>

dotset skyignore add <pattern> [-s "<Section>"] -p <path>
dotset rsync add <pattern> [-s "<Section>"] -p <path>
```

### .envrc directives

```bash
dotset envrc set <directive> <value> -p <path>
dotset envrc unset <directive> -p <path>
```

Common directives: `debug_mode`, `dev_mode`, `run_mode`, `activate_hpc`, `activate_hydra_launcher`.
Common values: `on` / `off`, cluster name (e.g. `NOCTUA2`), launcher (e.g. `skypilot`).

### Activating optional files

```bash
dotset skyignore activate -p <path>    # creates .skyignore + adds entry to .gitignore
dotset rsync activate -p <path>        # creates .rsync-exclude + updates .gitignore/.skyignore
```

---

## Section Headers

Always supply `-s` when you know the right header.
Standard headers from the ML preset:

- `Pytest cache` — `.coverage`, `.pytest_cache`
- `Python cache` — `*__pycache__*`
- `Ruff cache` — `.ruff_cache`
- `Apple Finder files` — `.DS_Store`
- `UV environment` — `.venv`, `uv.lock`, `.uvgroups`
- `Direnv environment` — `.envrc`
- `Secrets file` — `.env`
- `Data and model caches` — `.data_cache`, `.model_cache`
- `AI assistant configuration` — `.claude`
- `Weights and Biases logs` — `wandb_logs`
- `MLflow logs` — `mlflow_logs`
- `Deepeval cache` — `.deepeval`
- `Hydra experiment directories` — `hydra_plugins`, `multirun`, `outputs`, `hpc_jobs` (gitignore)
- `Hydra experiment outputs` — `multirun`, `outputs` (skyignore/rsync)
- `Hydra multirun configs` — `multirun/` (cleanup)
- `Accelerate outputs` — `outputs/accelerate` (cleanup)
- `Mac incompatible packages` — `launchers`, `quantized`, `muon`, `vllm` (uvgroups)

Omit `-s` to append under the last existing section.

---

## Init Flow

When asked to initialise dotfiles for a project from scratch:

**Step 1 — Study the project.**
Read `pyproject.toml` (dependencies and optional-dependency groups).
Look for `wandb`, `mlflow`, `deepeval`, `hydra-core`, `accelerate`, `skypilot`.
Check for HPC job scripts (`sbatch`, `srun`).

**Step 2 — Determine answers** to the fixed `dotset init` prompt sequence:

| Prompt                             | Default              | Signal                                        |
| ---------------------------------- | -------------------- | --------------------------------------------- |
| Overwrite? _(only if files exist)_ | N                    | Ask user                                      |
| MLflow?                            | N                    | `mlflow` in deps                              |
| Weights & Biases?                  | Y                    | `wandb` in deps                               |
| Deepeval?                          | N                    | `deepeval` in deps                            |
| Hydra?                             | Y                    | `hydra-core` or `omegaconf` in deps           |
| Accelerate? _(only if Hydra=Y)_    | N                    | `accelerate` in deps                          |
| Skypilot?                          | N                    | `skypilot` in deps or user wants `.skyignore` |
| Rsync?                             | N                    | User uses HPC rsync syncing                   |
| HPC cluster?                       | N                    | HPC job scripts in project                    |
| Cluster name _(only if HPC=Y)_     | NOCTUA2              | Ask user                                      |
| UV groups _(comma-separated)_      | _(empty = dev only)_ | Optional-dep groups in pyproject.toml         |
| Debug mode?                        | N                    | User preference                               |
| Dev mode?                          | Y                    | User preference                               |
| Run mode?                          | N                    | User preference                               |
| Proceed?                           | Y                    | Always Y after user confirms                  |

**Step 3 — Confirm plan with user** before running anything.
Let them correct decisions.

**Step 4 — Run init non-interactively** by piping answers (one per line; empty line accepts text prompt default):

```bash
# Example: W&B + Hydra + Skypilot + Rsync + HPC=NOCTUA2, groups=launchers,muon
# n=MLflow  y=W&B  n=Deepeval  y=Hydra  n=Accelerate  y=Skypilot  y=Rsync  y=HPC  NOCTUA2  launchers,muon  n=Debug  y=Dev  n=Run  y=Proceed
printf "n\ny\nn\ny\nn\ny\ny\ny\nNOCTUA2\nlaunchers,muon\nn\ny\nn\ny\n" | \
  ${CHEZMOI_COMMAND_DIR}/.venv/bin/dotset init -p <path>
```

Full prompt sequence (adjust for conditionals):

```
[overwrite? — only present if files already exist]
y/n  MLflow
y/n  Weights & Biases
y/n  Deepeval
y/n  Hydra
y/n  Accelerate          (only if Hydra=y)
y/n  Skypilot
y/n  Rsync
y/n  HPC cluster
str  Cluster name        (only if HPC=y; empty line accepts default NOCTUA2)
str  UV groups           (empty line for dev only)
y/n  Debug mode
y/n  Dev mode
y/n  Run mode
y    Proceed
```

**Step 5 — Verify** with `dotset status -p <path>` and show the result.

---

## Fallback

If dotset cannot handle an operation, fall back to the Read/Edit tools.
Always show what is changing.
Never write dotset-managed files directly unless dotset itself fails or no applicable command exists.
