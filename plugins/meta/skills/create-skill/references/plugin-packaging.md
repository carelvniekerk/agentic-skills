# Plugin packaging and distribution

How to ship a skill inside a plugin, list the plugin in a marketplace, and check that it installs.
Read this when the working repository has `.claude-plugin/marketplace.json` at its root, or when the user asks for a plugin.

## Contents

- Plugin layout
- The manifest and reserved names
- Choosing a plugin
- Marketplace entries
- Validation and installation
- Distribution scopes
- Notes for the agentic-skills repository

## Plugin layout

```text
plugins/<plugin>/
├── .claude-plugin/
│   └── plugin.json        # the manifest, and nothing else in this directory
├── skills/
│   └── <slug>/
│       ├── SKILL.md       # complete frontmatter inline
│       ├── references/
│       ├── scripts/
│       └── assets/
├── agents/                # optional subagents
├── hooks/hooks.json       # optional plugin-wide hooks
└── evals/                 # optional claude plugin eval suite
```

`skills/` and `agents/` are discovered automatically.
Declare their paths in `plugin.json` only when they live somewhere non-standard.
Never reference files outside the plugin directory with `../`, because installs copy only the plugin directory into the cache.

## The manifest and reserved names

The manifest `name` becomes the prefix of every skill, so `name: hello` in a plugin called `tools` runs as `/tools:hello`.
Keep it short.

`claude plugin validate` rejects reserved plugin names.
A plugin name cannot be `claude`, `anthropic`, `anthropics`, `claude-code` or `claude-mods`, cannot start with `claude-`, `anthropic-`, `anthropics-` or `cc-plugin-`, and cannot put "official" beside "claude" or "anthropic".
Name the plugin for what it does.

## Choosing a plugin

Put a skill in the plugin that matches its primary function, not the language it touches.
A plugin is the unit of installation and of context cost, because every enabled plugin's skill descriptions sit in the listing on every turn.
Group skills that are always wanted together, and give a skill wanted in only one project its own plugin so it can be installed at project scope.

When a `.claude/` directory is converted to a plugin by copying, skills do not collide because of the prefix, but hooks run twice while both copies exist.
Remove the original.

## Marketplace entries

Every plugin needs an entry in `.claude-plugin/marketplace.json`, or it will not install:

```json
{ "name": "tools", "source": "./plugins/tools", "category": "workflow", "tags": ["example"] }
```

A `source` is a path from the repository root and must start with `./`.
Do not set `metadata.pluginRoot`: a source short enough to need it fails the schema, and a valid source ignores it.

## Validation and installation

```bash
claude plugin validate .                          # marketplace manifest
claude plugin validate plugins/<plugin>           # plugin manifest
claude plugin validate plugins/<plugin>/skills    # skill frontmatter
```

`validate` checks schema and syntax.
It does not check that a `source` path exists or that the skill behaves, so confirm with an install and with the evaluation in `evaluation.md`.
For a quick load check, run `claude --plugin-dir plugins/<plugin>` and invoke `/<plugin>:<slug>`.

A plugin directory placed or symlinked under `~/.claude/skills/<name>/` with a `.claude-plugin/plugin.json` loads as `<name>@skills-dir` with no marketplace or install, which suits development against a live checkout.

After changing an installed plugin, the user runs `/reload-plugins`, or updates the marketplace and the plugin if it was installed from a remote.

## Distribution scopes

| Scope | How |
| --- | --- |
| Personal | `~/.claude/skills/<name>/` |
| Project | Commit `.claude/skills/<name>/` |
| Plugin | Marketplace entry, then `claude plugin install <plugin>@<marketplace>` with `--scope user`, `project` or `local` |
| Enterprise | Managed settings |
| claude.ai or the API | Upload a zip whose root is the skill folder, with frontmatter limited to the six spec fields |

Pick the narrowest scope that works.

## Notes for the agentic-skills repository

- Plugin manifests omit `version`, so installs track the git commit SHA.
`validate` warns about the missing field, and the warning is expected.
- Third-party marketplace auto-update is off by default.
Enable it under `/plugin`, then **Marketplaces**.
- Add each new plugin to the plugin tables in `CLAUDE.md` and `README.md`.
- Write skills with one sentence per line in the source, and finish any skill that touches git, the filesystem or a remote service with a strict prohibitions table.
