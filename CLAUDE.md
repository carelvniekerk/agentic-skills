# CLAUDE.md

> Conventions for authoring and organising skills in this repository.

This repo is a personal library of Claude Code skills, grouped into category folders.
Each skill lives in its own directory under a category and is described by a single `SKILL.md` file.

---

## Repository Layout

```text
AgenticSkills/
├── Configuration/        configuration / dotfile management
│   └── dotset/
├── Debugging/            diagnosis and investigation skills
│   └── bug-discovery/
├── Git/                  version-control workflow skills
│   ├── commit/
│   └── pr/
└── HuggingFace/          Hugging Face hub interactions
    └── hf/
```

Each leaf directory contains exactly one `SKILL.md`.
Categories are organisational only — Claude Code's skill loader still requires a flat directory at install time, so the README documents how to flatten on install.

---

## Where New Skills Go

Place a new skill under the existing category that matches its **primary function**, not the language ecosystem it touches.

| Category         | Belongs here                                               |
| ---------------- | ---------------------------------------------------------- |
| `Git/`           | Anything driven by `git` or `gh` — commits, PRs, branches  |
| `Configuration/` | Project setup, dotfiles, environment management            |
| `Debugging/`     | Diagnosis, root-cause analysis, evidence gathering         |
| `HuggingFace/`   | HF hub, models, datasets, inference providers              |

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
- `description` — drives auto-loading.
  Pack it with the verbs and nouns a user would actually say when the skill should fire.
  Long, trigger-rich descriptions are fine when the skill is meant to load aggressively.

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

When a skill's commit-message templates include a `Co-Authored-By` line, keep the model name **agnostic**:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

Do not hard-code a specific model version (`Claude Sonnet 4.6`, `Claude Opus 4.7`).
The harness rotates models, and stale strings drift away from reality.

### Strict prohibitions

If the skill is about Git or any external action, finish with a "Strict Prohibitions" table that lists hooks-bypassing flags, destructive flags, force-push patterns, and credential leaks.
This is the safety contract.

---

## Adding a Skill — Checklist

1. Pick (or create) the right category folder.
2. Create `<Category>/<slug>/SKILL.md`.
3. Write the frontmatter — `name` matches the folder, `description` is trigger-rich.
4. Draft the body in **semantic line breaks** as you type.
5. If the skill runs commands, finish with a Strict Prohibitions table.
6. Verify the rendered output looks right in your editor's Markdown preview.
7. Update `README.md` if the category list changed.

No build step.
No code is needed to manage the file — keep editing the markdown by hand.

---

## What Not to Do

- Do not nest `<Category>/<skill>/SKILL.md` inside `~/.claude/skills/`.
  The Claude Code loader only reads the top level of `~/.claude/skills/`.
  The README explains how to flatten on install.
- Do not reflow paragraphs into long single lines in the source.
  Sentence-per-line is the convention; long lines defeat the diff benefit.
- Do not write a script to enforce semantic line breaks.
  The rule is small, easy to follow by hand, and unambiguous when you author skills sentence-by-sentence.
- Do not bake model versions into commit-message templates.
- Do not skip the prohibitions table for skills that touch Git, the filesystem, or remote services.
