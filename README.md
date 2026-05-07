# AgenticSkills

A personal library of [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, organised by category.
Each skill is a single `SKILL.md` file with YAML frontmatter that the Claude Code skill loader picks up at runtime.

For authoring conventions (folder taxonomy, semantic line breaks, frontmatter rules), see [`CLAUDE.md`](./CLAUDE.md).

---

## Skills in this repo

| Category         | Skill           | Purpose                                                                                  |
| ---------------- | --------------- | ---------------------------------------------------------------------------------------- |
| `Configuration/` | `dotset`        | Manage project dotfiles (`.gitignore`, `.uvgroups`, `.envrc`, …) via the `dotset` CLI    |
| `Debugging/`     | `bug-discovery` | Diagnostic-first debugging: gather evidence, search exhaustively, write a ranked report  |
| `Git/`           | `commit`        | Thorough commit workflow with code review, logical grouping, and pre-commit hook respect |
| `Git/`           | `pr`            | End-to-end pull request workflow: tests, lint, type-check, review, open, merge, resync   |
| `HuggingFace/`   | `hf`            | Hugging Face hub assistant — model / dataset profiles, prompt templates, agentic search  |

---

## Installing into Claude Code

Claude Code's skill loader reads from a flat directory — it does **not** recurse into category folders.
The category structure here is for organisation only; on install, each skill is placed directly under the target skills directory.

There are three common scopes:

| Scope             | Path                                      | Available where                        |
| ----------------- | ----------------------------------------- | -------------------------------------- |
| User              | `~/.claude/skills/<name>/SKILL.md`        | Every project on this machine          |
| Project (skill)   | `<repo>/.claude/skills/<name>/SKILL.md`   | Inside this repo only                  |
| Project (command) | `<repo>/.claude/commands/<name>.md`       | Inside this repo, invoked as `/<name>` |

Pick whichever scope matches how broadly you want the skill available.

### Install with `gh skills`

The [`gh skills`](https://docs.github.com/en/copilot/concepts/agents/agent-skills) CLI extension installs skills directly from this GitHub repository (`carelvniekerk/agentic-skills`).
Pass the skill's path within the repo as the second argument.

```bash
# user scope — available in every project on this machine
gh skill install carelvniekerk/agentic-skills Git/commit/SKILL.md \
  --agent claude-code --scope user

# project scope — writes to ./.claude/skills/ in the current repo
gh skill install carelvniekerk/agentic-skills Git/commit/SKILL.md \
  --agent claude-code --scope project

# project-level slash command — writes to ./.claude/commands/ so it loads as /commit
gh skill install carelvniekerk/agentic-skills Git/commit/SKILL.md \
  --dir .claude/commands
```

`--dir` overrides `--agent` and `--scope`, so the third form is exactly how you "install as a project-level command".

To pin a skill to a specific revision, append `@<tag-or-sha>` to the skill argument or pass `--pin <ref>`:

```bash
gh skill install carelvniekerk/agentic-skills Git/commit/SKILL.md@v1.0.0 \
  --agent claude-code --scope user
```

To install all skills at once at user scope:

```bash
for path in \
    Configuration/dotset/SKILL.md \
    Debugging/bug-discovery/SKILL.md \
    Git/commit/SKILL.md \
    Git/pr/SKILL.md \
    HuggingFace/hf/SKILL.md; do
  gh skill install carelvniekerk/agentic-skills "$path" \
    --agent claude-code --scope user
done
```

---

## Verifying the install

After install, restart Claude Code (or reload the workspace) and confirm the skill is loaded:

- User-scope skills appear in every session's available skills list.
- Project-scope skills appear only when Claude Code is launched from the project root.
- Slash commands appear by their filename: `commit.md` → `/commit`.

If a skill does not appear:

- Confirm `<target>/<name>/SKILL.md` exists (skills) or `<target>/<name>.md` exists (commands).
- Verify the YAML frontmatter `name:` matches the directory or filename.
- Reload Claude Code — skills are read at startup.

---

## Updating an installed skill

```bash
gh skill update --agent claude-code
```

`gh skills install` injects source-tracking metadata into the installed skill's frontmatter, so `gh skill update` knows where each skill came from and can refresh it from the upstream repo.

---

## Uninstalling

```bash
# user scope
rm -rf ~/.claude/skills/<name>

# project scope
rm -rf ./.claude/skills/<name>

# project-level command
rm ./.claude/commands/<name>.md
```

---

## Contributing a skill

See [`CLAUDE.md`](./CLAUDE.md) for the authoring conventions used in this repo (category placement, frontmatter, semantic line breaks, prohibitions tables).
