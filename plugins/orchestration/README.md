# orchestration

Splits Claude Code work across models.
The main session runs Sonnet with an Opus advisor, three read-only Haiku subagents handle lookups, and two kinds of Sonnet hook act as second opinions.
Nothing in the plugin sets your main model or advisor. The `setup` skill does that in your own files, after you approve each diff.

## What it contains

| Part | What it does |
| --- | --- |
| `orchestration:repo-map` | Haiku subagent. Maps the files, entry points, imports, calls and inheritance a change touches, from a local code graph that it checks against the source. Tools: Read, Glob, Grep and 12 read-only graph tools. |
| `orchestration:call-sites` | Haiku subagent. Finds every call site, import and override of a symbol from the graph and from Grep, and marks each result as found by both or by one source. Tools: Read, Grep, Glob and 7 read-only graph tools. |
| `orchestration:api-docs` | Haiku subagent. Fetches current library documentation with source URLs. Tools: WebSearch, WebFetch, Read. |
| `/orchestration:delegate` | Skill. Tells the main session when a lookup is worth a subagent and when it is not. |
| `/orchestration:setup` | Skill. Writes the main and advisor models, the Flightdeck marketplace and options, the CLAUDE.md rules and a read rule into your files. |
| `.mcp.json` | Starts `codebase-memory-mcp --tool-profile=analysis`, the 13-tool read-only profile. It has no index, delete or ADR-write tool. |
| `PreToolUse` graph hook | Before `repo-map` or `call-sites` starts, indexes the git repository root without persistence and puts the index counts in the main session's context. |
| `SessionStart` hook | States which subagents and skill exist, as facts. |
| `PreToolUse` gate | Asks Sonnet about Bash commands that start with `rm`, `sudo`, `git push`, `git reset`, `git clean` or `curl`. A denial goes back to Claude as the tool error and the turn continues. |
| `Stop` check | One Sonnet agent hook. It checks that a reply reporting code changes also reports which tests or checks ran, and that the prose follows the writing rules in your global `~/.claude/CLAUDE.md`. A failing reply goes back to Claude once. |

The subagents are read-only because their `tools` lists contain no write tool. A plugin agent ignores `permissionMode`, so the `tools` list is the only enforcement.
Their prompts tell them not to consult the advisor, because subagents inherit it.

## Install and set up

```bash
claude plugin install orchestration@agentic-skills
```

Then run `/orchestration:setup` in a new session.
It asks for your main and advisor models, checks the pair against the documented table, and shows each change as a diff before it writes.
It also adds `Read(~/.claude/CLAUDE.md)` to `permissions.allow`.
Without that rule the Stop check cannot read your writing rules in a headless or background run, and it passes every reply without saying so.

## Code graph

The graph agents use [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp), which indexes a repository with tree-sitter into a local SQLite graph.
Install it once with `uv tool install codebase-memory-mcp`. The package is a wrapper that downloads the native binary on first run and verifies its checksum.
The `setup` skill checks whether it is installed first and installs it only when it is missing and you agree.

- **Local.** The README says it runs fully locally with no telemetry. Indexing and querying worked with all IP traffic blocked by `sandbox-exec`. This is a test of two operations and not an audit.
- **Where the index lives.** Under `~/.cache/codebase-memory-mcp/`. A repository gets a `.codebase-memory/graph.db.zst` snapshot only when someone calls `index_repository` with `persistence: true`, which the read-only profile cannot do. Before the first graph agent in a repository, `orchestration:delegate` asks whether to add `.codebase-memory/` to that repository's `.gitignore`. Remove the line by hand where committing the snapshot is fine.
- **It can be wrong.** The package has missed files and produced wrong edges before, so both agents check it. `repo-map` compares the graph's file count with a Glob count, calls `check_index_coverage` for every path it cites, and confirms at least two edges against the source. `call-sites` compares graph callers with Grep and reads every graph-only result. In a test on this repository the graph held 204 file nodes against 208 tracked files while `index_status` reported no unindexed files, so the count comparison shows a gap that the status does not. I did not identify the four files, and some may be types it does not parse. `query_graph` also returns at most 200 rows per call and ignores a larger `LIMIT`, so the agents read `truncated` and report a truncated result as partial.
- **Retention.** Indexes of client code stay on your machine until `codebase-memory-mcp cli delete_project` removes them.
- **Headless runs.** A subagent cannot answer a permission prompt, so without `mcp__plugin_orchestration_codebase-memory` in `permissions.allow` the graph agents fall back to Grep and say so in their first line. The `setup` skill adds the rule.

## Version and model requirements

- Claude Code v2.1.293 or later, for Haiku 5.5 subagents. `continueOnBlock` on prompt hooks needs v2.1.210 or later.
- The hooks pin `claude-sonnet-5-5`. The alias `sonnet` is rejected in a hook (`unrecognized_model`), and the hook then fails open. Update the ID in `hooks/hooks.json` when you move to a newer Sonnet.
- The agents use the alias `haiku`, which frontmatter accepts.

## Cost profile

Figures come from headless test sessions on 2026-10-13, five sessions per row at most. They are indications, not a benchmark.

| Part | Calls | Observed |
| --- | --- | --- |
| `Stop` check | One agent-hook call per turn, two API requests when it reads `CLAUDE.md`. A rejected reply adds a second turn. | A trivial turn cost about $0.113 without the plugin and $0.124 with it. A rejected reply cost about $0.26 in total. |
| `PreToolUse` gate | One Sonnet call per matching Bash command. A command that matches two rules makes two calls. | A session with one blocked `rm -rf` cost $0.14 to $0.19, including the retry turn. |
| Advisor | The model decides when to consult it. Each consultation is an uncached read of the whole transcript. | Not measured here. |

The hook agent for the Stop check may also have the advisor tool enabled. The debug log showed `[AdvisorTool] Server-side tool enabled` for its request. Whether it consults the advisor is unverified.

## What the hooks do not guarantee

- **The gate and the Stop check are second opinions.** A prompt or agent hook that times out lets the call proceed, and hooks can tighten permission rules but never loosen them. Use `onFailure: "block"` on a command hook or a permission rule where you need a guarantee. `onFailure` does not exist for prompt or agent hooks.
- **The Stop check judges what Claude says, not what is true.** It sees the hook input and the file it reads, and cannot run tests. It overlaps with the advisor's "before done" consultation, and a reply it sends back can trigger another advisor call.
- **The Stop check fails open on its style half** when it cannot read `~/.claude/CLAUDE.md`. `tests/stop-probe.sh` case D shows this.
- **Agent hooks are experimental** in Claude Code, and their behaviour may change.
- **You cannot switch off one hook.** Claude Code has no per-hook toggle, so the choices are to disable the whole plugin or to move a hook into its own plugin. The Stop check is the likely candidate if its cost bothers you.

### Bash commands the gate does not see

The gate matches six command prefixes. Risky commands outside them pass without a check, for example `git checkout -- .`, `find . -delete`, `rsync --delete`, `scp`, `dd`, `mv` over an existing file, `python -c "..."` and a script file that deletes things.
Writes through the Edit and Write tools are not gated either.
Each `if` rule takes one permission rule, so the gate is six handlers with the same prompt.

## Advisor availability

The advisor does not run on Amazon Bedrock, Claude Platform on AWS, Google Cloud's Agent Platform or Microsoft Foundry.
It also stays off when feature-flag fetching is disabled, for example with `DISABLE_TELEMETRY`, and through an LLM gateway that does not forward the request intact.
This matters for client work that requires EU-hosted cloud endpoints or locked-down telemetry.
The subagents, the gate and the Stop check do not depend on the advisor.

## Data handling

The plugin sends no prompts or code to any processor other than Anthropic.
The gate and the Stop check run on Anthropic models inside Claude Code.
The `orchestration:api-docs` agent fetches public documentation pages, so the sites it visits see the library name and version it asks for.
Do not put client data in an `api-docs` brief.

## Alternatives

**A cheaper router.** The first design routed each prompt through a Sonnet call from a `UserPromptSubmit` hook. It cost about $0.11 per call in a test and was replaced by the `delegate` skill.
If you want a hook-based router again, a command hook that matches keywords such as "every call", "all usages", "where is ... used" and "docs for" can print the same facts in milliseconds at no model cost. It is not built.

**Hosted routers such as JEV.** A hosted router makes its operator an additional processor under Art. 28 DSGVO, so it needs an AVV and client sign-off, and it adds a transfer to a third country.

## Tests

```bash
plugins/orchestration/tests/acceptance.sh     # free, deterministic: hooks, agents, scoping, dashes
plugins/orchestration/tests/prompt-probe.sh 3 # billed: gate verdicts on 12 commands, three runs each
plugins/orchestration/tests/stop-probe.sh     # billed: four headless sessions against the Stop check
```

Verdicts from a model are not deterministic.
Run the probes more than once and read the disagreements, not a single pass.
