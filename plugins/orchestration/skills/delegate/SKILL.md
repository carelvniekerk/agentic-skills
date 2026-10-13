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

`orchestration:repo-map` and `orchestration:call-sites` query a local codebase-memory graph.
A hook indexes the repository before either agent starts and adds the index counts to your context.
By default the index lives under `~/.cache/codebase-memory-mcp/`, but codebase-memory can also write a `.codebase-memory/` snapshot into the repository.
So once per repository and session, before the first spawn of either agent:

1. Run `git check-ignore -q .codebase-memory/graph.db.zst` from the repository root.
2. If it exits non-zero, ask the user with `AskUserQuestion` whether to add `.codebase-memory/` to the repository's `.gitignore`.
3. On yes, append the line to `.gitignore` with `Edit` (or create the file with `Write`), and say that the change is unstaged.
On no, do not ask again in this session.

Ask in the main session, because subagents cannot ask the user.
If the repository is not a git repository, skip the question.

## Do the lookup yourself instead

- The answer is one known file or a single Grep for a unique name.
- The code is already in your context.
- The library documentation is already in the repository or was fetched earlier in this session.

A subagent costs a spawn and a round trip, so it pays off only when the search is wider than a few tool calls.

## Rules

- Start independent lookups in the same message so they run in parallel, for example `orchestration:call-sites` and `orchestration:api-docs` for a signature change to a library wrapper.
- Write a complete brief, because a subagent does not see this conversation.
Give the goal, the exact names, the directories to skip and the return format.
- Copy the project name and the index counts from the hook's context into the graph agents' briefs, because that context reaches you and not the subagent.
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
| Editing `.gitignore` without the user's yes | The user decides per repository whether the graph snapshot may be committed |
| Calling `manage_adr`, `delete_project` or `index_repository` with `persistence: true` | They write into the repository or delete an index, and the plugin exposes only read-only graph tools |
