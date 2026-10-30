---
name: setup
description: Configure the parts of the orchestration setup that live outside the plugin. Asks which main model and which advisor model to use and writes them to ~/.claude/settings.json, adds Flightdeck as a marketplace and plugin with its options when it is missing, appends the Advisor and Delegation rules to ~/.claude/CLAUDE.md, and offers to remove old manual copies of the router hook and agents. Use after installing orchestration, or when the user says "set up model split", "set the advisor model", "change my main model" or "add flightdeck".
disable-model-invocation: true
allowed-tools: Read AskUserQuestion Bash(claude --version) Bash(ls *) Bash(jq *) Bash(graphicle --version) Bash(brew info *)
---

# Set up the model split

A plugin cannot set `model` or `advisorModel`, and CLAUDE.md is not a plugin component, so this skill makes those edits in the user's own files.
It shows every change as a diff first and writes only after an explicit go.
It merges into existing files with `Edit`, keeps every line it does not own, and never rewrites a whole file.

## Contents

- Workflow
- Phase 0: inspect
- Phase 1: models
- Phase 2: Flightdeck
- Phase 3: CLAUDE.md rules and read access
- Phase 4: old copies
- Phase 5: code graph
- When the chezmoi guard refuses an edit
- Report
- Strict prohibitions

## Workflow

```text
Setup progress:
- [ ] 0. Inspected: version, settings.json, CLAUDE.md, old copies, advisor blockers
- [ ] 1. Models chosen, checked against the pairing table, diff approved, written
- [ ] 2. Flightdeck marketplace, plugin and options checked, diff approved, written
- [ ] 3. Advisor and Delegation rules appended, read rule added, diff approved, written
- [ ] 4. Old manual copies listed, removal approved or skipped
- [ ] 5. Graphicle checked, and installed only if missing and approved
- [ ] 6. Report given
```

Each phase ends with its own approval question.
A skipped phase does not block the later ones.

## Phase 0: inspect

Read-only.
Run `claude --version`, read `~/.claude/settings.json` and `~/.claude/CLAUDE.md`, and run `ls ~/.claude/agents ~/.claude/hooks`.

Report these before asking anything:

- A version below 2.1.293.
Haiku 5.5 subagents need it, so stop and say so.
- Anything in the `env` block of `settings.json` that turns the advisor off or moves it: `DISABLE_TELEMETRY`, `CLAUDE_CODE_DISABLE_ADVISOR_TOOL`, `ANTHROPIC_BASE_URL`, or a Bedrock, Vertex or Foundry switch.
The shell environment is not inspected, so say that the check covers the settings file only.
- Keys that already exist: `model`, `advisorModel`, `statusLine`, `extraKnownMarketplaces`, `enabledPlugins`, `pluginConfigs` and `permissions.allow`.

## Phase 1: models

1. Ask two questions with `AskUserQuestion`: the main model (`sonnet`, `opus`, `haiku` or keep the current value) and the advisor model (`opus`, `fable`, `sonnet` or off).
Mark the current values as such.
2. Ask whether to write aliases or pinned IDs.
Aliases follow Claude Code's current default version, which may be a newer Sonnet or Opus than the one you used last week.
Pinned IDs give reproducibility.
3. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/references/model-pairings.md` and check the pair.
If the advisor ranks below the main model, say so, explain that Claude Code would not attach it, and ask again.
Warn about Fable access and usage credits if Fable was chosen.
4. Show the diff for `model` and `advisorModel`, with "advisor off" meaning the key is removed.
Ask for approval, then apply with `Edit`.

Aliases are written as given.
For pinned IDs, confirm them with the user against `/model` first, because the table in the reference is dated.

## Phase 2: Flightdeck

Flightdeck is a third-party observer plugin (`scasella/claude-flightdeck`).
This skill never modifies its files and never depends on it.

1. If `extraKnownMarketplaces["claude-flightdeck"]` is missing, add it in the same shape as the other entries in the file:
`{"source": {"source": "github", "repo": "scasella/claude-flightdeck"}, "autoUpdate": true}`.
If it exists, leave it unchanged, whatever its `autoUpdate` value.
2. If `enabledPlugins["flightdeck@claude-flightdeck"]` is missing, add it as `true`.
3. Set these under `pluginConfigs["flightdeck@claude-flightdeck"].options`, keyed by the full plugin ID:
   - `"architectLabel": "ADVISOR"`.
   - `"moments": false`, because Flightdeck infers its moment labels from edit and error counts and not from real advisor triggers.
   - `"statusLine": false` only when `settings.json` already defines a `statusLine`.
   - Leave `architectPattern` at its default `advisor|architect`, which already matches the advisor tool.
4. Show the combined diff, ask for approval, then apply.
5. When the marketplace or plugin was newly added, say that declaring them does not install anything.
Offer to run `claude plugin marketplace add scasella/claude-flightdeck` and `claude plugin install flightdeck@claude-flightdeck`, after checking both commands with `--help`, and ask before running either.

## Phase 3: CLAUDE.md rules and read access

Append these two sections to `~/.claude/CLAUDE.md`.
If a section with the same heading exists, show the difference against it and keep the user's other lines in it.
If both are present and identical, report them as already set.

```markdown
## Advisor
- Consult the advisor before committing to a plan that touches more than one module.
- Consult the advisor when the same error or test failure recurs after one fix attempt.
- Consult the advisor before declaring a task done.
- Do not consult the advisor for routine edits, renames or formatting.

## Delegation
- Check every task against the triggers below before your first Grep, Glob, Read or Bash search, and invoke orchestration:delegate first when one applies.
Once you have started searching, the search grows into the whole lookup, so the check cannot wait until you know how wide the task is.
- The triggers: a rename or a signature change, a request for every use of a symbol or for the files a change involves, a change that may span more than one module, and code against an external library API that has not been verified in this session.
- A symbol you can name is still a trigger.
A single Grep returns the first hits, not the complete list of references.
- If you skip delegation for a task that matches a trigger, say so in one line with the reason before you search, for example one known file or documentation already fetched.
- Use orchestration:repo-map for repository mapping, orchestration:call-sites for symbol searches and orchestration:api-docs for library documentation.
- Subagents return paths, line numbers and short findings, never whole files.
```

These are instructions, so they belong in CLAUDE.md and not in hook-injected context.
The order matters, because in the eval suite the model delegated less often when it was free to search first.
Match the file's existing heading level and its British English and punctuation rules.

Then add `"Read(~/.claude/CLAUDE.md)"` to `permissions.allow` in `settings.json`, if no equivalent rule exists.
The Stop check of this plugin reads that file to learn the writing rules.
A headless or background hook agent cannot answer a permission prompt, so without the rule its Read is denied and the style check passes every reply without saying so.
Grant exactly that one file, not `~/.claude/**`.

Also add these six rules to `permissions.allow`, if no equivalent rule exists: `mcp__plugin_orchestration_graphicle__repository_status`, `mcp__plugin_orchestration_graphicle__repository_files`, `mcp__plugin_orchestration_graphicle__query_graph`, `mcp__plugin_orchestration_graphicle__get_node`, `mcp__plugin_orchestration_graphicle__get_neighbors` and `mcp__plugin_orchestration_graphicle__shortest_path`.
The graph agents are subagents, so in a headless or background run their Graphicle calls are denied and they fall back to Grep without the graph.
Grant the tools one by one and never the whole server.
`.mcp.json` starts it with `--tools all`, which publishes 23 tools, and one of them, `graph_link`, persists cross-repository edges for every readable project.
The agents' `tools:` lists and these per-tool rules are what keep a graph agent read-only, not the server profile.

## Phase 4: old copies

An earlier manual install may exist.
List what is present:

- `~/.claude/hooks/sonnet-router.py`.
- `~/.claude/agents/repo-map.md`, `call-sites.md` and `api-docs.md`.
- Hook entries in `settings.json` under `UserPromptSubmit`, `PreToolUse` (matcher `Bash`) or `Stop` that point at `sonnet-router.py` or carry the "Sonnet gate" prompt.

If both the old and the plugin copies exist, the gate and done check run twice and the bare agent names collide with the scoped ones.
Show each removal as a diff or a file list and ask.
Delete files with `trash`, never `rm`.
Keep any hook entry that is not one of these.

## Phase 5: code graph

`orchestration:repo-map` and `orchestration:call-sites` query Graphicle, and the plugin's `.mcp.json` starts it with `graphicle mcp --tools all --project .`.

1. Check first whether it is installed: run `graphicle --version`.
If it prints a version, report it and change nothing.
2. If it is missing, offer to install it with Homebrew, using the formula `graphicle-ai/tap/graphicle`.
Check the command with `brew info` first, and run the install only after a yes.
3. Say that Graphicle is a young tool (0.1.x, release builds not yet signed with a trusted certificate) and that releases land almost daily, so the user may want to pin it.
4. Say how a repository opts in: the first time a graph agent reports that Graphicle is unavailable, the main session runs `graphicle setup --clients none --no-hooks --no-capture --no-instructions` on the repository root, after a permission prompt, and the user reconnects the server in `/mcp`.
Until then the graph agents fall back to Glob and Grep and say so.
Do not run it from this skill.
5. Mention retention: the data folder (`~/Library/Application Support/Graphicle` on macOS) holds the synced source text of every opted-in repository until `graphicle offboard --project <folder>` removes it.
That command prints a plan first, and `--apply <plan hash>` carries it out.
6. If `~/.cache/codebase-memory-mcp/` exists, say that the old indexes of client code are still there, and that `codebase-memory-mcp cli delete_project` or `trash` removes them.
Do not delete anything.

## When the chezmoi guard refuses an edit

`~/.claude/settings.json` and `CLAUDE.md` may be chezmoi destination files.
Attempt the edit on the live file first.
If the chezmoi guard refuses and names a source file, re-read that source file, show the same change as a diff against it, ask again, and edit the source.
Do not route around the guard with Bash, `jq`, `sed`, `cp` or a different path to the same file.
Do not run `chezmoi apply` unless asked.
Say in the report which file was edited and what the guard reported.

## Report

List each change as applied, skipped or already set, and name each file touched.
Add the judgement calls, such as alias versus pinned ID, and anything the checks showed that the user did not ask about, for example an advisor blocker in the `env` block.
Say that new settings take effect in a new session, and that the plugin hooks appear under `/hooks`.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Writing any file before the user approved that diff | The user wants to see each change first |
| Overwriting `settings.json` or `CLAUDE.md` with `Write` | It drops lines the skill does not own |
| Editing managed policy settings | They belong to an administrator |
| Setting `disableAllHooks` in any settings file | It turns off the gates and every other hook |
| Editing, copying or disabling Flightdeck's own files | It is a separate observer plugin |
| Bypassing the chezmoi guard with a shell command | The guard exists to stop edits that `chezmoi apply` would revert |
| Deleting with `rm`, or removing a hook entry that is not one of the old copies | Deletions go through `trash`, and other hooks are the user's |
| Running `claude plugin install`, `brew install` or `chezmoi apply` without asking | Each changes state outside the files shown |
| Granting `Read` on more than `~/.claude/CLAUDE.md` | The rule exists for one file, and a wider grant exposes credentials stored under `~/.claude` |
| Granting an MCP permission for anything but the six Graphicle read tools named in Phase 3, or a whole-server rule for Graphicle | Each grant widens what a background subagent may call without asking, and the server also publishes `graph_link`, which persists edges |
| Running `graphicle sync`, `graphicle setup` or `graphicle connect` | This skill configures models and permissions, and the `delegate` skill sets each repository up on demand because a setup copies the repository's source text into the Graphicle store |
