---
name: delegate
description: Decide whether to hand a lookup to one of the read-only Haiku subagents (orchestration:repo-map, orchestration:call-sites, orchestration:api-docs) before starting work. Use when a task touches more than one module, asks which files or modules a change would involve, renames a symbol or changes a function signature, asks for every call or usage of something, or writes code against an external library API that has not been verified in this session, even if the user does not mention subagents.
---

# Delegate lookups to the Haiku subagents

This skill chooses between doing a lookup yourself and handing it to a read-only Haiku subagent.
It edits nothing.
The saving comes from the subagent returning paths and line numbers instead of file contents, so the main context stays small.

## Choose the agent

| The task needs | Agent | Put in the brief |
| --- | --- | --- |
| The files, entry points and dependencies a change involves, and you do not yet know the modules | `orchestration:repo-map` | The change in one sentence, and directories to ignore |
| Every reference to a named symbol, before a rename or a signature change | `orchestration:call-sites` | The exact symbol, the file that defines it, and any alternative spellings |
| The current signatures of an external library | `orchestration:api-docs` | The library, its version from the lockfile, and the calls you plan to use |

## Before the first graph agent in a repository

`orchestration:repo-map` and `orchestration:call-sites` query a local Graphicle code graph.
Graphicle serves only a repository that has been set up for it, and the server does not start in any other folder.
The agents then say so in their first line and fall back to Glob and Grep.
The agents have no Bash tool, so when one reports that Graphicle is unavailable you set the repository up yourself:

1. Find the repository root with `git rev-parse --show-toplevel`.
If the folder is not a git repository, skip the rest and carry on with the Grep-based result.
2. Say in one line which repository you are setting up and that the setup copies its source text into the Graphicle data folder, so that the permission prompt for the next command is an informed one.
3. Run `graphicle setup --clients none --no-hooks --no-capture --no-instructions <repository root>`.
The flags keep it to the data folder: no client configuration, no git hooks, no session capture and no edits to `CLAUDE.md` or `AGENTS.md`.
Do not add the command to `permissions.allow`, because each repository should get its own prompt.
4. When it succeeds, tell the user to reconnect the `plugin:orchestration:graphicle` server in `/mcp`, or to start a new session, because the server resolves its project once at start and a running session cannot restart it.
Spawn the graph agent again after that, and carry on with the Grep-based result until then.
5. When it fails, report the error line verbatim and carry on with the Grep-based result.

## Decide before the first search

Choose before your first Grep, Glob or Read on the task.
Once you have started searching, the search tends to grow into the whole lookup and the main context fills with file contents.
A symbol you can name is not a reason to Grep it yourself, because the Grep returns the first hits and not the complete list of references.

Delegate when the task is one of these:

- A rename or a signature change.
- A request for every use of a symbol, or for the files and modules a change involves.
- Code against an external library whose signatures you have not read in this session.

Do the lookup yourself only when the code is already in your context, the answer sits in one file the user named, or the library documentation is in the repository or was fetched earlier in this session.

## Rules

- Start independent lookups in the same message so they run in parallel, for example `orchestration:call-sites` and `orchestration:api-docs` for a signature change to a library wrapper.
- Write a complete brief, because a subagent does not see this conversation.
Give the goal, the exact names, the directories to skip and the return format.
- Treat the result as a lead, and read the coverage line first.
A count mismatch or a failed spot-check means the graph missed something, so fall back to Grep for that area.
Read the files you are about to edit yourself, because a Haiku summary can miss a reference.
After a rename, run one Grep for the old name as the check.
- Ask for paths, line numbers and one-line findings, never whole files.
- Do not ask a subagent to edit anything, since all three are read-only.
The subagents are told not to consult the advisor, so only you do.

## Gotchas

- `orchestration:api-docs` fetches the version you name.
Without a version it returns the latest documentation, which can differ from the lockfile.
- Plugin agents carry the plugin prefix.
Use the `orchestration:` names above, not the bare slugs.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Putting secrets, credentials or client data in an `orchestration:api-docs` brief | Its web searches leave the machine |
| Delegating an edit, a commit or a shell command | All three agents are read-only and have no Bash tool |
| Editing a file from a subagent summary without reading the file | Haiku summaries can miss a reference |
| Running `graphicle setup` without `--clients none --no-hooks --no-capture --no-instructions`, or running `graphicle connect` | Without those flags `setup` writes hook, MCP and instruction entries into the repository and your home folder, and `connect` writes the same kind of entries |
| Running `graphicle setup` on a subfolder of a repository | A subfolder synced alone becomes a project of its own, so use the repository root |
| Calling `graph_link` or any Graphicle tool outside the agents' lists | `graph_link` persists cross-repository edges for every readable project in the workspace |
