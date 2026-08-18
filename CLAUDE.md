# CLAUDE.md

> Conventions for authoring and organising the skills, agents, and plugins in this repository.

This repo is a personal library of Claude Code skills and subagents, grouped into installable **plugins** and published through a **plugin marketplace** hosted from this same repository.

---

## Repository Layout

```text
agentic-skills/
├── .claude-plugin/
│   └── marketplace.json      the marketplace catalogue — one entry per plugin
├── .claude/skills/           authoring meta-skills (project-scoped; not published)
│   ├── create-skill/         author skills
│   ├── create-hook/          author hooks
│   └── create-agent/         author subagents
└── plugins/                  every published plugin
    ├── git/
    │   ├── .claude-plugin/plugin.json
    │   └── skills/
    │       ├── commit/SKILL.md
    │       └── pr/SKILL.md
    ├── debug/
    ├── config/
    ├── hf/
    ├── langchain/
    └── research/
        ├── .claude-plugin/plugin.json
        ├── skills/           deep-research, literature-review, peer-review, …
        └── agents/           researcher.md, reviewer.md, verifier.md, writer.md
```

Every plugin directory is self-contained.
Its manifest lives at `<plugin>/.claude-plugin/plugin.json`, and **only** the manifest goes in that directory.
`skills/`, `agents/`, `hooks/`, and `.mcp.json` all sit at the plugin root, never inside `.claude-plugin/`.

The `.claude/skills/` directory is the Claude Code loader's project-scoped location and holds **meta-skills only**.
They are not published, and they load only when Claude Code runs from this repository.

---

## The Six Plugins

| Plugin      | Contains                                                                                                                   | Invoked as                     |
| ----------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| `git`       | commit, pr                                                                                                                 | `/git:commit`                  |
| `debug`     | bug-discovery                                                                                                              | `/debug:bug-discovery`         |
| `config`    | dotset                                                                                                                     | `/config:dotset`               |
| `hf`        | hf                                                                                                                         | `/hf:hf`                       |
| `langchain` | langgraph-multi-agent-architect                                                                                            | `/langchain:langgraph-…`       |
| `research`  | deep-research, external-research, literature-review, source-comparison, eli5, paper-draft, peer-review, paper-code-audit + 4 agents | `/research:deep-research`      |

Plugin skills are **always** namespaced by the plugin name.
The plugin's `name` field is therefore the slash prefix your future self types every day — keep it short.

---

## Where New Skills and Agents Go

Add a new skill to the plugin that matches its **primary function**, not the language ecosystem it touches.
A skill about Python dotfiles belongs in `config`, not a new `python` plugin.

Create a new plugin only when no existing one fits, and only when you would want to install it independently of the others.
A plugin is the unit of installation and of context cost — every enabled plugin's skill descriptions load on every turn.
Two skills that are always wanted together belong in one plugin; a skill you would want in only one project belongs in its own.

When you add a plugin you must also add its entry to `.claude-plugin/marketplace.json`, or it will not be installable.

---

## Skill File Structure

A skill is a directory under `<plugin>/skills/` containing a `SKILL.md` with YAML frontmatter:

```markdown
---
name: <slug>
description: <one or two sentences with the trigger words the loader will match on>
allowed-tools: Read Grep Bash(git *)
---

<skill body — instructions, phases, references>
```

Frontmatter rules:

- `name` — the slug, matching the directory name.
  Must be ≤ 64 characters, lowercase letters / digits / hyphens, no leading or trailing hyphen, no consecutive hyphens.
  Always set it explicitly; without it the invocation name falls back to the install directory name, which is unstable across updates.
- `description` — drives auto-loading.
  Pack it with the verbs and nouns you would actually say when the skill should fire.
  Must be ≤ 1,024 characters.
- `allowed-tools` — Anthropic syntax, space-separated: `Bash(git *)`, not `Bash(git:*)`.
- `when_to_use`, `argument-hint`, `disable-model-invocation`, `model`, `effort`, `paths`, `hooks` — all optional, all inline.

Everything goes in the one file.
There is no `.harness/` split any more; Claude Code reads `SKILL.md` frontmatter directly and performs no merge.

Supporting assets — `references/`, `scripts/`, `assets/` — sit beside `SKILL.md` inside the skill directory and travel with it.
Reference bundled files from the skill body with `${CLAUDE_PLUGIN_ROOT}` when a command needs an absolute path.

---

## Agent File Structure

An agent is a single Markdown file directly under `<plugin>/agents/`:

```markdown
---
name: researcher
description: <what it does, when to use it proactively, and its trigger phrases>
tools: WebSearch, WebFetch, Read, Write
model: sonnet
permissionMode: acceptEdits
color: blue
---

<system prompt>
```

Agents are namespaced like skills — the file above is `research:researcher` in the `@`-mention typeahead.
`tools` is comma-separated here, unlike a skill's space-separated `allowed-tools`.

---

## Plugin Manifest

Each plugin needs `<plugin>/.claude-plugin/plugin.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "git",
  "description": "Thorough Git workflows — …",
  "author": { "name": "Carel van Niekerk", "email": "code@carelvanniekerk.com" },
  "homepage": "https://github.com/carelvniekerk/agentic-skills",
  "repository": "https://github.com/carelvniekerk/agentic-skills",
  "license": "MIT",
  "keywords": ["git", "commit", "pull-request"]
}
```

`name` must match the directory name and the marketplace entry.
The `skills/` and `agents/` directories are discovered automatically — do not list them unless they live somewhere non-standard.

**`version` is deliberately omitted.**
With no version set, Claude Code falls back to the git commit SHA, so every push propagates to installed copies on the next update.
Adding an explicit `version` pins the plugin to that string and installs stop updating until you bump it.
`claude plugin validate` warns about the missing field; that warning is expected and intentional here.

---

## Marketplace Catalogue

`.claude-plugin/marketplace.json` at the repo root lists every plugin.
`metadata.pluginRoot` is set to `./plugins`, so each `source` is written relative to that:

```json
{
  "name": "agentic-skills",
  "owner": { "name": "Carel van Niekerk" },
  "metadata": { "pluginRoot": "./plugins" },
  "plugins": [
    { "name": "git", "source": "./git", "category": "workflow", "tags": ["git", "commit"] }
  ]
}
```

Relative sources keep every plugin inside this one repository.
That is what makes the marketplace work from a private repo and avoids a second repository per plugin.

Run both validators before committing:

```bash
claude plugin validate .                 # the marketplace manifest
claude plugin validate plugins/<name>    # a plugin manifest
claude plugin validate plugins/<name>/skills   # the skill files themselves
```

---

## Pre-commit

`pre-commit install` wires up the hooks in `.pre-commit-config.yaml`.
They run the three `claude plugin validate` invocations above automatically, alongside whitespace, JSON, and spelling checks.

`markdownlint-cli2` runs with `--fix`, configured by `.markdownlint-cli2.jsonc`.
Most of its default rule set is switched off, because it assumes soft-wrapped prose and would fight the semantic-line-break convention on every line.
What stays on catches genuine breakage rather than style: dead in-document anchor links, unbalanced code fences, repeated sibling headings, stray blank lines.
That is not hypothetical — enabling it surfaced five unbalanced fences in the `hf` skill that had been silently swallowing about 250 lines of its body.

If a rule starts fighting you rather than helping, switch it off in `.markdownlint-cli2.jsonc` with a comment saying why.
Do not suppress a finding inline unless it is genuinely a one-off false positive.

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

When a skill's commit-message templates include a `Co-Authored-By` line, keep it **model-agnostic**:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

Name the assistant platform, never a specific model version (`Claude Sonnet 4.6`, `Opus 5`).
The harness rotates models, and a hard-coded string drifts away from reality within weeks.

### Strict prohibitions

If the skill is about Git or any external action, finish with a "Strict Prohibitions" table that lists hooks-bypassing flags, destructive flags, force-push patterns, and credential leaks.
This is the safety contract.

---

## Authoring Meta-Skills

Three skills under `.claude/skills/` automate the authoring of new Claude Code primitives.
Use them whenever you create or refine the corresponding artefact instead of writing the file from scratch:

| Skill          | For authoring                                                                                         |
| -------------- | ----------------------------------------------------------------------------------------------------- |
| `create-skill` | A new `SKILL.md` — any skill under `plugins/<plugin>/skills/`, or a skill bundled inside a plugin.     |
| `create-hook`  | A hook entry — `settings.json`, plugin `hooks/hooks.json`, or skill/agent frontmatter `hooks:` field.  |
| `create-agent` | A subagent definition under `plugins/<plugin>/agents/`.                                                |

These meta-skills are aware of each other.
When a job needs more than one primitive — a skill that bundles a hook, an agent with preloaded skills, a hook scoped to a specific subagent — each delegates to its sibling via the `Skill` tool rather than reimplementing the workflow inline.

---

## Adding a Skill — Checklist

1. Pick the plugin whose primary function matches, or create a new one (see below).
2. Create `plugins/<plugin>/skills/<slug>/SKILL.md` with complete frontmatter — `name`, `description`, and whatever Claude extensions the skill needs.
3. Invoke the `create-skill` meta-skill (or `/create-skill`) and let it drive the draft → test → review loop.
4. Draft the body in **semantic line breaks** as you type.
5. Put supporting assets in `references/`, `scripts/`, or `assets/` beside `SKILL.md`.
6. If the skill runs commands, finish with a Strict Prohibitions table.
7. Validate: `claude plugin validate plugins/<plugin>/skills`.
8. Smoke-test it loads: `claude --plugin-dir plugins/<plugin>`, then invoke `/<plugin>:<slug>`.
9. Update `README.md` if the plugin's contents table changed.

## Adding an Agent — Checklist

1. Pick the plugin it belongs to.
2. Create `plugins/<plugin>/agents/<slug>.md` with full frontmatter — `name`, `description`, `tools`, `model`, `permissionMode`, `color` — plus the system prompt as the body.
3. Invoke the `create-agent` meta-skill if you need help.
4. Validate: `claude plugin validate plugins/<plugin>/agents`.
5. Smoke-test: `claude --plugin-dir plugins/<plugin>`, then check `<plugin>:<slug>` appears in `/context` under Custom Agents.

## Adding a Plugin — Checklist

1. `mkdir -p plugins/<name>/{.claude-plugin,skills}`.
2. Write `plugins/<name>/.claude-plugin/plugin.json` — no `version` field.
3. Add the entry to `.claude-plugin/marketplace.json` with `"source": "./<name>"`.
4. Validate both: `claude plugin validate .` and `claude plugin validate plugins/<name>`.
5. Add a row to the plugin table in this file and in `README.md`.

No build step.
No generated files.
Everything is hand-edited markdown and JSON.

---

## What Not to Do

- Do not put `skills/`, `agents/`, or `hooks/` inside `.claude-plugin/`.
  Only `plugin.json` goes there; everything else sits at the plugin root.
- Do not reintroduce a `.harness/` directory.
  Claude Code reads `SKILL.md` frontmatter directly and merges nothing.
  The split existed to serve Codex and Copilot, which this repo no longer targets.
- Do not add a `version` field to a plugin manifest unless you intend to hand-bump it on every change.
  The git SHA fallback is what keeps installs current.
- Do not reference files outside a plugin's own directory with `../`.
  Installed plugins are copied into `~/.claude/plugins/cache/`, and anything outside the plugin root is left behind.
  Use symlinks if two plugins genuinely must share a file.
- Do not create a plugin per skill.
  Each enabled plugin costs context on every turn; group skills you would install together.
- Do not reflow paragraphs into long single lines in the source.
  Sentence-per-line is the convention; long lines defeat the diff benefit.
- Do not write a script to enforce semantic line breaks.
  The rule is small, easy to follow by hand, and unambiguous when you author skills sentence-by-sentence.
- Do not bake model versions into commit-message templates.
- Do not skip the prohibitions table for skills that touch Git, the filesystem, or remote services.
