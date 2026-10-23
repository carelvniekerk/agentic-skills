# Loading behaviour of instruction files

What Claude Code loads, when, and for whom.
The facts come from the Claude Code docs pages on memory (<https://code.claude.com/docs/en/memory>) and subagents (<https://code.claude.com/docs/en/sub-agents>), read on 2026-10-23.
Version numbers are the docs' own and were not tested against a local build.
Claims the docs leave open are marked as such, and you repeat the marks when you advise.

## Contents

- Files that load at launch
- Files that load on demand
- The rules directory
- Conflicts and layering
- Subagents and forked skills
- Plugins
- Size limits
- Diagnostics
- What the docs leave open

## Files that load at launch

CLAUDE.md files are discovered from the filesystem root down to the working directory and concatenated, not overridden.
`CLAUDE.local.md` follows `CLAUDE.md` in the same directory.
`~/.claude/CLAUDE.md` loads in every project.
Unscoped files under `.claude/rules/` and `~/.claude/rules/` also load at launch, "with the same priority as `.claude/CLAUDE.md`".
User-level rules load before project rules.

## Files that load on demand

A CLAUDE.md or `CLAUDE.local.md` in a subdirectory below the working directory loads once Claude reads, writes or edits another file in that subdirectory.
A rule with `paths:` loads when Claude uses Read, Write or Edit on a matching file, or reads a single matching file with a Bash command such as `cat` or `head`.
Path-scoped rules load again on demand after `/compact`.
A rule about behaviour with no file involved, such as how to write chat replies, never triggers a `paths:` match, so it has to be unscoped.

## The rules directory

Files are plain Markdown, one topic per file, found recursively, so `frontend/` and `backend/` subdirectories work.
Frontmatter is optional and `paths` is the only field read.
Any other field is ignored without an error, and the frontmatter is removed before the rule loads.
`paths` takes a YAML list or a comma-separated string.
If the YAML does not parse, Claude Code ignores the frontmatter and loads the rule as if it had no `paths`, and `claude --debug` shows the parse error.
Project rule globs are relative to the directory that holds the `.claude` folder.
User-level rule globs are relative to the session's primary working directory.

```markdown
---
paths:
  - "src/api/**/*.ts"
---
Handlers return the error shape defined in `src/api/errors.ts`.
```

A symlink in `.claude/rules/` is supported, and circular links are detected.
A symlink whose target lies outside the working directory is treated like an external import and needs a one-time approval per project.
The docs sentence on what loads before that approval is ambiguous, so do not rely on the unapproved behaviour.
`claudeMdExcludes` can exclude rule files.

## Conflicts and layering

The docs say user and project rules do not override each other: "if a user rule and a project rule conflict, Claude may follow either one, so keep the two consistent".
Nested CLAUDE.md files concatenate in the same way, and nothing in the docs lets a folder file replace a parent rule.
The docs describe the whole mechanism as context and point to a `PreToolUse` hook for a hard block.
A project rule appears later in context than a user rule, and the docs give no guarantee that the later rule wins.

## Subagents and forked skills

By default a subagent loads every level of the CLAUDE.md hierarchy the main conversation loads, including `~/.claude/CLAUDE.md`, project rules, `CLAUDE.local.md` and managed policy files.
It does not load the parent conversation's auto memory.
A subagent's own memory, enabled with the `memory` field, is a separate directory.

| Agent | User, project and local instruction files at start |
| --- | --- |
| Built-in Explore and Plan | Skipped |
| Other built-in agents | Loaded |
| Custom user, project or plugin agent | Loaded, unless it sets `omitClaudeMd: true` (v2.1.271 or later) |
| Forked skill with `agent: Explore` | Skipped |

Explore, Plan and agents with `omitClaudeMd` still load a subdirectory's CLAUDE.md and matching path-scoped rules when they work with files there.
`omitClaudeMd` still loads managed policy files, and it is ignored when the agent runs as the main session agent.
The docs say the main conversation still holds the full CLAUDE.md when it reads a subagent's result, so most rules do not need to reach the subagent.

## Plugins

Claude Code does not load a CLAUDE.md at the plugin root, `claude plugin validate` warns when it finds one, and the docs say to put instructions that load into context in a skill.
The plugin manifest reference (<https://code.claude.com/docs/en/plugins-reference>) lists every manifest field and the full standard layout, and `rules/` is in neither.
An unrecognised top-level manifest key is stripped, so a plugin cannot declare a rules directory.
No sentence says a `rules/` folder is ignored, so treat it as unsupported and not as documented to fail.
Of the plugins installed on this machine, none ships a `rules/` directory.

Four mechanisms inject instructions while a plugin is enabled:

- A skill, which loads on demand and is not always present.
- A `SessionStart` hook that returns `additionalContext`, which is always present for the session and can read its text from a file in the plugin.
The `orchestration` plugin in this repository does this.
- A `PreToolUse` or `PostToolUse` hook that returns `additionalContext` for a matching tool call, which approximates a path-scoped rule [Likely].
- A `settings.json` at the plugin root, where only `agent` and `subagentStatusLine` take effect.
Setting `agent` makes a plugin agent the session's main agent, so its prompt is always present [Likely].

## Size limits

Target under 200 lines per CLAUDE.md file.
Rules have no line target, but unscoped rules cost the same as CLAUDE.md at launch.
A file that loads on demand, meaning a subdirectory CLAUDE.md, a rule in a subdirectory or a path-scoped rule, is cut to its start above 40,000 characters on a 200K context window (v2.1.309 or later).
On a 1M window the cap is 200,000 characters on Opus 4.6 and Sonnet 4.6, and 150,000 on later models.
`@path` imports nest up to four hops and do not reduce the cost, because an imported file loads with the file that imports it.
A startup warning appears when files that are each within their limit add up past a combined limit.
Block-level HTML comments in CLAUDE.md are stripped before injection, and the docs do not say the same for rule files.

## Diagnostics

`/memory` lists the instruction files that loaded, and `/context` shows what they cost.
`claude --debug` shows a frontmatter parse error.
The `InstructionsLoaded` hook fires when a CLAUDE.md or rule file loads, at launch and again on lazy loads.
Its input carries `file_path`, `memory_type`, `load_reason` (`session_start`, `nested_traversal`, `path_glob_match`, `include` or `compact`) and `globs`.
Excluding `project` from `--setting-sources` also skips project rules.

## What the docs leave open

- Whether `@path` imports inside a rule file are expanded.
- Whether a `rules/` folder inside a plugin is silently ignored or loaded, since no page says either and the manifest and layout lists exclude it.
- Whether a plugin `settings.json` `agent` setting behaves as a main-session agent in every host, which the manifest reference states only as "settings Claude Code applies while the plugin is enabled".
- Whether `omitClaudeMd` works on a plugin agent is not documented.
One probe on Claude Code 2.1.309 on 2026-10-23 found it honoured: a plugin agent with the field answered NONE when asked to quote a rule from the user's CLAUDE.md, and a control plugin agent without it quoted the rule.
That is one run per arm.
- Whether `InstructionsLoaded` fires inside a subagent.
- Whether a forked skill whose `agent` is a custom agent with `omitClaudeMd` drops CLAUDE.md.
- Where an unscoped rule sits relative to the root CLAUDE.md within the loaded context.
