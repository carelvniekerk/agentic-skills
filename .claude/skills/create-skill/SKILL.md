---
name: create-skill
description:
    Author, edit, and iteratively improve Claude Code skills (SKILL.md files under .claude/skills/ or ~/.claude/skills/) following the official Agent Skills specification.
    Use this skill aggressively whenever the user mentions creating, writing, editing, refining, optimising, debugging, packaging, or distributing a skill — even if they only say "write a SKILL.md", "add a skill for X", "this should be a skill", "turn this workflow into a skill", or reference any path under .claude/skills/.
    Also use it when reviewing existing SKILL.md frontmatter, fixing skills that fail to trigger or trigger too often, designing supporting files (references/, scripts/, assets/), wiring up dynamic context injection, choosing between inline and forked-subagent execution, or distributing skills via plugins.
    The skill enforces a draft → test → review → iterate loop and keeps frontmatter aligned with the current Agent Skills spec.
allowed-tools: Read Write Edit Glob Grep Bash(mkdir *) Bash(ls *) Bash(cat *) Bash(git *) Bash(claude *) Bash(uv *)
---

# Skill Author

A disciplined workflow for authoring Claude Code skills.
The deliverable is a working `SKILL.md` (plus any supporting files) that triggers reliably, stays under the size budget, and survives auto-compaction.

This skill enforces a **draft → test → review → iterate** loop.
The first draft is rarely the final draft, and skipping evaluation is the single biggest reason skills under-trigger or produce inconsistent output in production.

---

## Operating principle

A skill is context that loads on demand.
Three things determine whether it succeeds:

1. **Triggering.**
   The `description` is the only signal Claude uses to decide whether to consult the skill.
   If keywords the user actually types are missing, the skill never loads, regardless of how good the body is.
2. **Concision.**
   Once a skill loads, its body stays in context for the rest of the session and is re-attached after auto-compaction (with a per-skill cap of 5,000 tokens and a combined budget of 25,000 tokens across all re-attached skills).
   Every line of `SKILL.md` is a recurring token cost.
3. **Progressive disclosure.**
   Detailed reference material, large examples, and rarely-needed docs belong in supporting files that are loaded only when the skill explicitly points to them.
   Bundled scripts execute without their source loading into context at all.

Optimise for these three properties from the first draft.
Everything below operationalises that.

---

## Source formatting — one sentence per line

Whenever you write markdown in this workflow — the `SKILL.md` body, reference files, or any commit/PR text — put each sentence on its own line in the source.
This convention is sometimes called *semantic line breaks*.

The rendered output is unchanged: a markdown renderer collapses consecutive non-blank lines within a paragraph into one rendered line, so the visual result is identical to a soft-wrapped paragraph.
The benefit is in `git diff`: editing one sentence produces a one-line diff instead of a re-flowed paragraph that touches every wrapped line.

Within a list item, the same rule applies — the bullet marker stays on the first line, and continuation sentences sit on subsequent unindented lines.
A blank line ends the paragraph or list item.

````markdown
- This is one bullet.
The bullet continues here, still in the same item.

- This is the next bullet.
````

Type each sentence on a new line as you author.
Do not rely on a post-processing script to enforce this — the rule is small and unambiguous when you write sentence-by-sentence.

---

## Companion skills — delegating to siblings

This skill is one of three that together cover Claude Code's authoring primitives:

- **`create-skill`** (this skill) — reusable prompt/workflow context that loads on demand into the parent conversation.
- **`create-hook`** — deterministic interception of a lifecycle event (format on save, block a command, inject context).
- **`create-agent`** — delegated subagent with its own context window, tool scope, and return-value contract.

If the user's request expands beyond a plain skill, invoke the sibling skill via the `Skill` tool rather than re-deriving its workflow inline.
Hand over the context you have already gathered (the wrapping file path, the lifecycle event, the desired tool scope) so the sibling does not re-ask its own Phase 0 questions.

Common compositions when authoring a skill:

- The skill should bundle a **hook** in its frontmatter (e.g. a skill that auto-formats on save or injects context after compaction).
  Delegate the hook design to `create-hook`, then place the resulting hook config in the skill's `hooks:` frontmatter field.
- The skill should preload or document a **subagent** that the user delegates to (e.g. a skill that wraps a code-review subagent).
  Delegate the agent design to `create-agent`, then reference it from the skill body and (optionally) the skill's `preloaded-skills`/`agents` directives.
- The skill is itself a **meta-skill** that authors agents or hooks for other projects — the sibling skill is a reference, not a replacement.

---

## Phase 0 — Capture intent

Before writing anything, establish what the skill is for.
The current conversation often already contains the workflow the user wants to capture (e.g. they say "turn this into a skill" after a debugging session).
Extract what you can from history first; ask only for the gaps.

Ask the user — in a single batched message — to confirm the following:

1. **What should the skill enable Claude to do?**
   One sentence, action-oriented.
2. **When should it trigger?**
   Concrete user phrases or contexts.
   Aim for at least three.
3. **What's the expected output?**
   A file? A diagnostic report? A code change? Inline prose?
4. **Reference content or task content?**
   _Reference content_ (conventions, patterns, domain knowledge) typically lets Claude auto-invoke; _task content_ (deploy, commit, fix-issue) is usually user-invocable only.
   See [§ Reference vs task content](#reference-vs-task-content).
5. **Should we set up test cases?**
   Skills with objectively verifiable outputs (file transforms, data extraction, code generation, fixed workflow steps) benefit from tests.
   Skills with subjective outputs (writing style, art) often do not.
   Suggest the appropriate default; the user decides.

Wait for confirmation before drafting.

---

## Phase 1 — Choose location and structure

### Where the skill lives

| Scope      | Path                                     | Notes                                                                       |
| ---------- | ---------------------------------------- | --------------------------------------------------------------------------- |
| Personal   | `~/.claude/skills/<name>/SKILL.md`       | Available in every project on this machine.                                 |
| Project    | `<repo>/.claude/skills/<name>/SKILL.md`  | Only when Claude Code runs from that repo.                                   |
| Plugin     | `<plugin>/skills/<name>/SKILL.md`        | Namespaced `<plugin>:<name>`. **This is what this repository publishes.**    |
| Enterprise | Managed settings                         | Organisation-wide deployment.                                               |

Precedence when names collide: **enterprise > personal > project**.
Plugin skills are namespaced and never collide — a plugin's `/git:commit` coexists with a personal `/commit`.
A skill takes precedence over a `.claude/commands/` file with the same name.

In monorepos, Claude Code automatically discovers skills from nested `.claude/skills/` directories under whichever file you are working on (e.g. `packages/frontend/.claude/skills/`).

### Publishing from this repository

Skills here live inside a plugin: `plugins/<plugin>/skills/<name>/SKILL.md`.
The plugin is the unit of installation, and `.claude-plugin/marketplace.json` at the repo root is what makes it installable.
The next phase covers the plugin layout and what the frontmatter must carry.

### Anatomy of a skill

```
skill-name/
├── SKILL.md              (required — entrypoint)
├── references/           (loaded on demand, referenced from SKILL.md)
│   ├── api-spec.md
│   └── examples.md
├── scripts/              (executed, not loaded into context)
│   └── run.py
└── assets/               (templates, fonts, icons used in output)
    └── template.md
```

`SKILL.md` is the only required file.
Everything else is optional and loaded only when `SKILL.md` explicitly points to it.

### Live change detection

Claude Code watches skill directories for file changes during a session.
Adding, editing, or removing a skill under `~/.claude/skills/`, the project `.claude/skills/`, or any `.claude/skills/` inside an `--add-dir` directory takes effect immediately.
Creating a brand-new top-level skills directory still requires a Claude Code restart so the watcher can attach to it.

---

## Phase 1.5 — Plugin packaging

Skills in this repository ship inside a plugin, and the plugin ships through the marketplace at `.claude-plugin/marketplace.json`.
Claude Code reads `SKILL.md` frontmatter **directly** and merges nothing — whatever you write in the file is exactly what the loader sees.

### All frontmatter is inline

Two keys are non-negotiable:

| Key           | Constraint                                                                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `name`        | Lowercase letters, digits, and hyphens. No leading/trailing hyphen. No consecutive hyphens. ≤ 64 characters. **Must match the parent directory name.** |
| `description` | ≤ 1024 characters. Describes both what the skill does and when to use it.                                                                             |

Always set `name` explicitly.
Without it the invocation name falls back to the install directory name, which is unstable across plugin updates.

Everything else Claude Code understands goes in the same block: `allowed-tools`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, `shell`.
Detailed semantics are in the Phase 2 frontmatter table.

Write `allowed-tools` in Anthropic syntax — `Bash(git *)`, space-separated — not the open-spec `Bash(git:*)` form.

> **Do not create a `.harness/` directory.**
> Earlier revisions of this repository split Claude-only frontmatter into `.harness/claude.yaml` so a separate installer could merge it per platform.
> That mechanism is gone, along with the Codex and Copilot targets it served.
> A `.harness/` file today is simply ignored, and its keys are silently lost.

### Directory layout

```text
plugins/<plugin>/
├── .claude-plugin/
│   └── plugin.json             (manifest — ONLY this file goes in here)
├── skills/
│   └── <slug>/
│       ├── SKILL.md            (required; complete frontmatter inline)
│       ├── references/         (loaded on demand)
│       ├── scripts/            (executed, not loaded as text)
│       └── assets/             (templates, fixtures, fonts)
└── agents/
    └── <slug>.md               (optional subagents)
```

`skills/` and `agents/` are discovered automatically.
Only declare `skills` or `agents` paths in `plugin.json` when they live somewhere non-standard.

### Choosing which plugin a skill joins

The plugin name becomes the slash prefix — `/git:commit`, `/research:peer-review` — so keep it short.

A plugin is the unit of installation *and* of context cost: every enabled plugin's skill descriptions load on every turn.
Group skills you would always install together.
Put a skill you would only ever want in one project into its own plugin so it can be installed at project scope.

Adding a new plugin means adding its entry to `.claude-plugin/marketplace.json` too, or it will not be installable:

```json
{ "name": "git", "source": "./plugins/git", "category": "workflow", "tags": ["git", "commit"] }
```

Sources are paths from the repository root and must start with `./`, so write the `./plugins/` prefix in full.
Do not set `metadata.pluginRoot` — a source short enough to need it is rejected by the schema, and a valid one ignores it.
Note that `claude plugin validate` checks the schema but never checks that the path exists, so confirm a new entry with an actual install rather than with the validator.

### Validate

```bash
claude plugin validate .                            # marketplace manifest
claude plugin validate plugins/<plugin>             # plugin manifest
claude plugin validate plugins/<plugin>/skills      # the skill files themselves
```

Plugin manifests here deliberately omit `version` so the git SHA drives updates.
`validate` emits one warning per plugin about that; it is expected.

---

## Phase 2 — Write the SKILL.md

### Frontmatter reference

Frontmatter sits between `---` markers at the top of `SKILL.md`.
All fields are optional except — practically speaking — `description`.
Most fields below are Claude Code extensions on top of the open Agent Skills spec.
All of them go inline in `SKILL.md` — see [§ Phase 1.5 — Plugin packaging](#phase-15--plugin-packaging).

| Field                      | Purpose                                                                     | Notes                                                                                                                                                                     |
| -------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                     | Display name for the skill.                                                 | Lowercase letters, numbers, hyphens. Max 64 characters. Defaults to the directory name if omitted.                                                                        |
| `description`              | What the skill does and when to use it.                                     | The primary triggering signal. If omitted, the first paragraph of body content is used. Combined with `when_to_use`, capped at **1,536 characters** in the skill listing. |
| `when_to_use`              | Additional triggering context — phrases, examples, edge cases.              | Appended to `description` and shares the 1,536-character cap.                                                                                                             |
| `argument-hint`            | Hint shown during autocomplete.                                             | E.g. `[issue-number]` or `[filename] [format]`.                                                                                                                           |
| `arguments`                | Named positional arguments for `$name` substitution.                        | Space-separated string or YAML list. Names map to argument positions in order.                                                                                            |
| `disable-model-invocation` | If `true`, only the user can invoke the skill.                              | Use for skills with side effects (`/deploy`, `/commit`, `/send-slack-message`). Also prevents the skill from being preloaded into subagents. Default: `false`.            |
| `user-invocable`           | If `false`, hides the skill from the `/` menu.                              | Use for background knowledge that isn't actionable as a command. Default: `true`.                                                                                         |
| `allowed-tools`            | Tools Claude can use without per-use permission while this skill is active. | Space-separated string or YAML list. Does not restrict tools — every tool remains callable, governed by your normal permission settings.                                  |
| `model`                    | Model to use while this skill is active.                                    | Same values as `/model`, or `inherit`. Override applies for the rest of the current turn only.                                                                            |
| `effort`                   | Effort level.                                                               | `low`, `medium`, `high`, `xhigh`, `max` — available levels depend on the model.                                                                                           |
| `context`                  | Set to `fork` to run in a forked subagent.                                  | The skill body becomes the subagent's prompt. See [§ Run in a forked subagent](#run-in-a-forked-subagent).                                                                |
| `agent`                    | Subagent type when `context: fork`.                                         | `Explore`, `Plan`, `general-purpose`, or any custom subagent in `.claude/agents/`. Defaults to `general-purpose`.                                                         |
| `hooks`                    | Hooks scoped to this skill's lifecycle.                                     | See the Hooks docs for format.                                                                                                                                            |
| `paths`                    | Glob patterns limiting when the skill auto-activates.                       | Comma-separated string or YAML list. When set, Claude only auto-loads the skill while working with matching files.                                                        |
| `shell`                    | Shell for `` !`command` `` and ` ```! ` blocks.                             | `bash` (default) or `powershell`. PowerShell requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`.                                                                                |

### String substitutions available in the body

| Variable               | Expands to                                                                                                                                                          |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$ARGUMENTS`           | All arguments passed when invoking the skill. If absent from the body, arguments are appended as `ARGUMENTS: <value>`.                                              |
| `$ARGUMENTS[N]`        | The N-th argument (0-based). Use shell-style quoting for multi-word values.                                                                                         |
| `$N`                   | Shorthand for `$ARGUMENTS[N]` (e.g. `$0`, `$1`).                                                                                                                    |
| `$name`                | A named argument declared in `arguments:`. With `arguments: [issue, branch]`, `$issue` is the first argument and `$branch` the second.                              |
| `${CLAUDE_SESSION_ID}` | The current session ID — useful for per-session log files.                                                                                                          |
| `${CLAUDE_EFFORT}`     | The current effort level.                                                                                                                                           |
| `${CLAUDE_SKILL_DIR}`  | The directory containing this `SKILL.md`. **Always use this** to reference bundled scripts or assets, so paths resolve regardless of the current working directory. |

### Reference vs task content

Whether the skill is reference or task content shapes the frontmatter and the body.

**Reference content** — knowledge Claude should consult while doing other work (style guides, API conventions, domain context).
Let Claude auto-invoke.
The body should state facts and patterns, not procedures.

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---
```

**Task content** — a procedure with side effects (deploy, commit, run a migration).
Restrict to user invocation, and pre-approve the tools the procedure needs.

```yaml
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
allowed-tools: Bash(git push *) Bash(./deploy.sh *)
---
```

### The `description` field — getting triggering right

This is the most important line in the file.
Internalise three things:

1. **Claude has a tendency to _under-trigger_ skills.**
   To compensate, write descriptions slightly "pushy".
   Instead of _"How to build a fast dashboard"_, write _"How to build a fast dashboard. Use this skill whenever the user mentions dashboards, data visualisation, internal metrics, or wants to display any kind of data, even if they don't explicitly say 'dashboard'."_
2. **Front-load the key use case.**
   The combined `description` + `when_to_use` is truncated at 1,536 characters in the skill listing — what the user would actually type goes first.
3. **Include the trigger phrases users actually use.**
   If users say "fix the bug" rather than "diagnose the runtime exception", put "fix the bug" in the description.

A reliable structure:

```
<one sentence: what it does>.
Use this skill aggressively whenever the user mentions <phrase 1>, <phrase 2>, <phrase 3>, or <phrase 4> — even if they don't explicitly say <obvious keyword>.
Also use it when <secondary trigger 1>, <secondary trigger 2>.
The skill enforces <one-line summary of the workflow or contract>.
```

### The body — keep it tight

The body lives in context for the rest of the session.
Apply the same conciseness test as for `CLAUDE.md`: state what to do, not how or why.

Hard rules:

- **Aim for under 500 lines.**
  If you exceed this, split into reference files.
- **Do not narrate.**
  _"This skill helps you debug bugs by gathering context."_ → cut.
  _"Run `git status` and record the output."_ → keep.
- **Write standing instructions, not one-time steps.**
  The skill content is injected once per invocation and does not re-read on later turns.
  Anything that should apply throughout the task must be phrased as an ongoing rule.
- **Use headings to make the structure scannable.**
  Claude (and you) will skim it.

### Reference files (progressive disclosure)

Detailed material — full API specs, long example collections, framework-specific notes — goes in separate files referenced from `SKILL.md`:

```
my-skill/
├── SKILL.md          (overview + navigation)
├── references/
│   ├── reference.md  (loaded only when SKILL.md tells Claude to)
│   └── examples.md
└── scripts/
    └── helper.py     (executed, never loaded as text)
```

Tell Claude _what each file contains and when to read it_:

```markdown
## Additional resources

- For complete API details, see [references/reference.md](references/reference.md) — read this when implementing new endpoints.
- For canonical examples, see [references/examples.md](references/examples.md) — read this when writing tests.
```

For long reference files (>300 lines), include a table of contents at the top so Claude can jump to the relevant section without reading the whole thing.

When a skill supports multiple variants (cloud providers, frameworks, languages), organise references by variant and have `SKILL.md` route between them:

```
cloud-deploy/
├── SKILL.md          (workflow + selection logic)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

### Bundled scripts — always use `uv run`

If your skill bundles Python scripts, **run them with `uv run`, not the system Python interpreter**.
Never instruct the user (or Claude) to `pip install` anything globally; never assume `python3` resolves to the right interpreter.

`uv run` handles environment isolation, dependency resolution, and Python version pinning in a single command.
For self-contained scripts, use [PEP 723 inline metadata](https://peps.python.org/pep-0723/) so dependencies travel with the file:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich",
#     "httpx",
# ]
# ///
"""What this script does."""
...
```

In `SKILL.md`, reference the script via `${CLAUDE_SKILL_DIR}` so it resolves regardless of working directory:

```markdown
Run the analyser:

\`\`\`bash
uv run ${CLAUDE_SKILL_DIR}/scripts/analyse.py "$ARGUMENTS"
\`\`\`
```

For skills that need a more complex environment (private dependencies, lockfiles), bundle a `pyproject.toml` and `uv.lock` alongside the script and invoke with `uv run --project ${CLAUDE_SKILL_DIR}/scripts ...`.

This keeps skills portable, reproducible, and immune to whatever Python state the user happens to have on their machine.

### Dynamic context injection

The `` !`<command>` `` syntax runs a shell command **before** the skill is sent to Claude and replaces the placeholder with the command's stdout.
Use this to ground the skill in live state (current diff, current branch, current PR comments) instead of expecting Claude to fetch it.

```markdown
---
name: summarise-changes
description: Summarises uncommitted changes and flags risks. Use when the user asks what changed, wants a commit message, or asks to review their diff.
---

## Current changes

!`git diff HEAD`

## Instructions

Summarise the diff above in two or three bullets, then list risks (missing error handling, hardcoded values, untested paths). If the diff is empty, say so.
```

For multi-line commands, use a fenced block opened with ` ```! ` instead of inline:

````markdown
## Environment

```!
node --version
uv --version
git status --short
```
````

This is preprocessing — Claude only sees the resolved output, not the command.
If the command is expensive or has side effects, prefer letting Claude run it via `Bash` so the user can see what is happening.

The setting `disableSkillShellExecution: true` blocks this for user, project, plugin, and additional-directory skills (commands are replaced with `[shell command execution disabled by policy]`).
Bundled and managed skills are unaffected.

### Run in a forked subagent

Add `context: fork` to run the skill in an isolated subagent context.
The skill body becomes the subagent's prompt; it does **not** see the parent conversation history.

```yaml
---
name: deep-research
description: Research a topic thoroughly with read-only exploration tools.
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep.
2. Read and analyse the code.
3. Summarise findings with specific file:line references.
```

Use `context: fork` only for skills with explicit, actionable instructions.
A skill that says "use these API conventions" without a task will return nothing useful when forked, because the subagent receives the conventions but no prompt to act on.

The `agent` field selects the execution environment (model, tools, permissions).
`Explore` is read-only and optimised for codebase navigation; `Plan` is read-only and optimised for planning; `general-purpose` has the full toolset.
Custom subagents from `.claude/agents/` also work.

### Restricting tool use

`allowed-tools` **grants** permission for listed tools without per-use prompting; it does not restrict.
To deny tools, add deny rules in `/permissions`.

Permission syntax: `Skill(name)` for an exact match, `Skill(name *)` for prefix-with-arguments.

```
Skill(commit)         # allow the commit skill
Skill(review-pr *)    # allow review-pr with any arguments
Skill(deploy *)       # deny if placed under deny rules
```

To disable all skills entirely, deny `Skill` in `/permissions`.

### Path-restricted activation

The `paths` field auto-loads the skill only when the user is working with files matching the pattern.
This is useful for skills that are only relevant to a specific subsystem.

```yaml
paths:
    - "src/api/**/*.py"
    - "tests/api/**/*.py"
```

Same glob format as path-specific rules in `CLAUDE.md`.

### Asking for deeper reasoning

Include the literal word `ultrathink` anywhere in the skill body to bump the reasoning budget for the duration of that invocation.
Reserve this for skills where shallow answers are genuinely harmful (architecture decisions, security review, hard debugging).

### The Principle of Lack of Surprise

Skills are loaded into context that already contains user instructions, project conventions, and other skills.
A surprising skill — one that overrides what the user just asked for, conflicts with `CLAUDE.md`, or silently changes formatting — is worse than no skill.

When in doubt, **state the contract explicitly** at the top of the body:

```markdown
This skill produces <X>.
It does not <Y>.
If <edge case>, it returns <fallback> rather than guessing.
```

---

## Phase 3 — Test the skill

A skill that has not been tested is not a finished skill.
Even for trivial skills, run at least one trigger test and one execution test before declaring done.

### 3a. Trigger tests

Verify the skill activates when it should and stays quiet when it shouldn't.

1. Open Claude Code in a project where the skill is installed.
2. Type queries that should trigger the skill.
   Confirm Claude consults it (you'll see the skill name in the activity stream).
3. Type queries that should _not_ trigger the skill.
   Confirm Claude does not consult it.
4. Run `What skills are available?` to confirm the description appears as expected.

If the skill under-triggers, the `description` is missing keywords the user would actually use.
If it over-triggers, the `description` is too vague — narrow it, or add `disable-model-invocation: true` if the skill should only be manual.

### 3b. Execution tests

For each test prompt:

1. Run it with the skill installed.
2. Inspect the output: is it correct, complete, in the expected format?
3. If the skill produces files, save them and have the user open them.
4. If the skill is non-deterministic, run the prompt **at least three times** to gauge variance.

Triggering note: Claude consults skills mainly for tasks it can't trivially handle.
Single-step prompts like _"read this file"_ may not trigger a skill even when the description matches perfectly.
Use substantive test prompts that genuinely benefit from the skill.

### 3c. Description optimisation (Claude Code only)

If you have access to the bundled `claude` CLI and the `skill-creator` example skill is installed at `/mnt/skills/examples/skill-creator/`, you can run its description optimiser.
This script splits a prompt set 60/40 train/test, evaluates the current description (three runs per query for stability), proposes improvements, and iterates.

```bash
uv run python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-from-system-prompt> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from the active session so the test mirrors what the user actually experiences.
The script returns `best_description` selected on the held-out test set, not on training, so it doesn't overfit.
Apply the result by updating the skill's frontmatter.

If the optimiser isn't available, fall back to manual iteration: change one thing at a time, re-run the trigger tests, and keep what improves the score.

---

## Phase 4 — Iterate

Treat the first draft as a hypothesis.
After each test pass:

1. **Note what failed and why.**
   Was it triggering, output format, scope, or correctness?
2. **Make the smallest change that addresses the failure.**
   Avoid rewrites — they conflate multiple changes and obscure what helped.
3. **Re-run the relevant tests.**
4. **Stop when you and the user are satisfied** — not when the skill is perfect.
   Skills can be edited later; live change detection means edits take effect within the session.

When iteration plateaus, expand the test set and run again at larger scale.
Skills that pass twenty diverse prompts are usually robust; skills that pass three are usually overfitted to the prompts you happened to write.

---

## Phase 5 — Distribute

Skills propagate at four scopes — pick the narrowest one that works.

| Scope               | How                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------------- |
| Personal (only you) | `~/.claude/skills/<name>/`. Nothing else to do.                                                           |
| Project (one repo)  | Commit `.claude/skills/<name>/` to version control.                                                       |
| **Plugin**          | Place under `plugins/<plugin>/skills/<name>/` and list the plugin in the marketplace. Namespaced `plugin:name`. |
| Enterprise          | Deploy via managed settings.                                                                              |

The plugin path is what this repository uses.
A consumer adds the marketplace once and installs whichever plugins they want, at whichever scope:

```bash
/plugin marketplace add carelvniekerk/agentic-skills

claude plugin install git@agentic-skills                        # global
claude plugin install research@agentic-skills --scope project   # one repo
```

Because no plugin here pins a `version`, Claude Code uses the git commit SHA — so every push to `main` reaches installed copies on the next update.
Auto-update is off by default for third-party marketplaces; enable it once under `/plugin` → **Marketplaces**, or set `"autoUpdate": true` on the `extraKnownMarketplaces` entry.

There is a fifth, install-free option worth knowing: a plugin directory symlinked into `~/.claude/skills/<name>/` auto-loads as `<name>@skills-dir`, with no marketplace, install, or cache involved.
Useful for developing against a live checkout.

For project skills, review `allowed-tools` carefully before checking in — a skill can grant itself broad tool access, and trusting the workspace activates those grants for everyone who clones the repo.

If `present_files` is available and you've followed the example `skill-creator` workflow, package with:

```bash
uv run python -m scripts.package_skill <path/to/skill-folder>
```

This produces a `.skill` file that can be installed by another user.

---

## Common failure modes and fixes

### Skill never triggers

- The `description` lacks keywords the user actually types.
  Add the user's actual phrasing, including informal versions.
- The skill is shadowed by a higher-precedence skill with the same name (enterprise > personal > project).
  Run `What skills are available?` and check which one Claude is seeing.
- The user's request is a single-step task Claude can handle directly.
  This is expected — skills are mainly for multi-step or specialised work.

### Skill triggers when it shouldn't

- The `description` is too generic.
  Narrow with specific contexts and trigger phrases.
- Add `disable-model-invocation: true` if the skill should only ever be user-invoked.
- Use `paths:` to limit auto-activation to relevant files.

### Skill description gets cut off in the listing

Skill descriptions share a budget that scales at 1% of the context window (fallback 8,000 characters).
If you have many skills, low-priority ones get truncated.

- Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` to raise the limit.
- Set low-priority skills to `"name-only"` in `skillOverrides` (in `.claude/settings.local.json`) — the name still lists, freeing budget for descriptions of skills that need them.
- Tighten the skill's own `description` and `when_to_use` so the key use case fits before the 1,536-character per-skill cap.

### Skill seems to stop influencing behaviour mid-session

The content is almost certainly still in context — Claude is choosing other tools or approaches.
Strengthen the description and the standing instructions in the body, or use [hooks](https://code.claude.com/docs/en/hooks) to enforce behaviour deterministically.
If the skill is large or many other skills were invoked after it, re-invoke it after auto-compaction to restore the full content (auto-compaction keeps only the first 5,000 tokens of each skill, with a 25,000-token combined budget).

### Bundled script fails on someone else's machine

Almost always a Python environment problem.
Switch to `uv run` with PEP 723 inline metadata so dependencies travel with the script.
Reference the script via `${CLAUDE_SKILL_DIR}` so paths don't break when the working directory changes.

---

## Quick checklist before declaring done

- [ ] `name` matches the directory name and uses lowercase + hyphens only.
- [ ] `name` is ≤ 64 characters with no consecutive or leading/trailing hyphens (open Agent Skills spec).
- [ ] `description` is ≤ 1,024 characters (open Agent Skills spec) and includes at least three trigger phrases the user would actually type.
- [ ] `description` + `when_to_use` together fit comfortably under 1,536 characters (Claude Code listing cap).
- [ ] Body is under 500 lines; long material moved to `references/`.
- [ ] Any bundled scripts use `uv run` and reference `${CLAUDE_SKILL_DIR}`.
- [ ] `allowed-tools` lists only what the skill genuinely needs, in Anthropic syntax (`Bash(git *)`).
- [ ] If the skill has side effects, `disable-model-invocation: true` is set.
- [ ] All frontmatter is inline in SKILL.md — there is no `.harness/` directory.
- [ ] The skill sits under `plugins/<plugin>/skills/<name>/`, and that plugin has an entry in `.claude-plugin/marketplace.json`.
- [ ] `claude plugin validate plugins/<plugin>/skills` passes.
- [ ] Trigger tests pass (the skill activates on intended phrases and stays quiet otherwise).
- [ ] Execution tests pass on at least three prompts.
- [ ] Smoke-tested with `claude --plugin-dir plugins/<plugin>` and invoked as `/<plugin>:<name>`.
- [ ] The skill is committed (project) or saved (personal/plugin) at the intended scope.

---

## Template — minimal SKILL.md

Use this as a starting point.

```markdown
---
name: <skill-name>
description: <one sentence: what it does>. Use this skill whenever the user mentions <phrase 1>, <phrase 2>, or <phrase 3> — even if they don't explicitly say <obvious keyword>. The skill enforces <contract>.
allowed-tools: Read Grep
---

# <Skill Name>

<One-paragraph statement of the contract: what it produces, what it doesn't, and the fallback for edge cases.>

## When to use

- <concrete trigger 1>
- <concrete trigger 2>
- <concrete trigger 3>

## Procedure

1. <step>
2. <step>
3. <step>

## Output format

<state expected output explicitly>

## Edge cases

- <edge case>: <expected behaviour>
```

---

## Related documentation

- **Official Agent Skills spec**: <https://agentskills.io>
- **Claude Code skills docs**: <https://code.claude.com/docs/en/skills>
- **Subagents**: <https://code.claude.com/docs/en/sub-agents>
- **Hooks**: <https://code.claude.com/docs/en/hooks>
- **Permissions**: <https://code.claude.com/docs/en/permissions>
- **Plugins**: <https://code.claude.com/docs/en/plugins>
- **Memory / CLAUDE.md**: <https://code.claude.com/docs/en/memory>

---

Repeating the core loop one last time:

1. Capture intent (Phase 0).
2. Choose location and structure (Phase 1).
3. Draft `SKILL.md` (Phase 2).
4. Test triggering and execution (Phase 3).
5. Iterate one change at a time (Phase 4).
6. Distribute at the narrowest scope that works (Phase 5).

Add these as TodoList entries when authoring a skill so no step is silently skipped.
