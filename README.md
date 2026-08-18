# AgenticSkills

A personal library of [Claude Code](https://code.claude.com/docs) skills and subagents, packaged as installable **plugins** and served from a **plugin marketplace** hosted in this repository.

For authoring conventions (plugin layout, frontmatter rules, semantic line breaks), see [`CLAUDE.md`](./CLAUDE.md).

---

## Plugins

| Plugin      | Skills                                                                                                                    | Agents                                     |
| ----------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `git`       | `commit`, `pr`                                                                                                            | —                                          |
| `debug`     | `bug-discovery`                                                                                                           | —                                          |
| `config`    | `dotset`                                                                                                                  | —                                          |
| `hf`        | `hf`                                                                                                                      | —                                          |
| `langchain` | `langgraph-multi-agent-architect`                                                                                         | —                                          |
| `research`  | `deep-research`, `external-research`, `literature-review`, `source-comparison`, `eli5`, `paper-draft`, `peer-review`, `paper-code-audit` | `researcher`, `writer`, `verifier`, `reviewer` |

### What each one does

- **`git`** — conversation-aware commits that review every diff and split unrelated changes into separate logical commits, plus an end-to-end pull request flow with tests, lint, type-check, explicit review gates, and merge.
Never bypasses hooks, never force-pushes.

- **`debug`** — diagnostic-first debugging.
Gathers environment and run-condition evidence, reads the code and the full terminal output, searches issues and PRs exhaustively, then delivers a ranked hypothesis report and stops for discussion before any fix.

- **`config`** — project dotfile management through the [`dotset`](https://github.com/carelvniekerk/DotSet) CLI: `.gitignore`, `.uvgroups`, `.envrc`, `.cleanup`, `.skyignore`, `.rsync-exclude`.

- **`hf`** — Hugging Face hub assistant: model and dataset profiles, prompt and chat templates, inference providers, licences, linked papers, and search for models suited to agentic or tool-use workloads.
This is the only plugin here that bundles an MCP server — see [Hugging Face MCP](#hugging-face-mcp) below.

- **`langchain`** — multi-agent architecture selection for LangChain and LangGraph.
Argues for a single agent first, then maps constraints onto subagents, handoffs, skills, router, or a custom workflow, and delivers an architecture decision record with an explicit call and token cost model.

- **`research`** — the full research pipeline: evidence gathering, synthesis, citation anchoring, and critique.
Ships four subagents (`researcher` → `writer` → `verifier` → `reviewer`) that the skills delegate to.

---

## Install

Add the marketplace once:

```bash
/plugin marketplace add carelvniekerk/agentic-skills
```

This repository is **private**, so that command only resolves for an account with read access.
Claude Code clones over your existing GitHub credentials — `gh auth status` should show a working login, or an SSH key must be loaded for `git@github.com`.
Without access the command fails at clone time rather than reporting a missing marketplace.

Then install the plugins you want.
Scope decides where they apply:

```bash
# global — available in every project on this machine
claude plugin install git@agentic-skills

# project — shared with collaborators via .claude/settings.json
claude plugin install research@agentic-skills --scope project

# local — this repo only, not committed
claude plugin install debug@agentic-skills --scope local
```

Inside a session, `/plugin install git@agentic-skills` opens the same flow with a scope picker.
If the install summary says `Run /reload-plugins to activate.`, run that; otherwise the plugin is already live.

### Declarative project setup

To have a project pull the marketplace automatically once collaborators trust the folder, add this to that project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "agentic-skills": {
      "source": { "source": "github", "repo": "carelvniekerk/agentic-skills" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "git@agentic-skills": true,
    "research@agentic-skills": true
  }
}
```

Registering the marketplace this way does not fetch the plugins themselves — collaborators still run `claude plugin install` once.
`enabledPlugins` decides what is switched on afterwards.

---

## Using the skills

Plugin skills are namespaced by plugin name:

```text
/git:commit
/git:pr
/debug:bug-discovery
/research:deep-research
/research:peer-review
/langchain:langgraph-multi-agent-architect
```

Most also fire automatically from their `description` — you rarely need to type them.
Two are slash-only by design (`disable-model-invocation: true`): `/research:paper-draft` and `/research:paper-code-audit`.

Agents are namespaced the same way and appear in the `@`-mention typeahead as `research:researcher`, `research:writer`, `research:verifier`, `research:reviewer`.

---

## Hugging Face MCP

The `hf` plugin bundles the official Hugging Face MCP server in `plugins/hf/.mcp.json`, pointed at `https://huggingface.co/mcp?login`.
The `?login` parameter is what Hugging Face's own Claude Code install command uses; it makes the server drive the authentication flow rather than answering unauthenticated.
Installing the plugin is therefore enough — there is no separate connector to configure.

Authenticate once, then restart or `/reload-plugins`:

```bash
claude mcp login huggingface     # or run /mcp inside a session
```

No token goes in the manifest.
The entry deliberately carries no `Authorization` header, because a header the server rejects makes Claude Code report the connection as failed instead of falling back to the OAuth flow.

### If you already use the claude.ai Hugging Face connector

Nothing breaks, and nothing is duplicated.
Plugin servers and claude.ai connectors are matched by endpoint rather than by name, and both resolve to the same Hugging Face endpoint, so Claude Code connects one of them — the plugin copy, which outranks a connector.

The visible consequence is the tool prefix: `mcp__plugin_hf_huggingface__*` when the plugin provides the server, `mcp__claude_ai_Hugging_Face__*` when the connector does.
The `hf` skill allows both and refers to tools by their unqualified names, so it works either way.
Run `/mcp` to see which one is live.

### Which tools you get

The HF server exposes a **per-account** tool set, configured at <https://huggingface.co/settings/mcp>.
Only `hf_fs` is guaranteed; `hub_repo_details`, `hub_repo_search`, `hf_doc_search`, `paper_search`, `space_search`, and the rest are opt-in there.
The skill degrades to `hf_fs`, then `WebFetch`, then `WebSearch` when a tool is absent, and says which fallback it used rather than inventing metadata.

---

## Updating

No plugin here sets a `version`, so Claude Code uses the git commit SHA as the version.
Every push to `main` therefore counts as a new version and flows through to installed copies.

Enable background auto-update once per marketplace — third-party marketplaces have it **off** by default:

`/plugin` → **Marketplaces** → `agentic-skills` → **Enable auto-update**

Or set `"autoUpdate": true` on the `extraKnownMarketplaces` entry as shown above.

To update by hand:

```bash
claude plugin marketplace update            # refresh all marketplace catalogues
claude plugin update git@agentic-skills     # update one plugin
```

There is no built-in "update all plugins" command.
The JSON output makes one easy:

```bash
claude plugin list --json | jq -r '.[].id' | xargs -n1 claude plugin update
```

Updates apply on restart or `/reload-plugins`.

---

## Managing

```bash
claude plugin list                          # what's installed, with scope and version
claude plugin details git                   # component inventory and context cost
claude plugin disable git@agentic-skills    # keep installed, stop loading
claude plugin uninstall git@agentic-skills
```

Installed plugins are cached at `$CLAUDE_CONFIG_DIR/plugins/cache/<marketplace>/<plugin>/<version>/`, and the marketplace clone sits in `$CLAUDE_CONFIG_DIR/plugins/marketplaces/`.

---

## Local development

Test a plugin without installing it:

```bash
claude --plugin-dir plugins/git --plugin-dir plugins/research
```

A `--plugin-dir` copy takes precedence over an installed plugin of the same name for that session, so you can iterate on a plugin you already have installed.
Run `/reload-plugins` to pick up edits without restarting.

Validate before committing:

```bash
claude plugin validate .                        # marketplace manifest
claude plugin validate plugins/git              # plugin manifest
claude plugin validate plugins/git/skills       # the skill files
```

Plugin manifests here intentionally omit `version`, so `validate` reports one warning per plugin.
That is expected.

Those validators also run automatically via pre-commit:

```bash
pre-commit install
pre-commit run --all-files
```

### Loading them without installing at all

Because the plugin directories are already in the right shape, a symlink into your skills directory makes them load automatically as `<name>@skills-dir`, with no marketplace, install, or cache involved:

```bash
ln -s ~/Projects/AgenticSkills/plugins/git ~/.claude/skills/git
```

Handy if you keep more than one Claude Code config directory and want them to share a single checkout.

---

## Contributing

See [`CLAUDE.md`](./CLAUDE.md) for the authoring conventions — plugin membership, frontmatter rules, semantic line breaks, and the prohibitions-table requirement for anything that touches Git, the filesystem, or remote services.
