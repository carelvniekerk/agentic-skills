---
name: bug-discovery
description: Diagnose bugs, errors, tracebacks, crashes, failing tests, and unexpected runtime behavior through evidence gathering rather than guess-and-fix. Use this skill aggressively whenever the user mentions a bug, error, traceback, exception, crash, segfault, NaN, hang, deadlock, regression, "doesn't work", "broken", "failing test", or unexpected output — even if they don't explicitly ask for debugging help. Use it before proposing any code change. The skill enforces (1) gather environment and run-condition context, (2) read the relevant code and full terminal output thoroughly, (3) perform exhaustive web/issue search including reading linked discussions and PRs, (4) deliver a written diagnostic report with ranked hypotheses, sources, and suggested next diagnostic steps — and stop there for user discussion before any fix is attempted.
allowed-tools: Read Grep Glob WebSearch WebFetch Bash(git *) Bash(uname *) Bash(sw_vers *) Bash(python *) Bash(python3 *) Bash(node *) Bash(rustc *) Bash(cargo *) Bash(uv *) Bash(uvx *) Bash(pip *) Bash(pipx *) Bash(nvidia-smi *) Bash(nvcc *) Bash(rocm-smi *) Bash(rg *) Bash(fd *) Bash(ls *) Bash(eza *) Bash(bat *)
---

## Contract

This skill produces a **diagnostic report**, not a patch.
It reads, searches, and synthesises — it does not edit code, commit, push, install packages, or run the user's project commands beyond read-only probes (`--version`, `pip show`, `git status`, etc.).
If exhaustive search yields no relevant lead, the report says so explicitly rather than fabricating a plausible cause.
Phase 4 is a hard stop: the report is delivered and the next move is the user's.

# Bug Discovery

A diagnostic-first debugging workflow.
The goal is to understand _why_ a bug happens — supported by code evidence, terminal evidence, and external evidence — before anyone touches a fix.
Cheap guesses, plausible-sounding patches, and "try this and see" iterations are explicitly out of scope for this skill.

## Operating principle

Bugs are usually misunderstood, not mysterious.
Most premature fixes fail because the diagnosis was skipped: the model pattern-matches on the error string, suggests a fix that addresses the _symptom_, and the underlying cause persists or reappears elsewhere.
This skill exists to slow that loop down.

The deliverable is a **diagnostic report**, not a patch.
The user reviews the report and decides what to fix.

## Phase 1 — Gather context

You need three things before you can usefully reason about the bug: the environment, the run conditions, and the evidence already in front of you.

### 1a. Auto-detect what you can

Before asking the user anything, gather these silently from the working environment:

- **OS and kernel** — `uname -a`, and on macOS also `sw_vers`.
- **Python / runtime version** — `python --version`, `node --version`, `rustc --version`, etc., as appropriate to the project.
- **Project dependency state** — read `pyproject.toml` and `uv.lock` (or `requirements.txt`, `package.json` + lockfile, `Cargo.toml` + `Cargo.lock`) to identify the versions of packages plausibly involved in the bug.
  Don't dump the entire lockfile; extract the specific dependencies that appear in the traceback or are mentioned by the user.
- **Git state** — `git status`, `git log --oneline -20`, and if a regression is suspected, `git diff` against the last known-working commit if the user named one.

Record these findings concisely; they go into the report.

### 1b. Ask only for what you can't auto-detect

If the following are not already obvious from the conversation or the working environment, **ask the user before proceeding**.
Do not proceed with assumptions — guesses about run conditions are the single biggest source of false diagnoses.

- **Hardware context** — GPU model, CUDA / ROCm / MPS version, number of devices, whether this is local or on a cluster (and which one — SLURM node? SkyPilot VM? Container?).
- **Exact reproduction command** — the precise command-line invocation, including all flags, the config file path, the seed, and any relevant environment variables (`CUDA_VISIBLE_DEVICES`, `HF_HOME`, etc.).
- **When it last worked** — has this code path ever worked?
  If yes, what changed (new dependency, new data, new hardware, new commit)?
- **Reproducibility** — does it fail every time, intermittently, or only on specific inputs / seeds?

Ask these in a single batched message, not one at a time.
If the user has already volunteered some of these, only ask for the rest.

## Phase 2 — Read the evidence thoroughly

This is the phase where most diagnoses are won or lost.
Be patient here.

### 2a. Read the terminal output in full

The traceback is not just the bottom line.
Read the full output:

- The **complete traceback**, top to bottom — the outermost frame often reveals which subsystem triggered the failure (e.g., a `forward()` call originating from a `Trainer.training_step` differs meaningfully from one originating from `evaluate()`).
- **Warnings** logged before the failure — deprecation warnings, `RuntimeWarning`s, CUDA warnings, and HuggingFace `UserWarning`s frequently foreshadow the actual failure.
- **Log lines from libraries** — DeepSpeed init logs, vLLM engine startup, Accelerate launch info, SLURM node assignments.
  These reveal the actual runtime configuration, which often differs from what the user thinks they configured.
- **The lines immediately before the error** — the last successful operation tells you where the program got to, which constrains the hypothesis space.

If only a partial traceback was shared, ask for the full one.

### 2b. Read the relevant code thoroughly

Don't skim.
For each frame in the traceback that lives in user code or in a project dependency:

- Open the file and read the function in full, not just the failing line.
- Trace the values flowing into the failing operation — where does each argument come from?
  What are its shape, dtype, device, and expected range?
- Check the **call sites** of the failing function — is it being invoked in a context the author didn't anticipate?
- For library code (TRL, transformers, DeepSpeed, vLLM, etc.), open the actual installed source — not your memory of how it works.
  Library internals change between minor versions, and your training data is not a substitute for reading the version actually installed.

Use `grep` / `rg` to find related code paths — the same pattern often appears elsewhere in the codebase and the working instance reveals what the broken instance is missing.

### 2c. Form a tentative mental model

By the end of phase 2, you should be able to state, in one or two sentences, what the program _was trying to do_ at the moment of failure and what _unexpected condition_ it encountered.
If you can't articulate this clearly, you haven't read enough yet — go back.

## Phase 3 — Exhaustive external search

Now, and only now, go outside the codebase.
The goal is to find out whether this is a known issue.

### 3a. Search breadth

Cast a wide net before going deep:

- **GitHub issues** of every directly involved library — search both open and closed issues.
  Use the verbatim error message, then progressively shorter / more abstract variants.
  Closed issues with workarounds are gold.
- **GitHub pull requests** — especially recently merged ones.
  A bug that appeared after an upgrade is often addressed in a PR that hasn't been released yet, or has been released in a version the user hasn't pinned to.
- **Release notes and changelogs** for the involved libraries — particularly between the version that worked (if known) and the version that's failing.
- **Stack Overflow**, but treat it as a starting point rather than a source of truth — its signal-to-noise on modern ML/infra issues is poor.
- **Official documentation** — sometimes the behavior is documented and the bug is a misuse rather than a defect.
- **Discussion forums** — HuggingFace forums, PyTorch forums, NVIDIA developer forums, the relevant Discord/Slack archives where applicable.
- **Upstream repos** — if the failure is in `transformers`, also search `accelerate`, `peft`, `trl`, `deepspeed`, and `torch` issue trackers; bugs frequently propagate across the stack.

### 3b. Search depth

For every promising lead — **read it in full**.
This is non-negotiable:

- Read the full issue thread, not just the original post.
  The resolution is usually buried in comment 47.
- Follow links to other issues and PRs referenced in the discussion, and read those too.
- If a PR is linked, read the actual diff to understand what changed and whether it applies to the user's version.
- If a maintainer comment says "fixed in v0.X.Y", verify the user's installed version against that.

Yes, this is slow.
It is also the single highest-leverage step in this skill — pattern-matching on issue titles without reading the bodies is how false leads enter the report.

### 3c. Don't fabricate

If exhaustive search turns up nothing relevant, **say so explicitly** in the report.
Do not invent a plausible-sounding cause to fill the gap.
"I could not find a known issue matching this signature" is a legitimate and useful finding — it tells the user this is novel and shapes the next diagnostic steps differently.

## Phase 4 — Deliver the diagnostic report

Stop.
Do not propose a fix.
Do not edit any code.
Write the report and hand it to the user.

### Report structure

Use this exact template:

```markdown
# Bug Discovery Report

## Summary

One or two sentences: what failed, where, and the leading hypothesis.

## Environment and run conditions

- OS / kernel: ...
- Runtime: ...
- Relevant package versions: ...
- Hardware: ...
- Reproduction command: ...
- Reproducibility: ...
- Recent changes: ...

## Evidence

### From the terminal output

- Key warnings: ...
- Last successful operation before the failure: ...
- Failure signature: ...

### From the code

- What the program was attempting at the failure point: ...
- Values / shapes / devices flowing in: ...
- Notable discrepancies from documented usage: ...

## Hypotheses (ranked)

### H1 — [short name], confidence: [high | medium | low]

**Mechanism.** What's actually going wrong, mechanically.
**Supporting evidence.** Code observations, terminal output, and external sources that point to this. Cite issue / PR / doc URLs inline.
**Contradicting evidence.** Anything that doesn't fit this hypothesis. Be honest here.

### H2 — ...

### H3 — ...

(Include up to 5. If only one hypothesis fits the evidence, say so — don't pad.)

## Suggested next diagnostic steps

Concrete, low-cost actions to discriminate between the hypotheses. Each step should be designed to _eliminate_ at least one hypothesis. Examples:

- "Run with `TORCH_DISTRIBUTED_DEBUG=DETAIL` to confirm whether H1 or H2 is the cause."
- "Check `pip show <pkg>` to verify the installed version matches the lockfile."
- "Try with `--num-workers 0` to rule out a dataloader race."

## Sources consulted

- [URL 1] — short note on what was found
- [URL 2] — ...
- (If nothing relevant was found externally, state that explicitly.)

## Open questions for you

Anything you still need from the user before you can narrow further.
```

### After delivering the report

Wait for the user.
The next move is theirs.
They may ask you to:

- pursue a specific hypothesis further,
- run one of the suggested diagnostic steps,
- discuss tradeoffs between potential fixes, or
- proceed to implement a fix once a hypothesis is confirmed.

Do not preempt this by jumping to a fix.
Even if the cause is obvious, the report-then-discuss flow is the contract of this skill — it gives the user a chance to spot a bad diagnosis before code starts changing.

## When this skill does not apply

- Trivial typos and syntax errors the user can see for themselves.
- Bugs the user has already diagnosed and is asking for help fixing — at that point, switch to fix-mode and skip Phases 1–4.
- Build / install errors where the entire output is a single line from the package manager (just answer directly).

For everything else where the user says "it broke" — start at Phase 1.
