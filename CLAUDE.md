# CLAUDE.md

> Conventions for authoring and organising the skills and agents in this repository.

This repo is a personal library of agentic skills and subagents, grouped into category folders and published across Claude Code, OpenAI Codex, and GitHub Copilot via the [SkillShed](https://github.com/carelvniekerk/SkillShed) installer.

---

## Repository Layout

```text
AgenticSkills/
├── .claude/skills/           authoring meta-skills (project-scoped; not published)
│   ├── create-skill/         author skills (multi-harness aware)
│   ├── create-hook/          author hooks
│   └── create-agent/         author subagents; bundles md_to_toml.py for Codex
├── skills/                   published skills (installable via SkillShed)
│   ├── Configuration/
│   │   └── dotset/
│   ├── Debugging/
│   │   └── bug-discovery/
│   ├── Git/
│   │   ├── commit/
│   │   └── pr/
│   ├── HuggingFace/
│   │   └── hf/
│   └── Research/
│       └── ...               deep-research, eli5, literature-review, …
└── agents/                   published subagents (installable via SkillShed)
    └── Research/
        ├── researcher.md     single-file agent (canonical Anthropic .md)
        ├── reviewer.md
        ├── verifier.md
        └── writer.md
```

Each leaf skill directory under `skills/` contains exactly one `SKILL.md` plus optional supporting assets.
Agents under `agents/` may be either a single file `agents/<Category>/<slug>.md` or a directory `agents/<Category>/<slug>/<slug>.md` with supporting assets; SkillShed handles both.
The `.claude/skills/` directory is the Claude Code loader's project-scoped location and holds **meta-skills only** — they are not published to the SkillShed-installable library.

---

## Where New Skills and Agents Go

Place a new skill under `skills/<Category>/`, or a new subagent under `agents/<Category>/`, picking the category that matches its **primary function** — not the language ecosystem it touches.

| Category         | Belongs here                                                            |
| ---------------- | ----------------------------------------------------------------------- |
| `Git/`           | Anything driven by `git` or `gh` — commits, PRs, branches               |
| `Configuration/` | Project setup, dotfiles, environment management                         |
| `Debugging/`     | Diagnosis, root-cause analysis, evidence gathering                      |
| `HuggingFace/`   | HF hub, models, datasets, inference providers                           |
| `Research/`      | Literature search, deep research, peer review, paper-code audits, ELI5  |

Create a new top-level category folder only when no existing one fits.
A skill that touches Python tooling but is fundamentally about configuration belongs under `Configuration/`, not a new `Python/` folder.

---

## Skill File Structure

A skill is a single Markdown file with YAML frontmatter:

```markdown
---
name: <slug>
description: <one or two sentences with trigger words the loader will match on>
---

<skill body — instructions, phases, references>
```

Required frontmatter:

- `name` — the slug Claude Code uses to invoke the skill (matches the directory name).
  Must be ≤ 64 characters, lowercase letters / digits / hyphens, no leading or trailing hyphen, no consecutive hyphens.
- `description` — drives auto-loading.
  Pack it with the verbs and nouns a user would actually say when the skill should fire.
  Must be ≤ 1,024 characters (open Agent Skills spec cap).
  Long, trigger-rich descriptions are fine when the skill is meant to load aggressively.

---

## Multi-harness publishing (SkillShed)

The skills and agents in this repo are installed into three assistant platforms by the [SkillShed](https://github.com/carelvniekerk/SkillShed) CLI: Claude Code, OpenAI Codex, and GitHub Copilot.
SkillShed reads each entity's `SKILL.md` / `.md` from this repo, merges in optional per-harness overrides, injects a `metadata:` block recording the source commit SHA, and writes the result into the harness's expected directory.

### Install paths SkillShed writes to

| Harness  | Skills (project)         | Skills (global)         | Agents (project)    | Agents (global)         |
| -------- | ------------------------ | ----------------------- | ------------------- | ----------------------- |
| claude   | `.claude/skills/`        | `~/.claude/skills/`     | `.claude/agents/`   | `~/.claude/agents/`     |
| codex    | `.agents/skills/`        | `~/.agents/skills/`     | `.codex/agents/`    | `~/.codex/agents/`      |
| copilot  | `.agents/skills/`        | `~/.agents/skills/`     | `.claude/agents/` * | `~/.copilot/agents/`    |

\* SkillShed's Copilot agent project path is currently `.claude/agents/`; Copilot CLI actually reads from `.github/agents/`.
The global path (`~/.copilot/agents/`) is correct.
For Copilot agents, prefer `skillshed install -g` until the project-path bug is fixed.

### Authoring rules

These rules are how this repo stays portable across all three harnesses.
The `create-skill` and `create-agent` meta-skills enforce them as part of their workflows.

- **Skills are authored as one canonical SKILL.md** with Claude-style frontmatter.
  Codex and Copilot read the same file from `.agents/skills/`, so the frontmatter must work for all three at once.
  `name` and `description` are the only universally required keys; everything else either comes from the open Agent Skills spec (`license`, `compatibility`, `metadata`, `allowed-tools`) or is a Claude extension that Codex / Copilot ignore safely.
- **Do not author `.harness/copilot.yaml` or `.harness/codex.yaml` for skills.**
  Those harnesses share the `.agents/skills/` install path; per-harness frontmatter overrides defeat that.
  Keep SKILL.md Claude-canonical and let the other harnesses skip unknown keys.
- **Codex-only UI / policy / MCP-server dependencies live in `agents/openai.yaml`** inside the skill directory, committed as a regular asset (not under `.harness/`).
  SkillShed copies it through verbatim.
- **Agents are authored as one canonical Anthropic-style `.md`** under `agents/<Category>/` (single file) or `agents/<Category>/<slug>/<slug>.md` (directory).
  The body is the system prompt.
  Codex requires a separate `.toml` sibling — the `create-agent` meta-skill bundles `scripts/md_to_toml.py` to generate it from the `.md`.
  Both files are committed; SkillShed picks the right one per harness.
- **Codex-only optional agent fields** (`nickname_candidates`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`) are declared via a top-level `codex:` block in the canonical `.md`'s YAML frontmatter; the transpiler lifts them into the emitted `.toml`.

### `.skills.yaml` example

A consumer adds something like this to their `.skills.yaml` and runs `skillshed install`:

```yaml
skills:
  - repo: carelvniekerk/AgenticSkills
    path: skills/Git/commit
    harnesses: [claude, codex, copilot]

agents:
  - repo: carelvniekerk/AgenticSkills
    path: agents/Research/researcher.md
    harnesses: [claude, copilot]
  - repo: carelvniekerk/AgenticSkills
    path: agents/Research/researcher.toml
    harnesses: [codex]
```

The pattern above ships the Anthropic `.md` to Claude and Copilot and the transpiled `.toml` to Codex.
For skills, one entry covers all three harnesses because the file format is the same.

---

## Authoring Conventions

### Semantic line breaks (one sentence per line)

In the **source markdown**, every sentence sits on its own line.
A markdown renderer collapses consecutive non-blank lines within a paragraph into one rendered line, so the visual output is identical to a soft-wrapped paragraph.
The benefit is in `git diff`: editing a single sentence produces a one-line diff instead of a re-flowed paragraph.

Keep this in mind when **writing** skills — type each sentence on a new line as you go.
Do not rely on a script or post-processing tool to do it for you.
The convention is yours to maintain by hand.

Within a list item, the same rule applies: the bullet marker stays on the first line, and continuation sentences sit on subsequent unindented lines.
A blank line ends the paragraph or list item.

```markdown
- This is one bullet.
The bullet continues here, still in the same item.
And this third sentence is also in the same bullet.

- This is the next bullet.
```

### Style and tone

- Address the agent directly ("You are a meticulous commit assistant.").
- Lead with intent, then enumerate phases or steps.
- Use phase tables / numbered phases when the workflow is strictly ordered.
- Use bullet lists for unordered options or considerations.
- Prefer short, instructional sentences over long explanatory ones.
- Avoid filler ("It is important to note that…") — state the rule directly.

### Code in skill bodies

Use fenced code blocks for commands the skill should run.
Prefer triple-backtick fences with a language tag (` ```bash `, ` ```python `).
If the skill needs to **document** a Markdown template that itself contains code blocks, use four-backtick outer fences (` ```` `) so the inner three-backtick fences nest correctly.

### Co-authored-by trailers

When a skill's commit-message templates include a `Co-Authored-By` line, keep the model name **platform-specific but model-agnostic**:

```
Co-Authored-By: Codex <noreply@openai.com>
Co-Authored-By: Gemini <noreply@google.com>
```

Use the assistant platform currently performing the work, such as `Codex`, `Gemini`, or `Claude`, with that platform's no-reply email.
Do not hard-code a specific model version (`GPT-5.4`, `Gemini 2.5 Pro`, `Claude Sonnet 4.6`).
The harness rotates models, and stale strings drift away from reality.

### Strict prohibitions

If the skill is about Git or any external action, finish with a "Strict Prohibitions" table that lists hooks-bypassing flags, destructive flags, force-push patterns, and credential leaks.
This is the safety contract.

---

## Authoring Meta-Skills

Three skills under `.claude/skills/` automate the authoring of new Claude Code primitives.
Use them whenever you create or refine the corresponding artefact instead of writing the file from scratch:

| Skill          | For authoring                                                                                                                                                                                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `create-skill` | A new `SKILL.md` — any leaf skill under `skills/` in this repo, or a skill bundled inside a plugin or agent. Aware of the SkillShed multi-harness install rules above.                                                              |
| `create-hook`  | A hook entry — `settings.json`, plugin `hooks/hooks.json`, or skill/agent frontmatter `hooks:` field. Notes which hooks travel with SkillShed-installed entities.                                                                    |
| `create-agent` | A subagent definition — Anthropic-style `.md` under `agents/<Category>/` plus a transpiled Codex `.toml` sibling (via the bundled `scripts/md_to_toml.py`). Documents Copilot CLI compatibility and the SkillShed install paths.    |

These meta-skills are aware of each other.
When a job needs more than one primitive — e.g. a skill that bundles a hook, an agent with preloaded skills, or a hook scoped to a specific subagent — each skill delegates to its sibling via the `Skill` tool rather than reimplementing the workflow inline.
The "Companion skills" section near the top of each meta-skill enumerates the common compositions.

Each meta-skill enforces the project conventions documented above (semantic line breaks, platform-specific model-agnostic Co-Authored-By trailers, prohibitions tables for skills that touch Git or the filesystem), so using them keeps new artefacts consistent with the rest of the repo.

---

## Adding a Skill — Checklist

1. Pick (or create) the right category folder under `skills/`.
2. Create `skills/<Category>/<slug>/SKILL.md`.
3. Invoke the `create-skill` meta-skill (or `/create-skill`) and let it drive the draft → test → review loop.
   For hooks or subagents, invoke `create-hook` or `create-agent` instead — and the meta-skills will delegate to each other when a composite artefact is needed.
4. Write the frontmatter — `name` matches the folder, ≤ 64 chars, lowercase + hyphens; `description` is trigger-rich and ≤ 1,024 chars.
5. Draft the body in **semantic line breaks** as you type.
6. If the skill runs commands, finish with a Strict Prohibitions table.
7. Verify there is no `.harness/copilot.yaml` or `.harness/codex.yaml` inside the skill directory (SkillShed rule for shared install paths).
8. If the skill needs Codex-specific UI / policy / MCP-server config, commit `agents/openai.yaml` inside the skill directory.
9. Verify the rendered output looks right in your editor's Markdown preview.
10. Update `README.md` if the category list changed.

## Adding an Agent — Checklist

1. Pick (or create) the right category folder under `agents/`.
2. Create `agents/<Category>/<slug>.md` (single-file) or `agents/<Category>/<slug>/<slug>.md` (directory with assets).
3. Invoke the `create-agent` meta-skill — it covers Anthropic / Codex / Copilot frontmatter conventions and runs the transpile step.
4. Write the canonical Anthropic-style `.md` with frontmatter (`name`, `description`, `model`, `tools`, etc.) and a system-prompt body.
5. Declare any Codex-only optional fields under a top-level `codex:` block in the YAML frontmatter.
6. Run the transpiler to emit a sibling `.toml` for Codex:

   ```bash
   uv run .claude/skills/create-agent/scripts/md_to_toml.py agents/<Category>/<slug>.md
   ```
7. Commit both the `.md` and the `.toml`.
   SkillShed picks the right one per harness.

No build step.
No code is needed to manage the file — keep editing the markdown by hand.
The transpiler is the only generated artefact; re-run it whenever you edit the `.md`.

---

## What Not to Do

- Do not nest `<Category>/<skill>/SKILL.md` inside `~/.claude/skills/`.
  The Claude Code loader only reads the top level of `~/.claude/skills/`.
  SkillShed handles flattening at install time; you do not need to flatten by hand.
- Do not author `.harness/copilot.yaml` or `.harness/codex.yaml` inside a skill directory.
  Codex and Copilot share the same install path (`.agents/skills/`) and would both end up reading whatever override you wrote.
  Codex-specific UI / policy / MCP-server config goes in `agents/openai.yaml` instead (a regular asset, not under `.harness/`).
- Do not hand-edit the generated `.toml` for a Codex agent.
  Re-run `scripts/md_to_toml.py` whenever the canonical `.md` changes; the `.toml` is derived, not authored.
- Do not reflow paragraphs into long single lines in the source.
  Sentence-per-line is the convention; long lines defeat the diff benefit.
- Do not write a script to enforce semantic line breaks.
  The rule is small, easy to follow by hand, and unambiguous when you author skills sentence-by-sentence.
- Do not bake model versions into commit-message templates.
- Do not skip the prohibitions table for skills that touch Git, the filesystem, or remote services.
