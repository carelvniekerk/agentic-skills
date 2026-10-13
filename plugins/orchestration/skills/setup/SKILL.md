---
name: setup
description: Configure the parts of the orchestration setup that live outside the plugin. Asks which main model and which advisor model to use and writes them to ~/.claude/settings.json, adds Flightdeck as a marketplace and plugin with its options when it is missing, appends the Advisor and Delegation rules to ~/.claude/CLAUDE.md, and offers to remove old manual copies of the router hook and agents. Use after installing orchestration, or when the user says "set up model split", "set the advisor model", "change my main model" or "add flightdeck".
disable-model-invocation: true
allowed-tools: Read AskUserQuestion Bash(claude --version) Bash(ls *) Bash(jq *) Bash(uv tool list) Bash(codebase-memory-mcp --version)
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
- [ ] 5. codebase-memory-mcp checked, and installed only if missing and approved
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
- Invoke orchestration:delegate before a task that touches more than one module, asks which files a change would touch, renames a symbol or changes a signature, or writes code against an external library API that has not been verified in this session.
- Use orchestration:repo-map for repository mapping, orchestration:call-sites for symbol searches and orchestration:api-docs for library documentation.
- Subagents return paths, line numbers and short findings, never whole files.
```

These are instructions, so they belong in CLAUDE.md and not in hook-injected context.
Match the file's existing heading level and its British English and punctuation rules.

Then add `"Read(~/.claude/CLAUDE.md)"` to `permissions.allow` in `settings.json`, if no equivalent rule exists.
The Stop check of this plugin reads that file to learn the writing rules.
A headless or background hook agent cannot answer a permission prompt, so without the rule its Read is denied and the style check passes every reply without saying so.
Grant exactly that one file, not `~/.claude/**`.

Also add `"mcp__plugin_orchestration_codebase-memory"` to `permissions.allow`, if no equivalent rule exists.
The graph agents are subagents, so in a headless or background run their codebase-memory calls are denied and they fall back to Grep without the graph.
The rule is safe to grant because `.mcp.json` starts the server with the read-only `analysis` profile, which has no index, delete or ADR-write tool.
Do not grant it for a server that was started without that profile.

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

`orchestration:repo-map` and `orchestration:call-sites` query codebase-memory-mcp, and the plugin's `.mcp.json` starts it with `--tool-profile=analysis`.

1. Check first whether it is installed: run `uv tool list` and `codebase-memory-mcp --version`.
If either shows it, report the version and change nothing.
2. If it is missing, offer `uv tool install codebase-memory-mcp` and run it only after a yes.
The uv package is a wrapper that downloads the native binary from GitHub on first run and verifies its checksum.
3. Say that the user can add it to their list of uv tools, and do not edit that list.
4. Mention retention: indexes of client code stay under `~/.cache/codebase-memory-mcp/` until `codebase-memory-mcp cli delete_project` removes them.

The question about `.codebase-memory/` in a repository's `.gitignore` belongs to `orchestration:delegate`, which asks per repository.

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
| Running `claude plugin install`, `uv tool install` or `chezmoi apply` without asking | Each changes state outside the files shown |
| Granting `Read` on more than `~/.claude/CLAUDE.md` | The rule exists for one file, and a wider grant exposes credentials stored under `~/.claude` |
| Granting an MCP permission for any server other than `orchestration`'s `codebase-memory` | Each grant widens what a background subagent may call without asking |
