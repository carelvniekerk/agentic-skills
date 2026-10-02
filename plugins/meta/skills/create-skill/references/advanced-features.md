# Advanced features

Features to reach for only when the plain instructions in `SKILL.md` are not enough.

## Contents

- Dynamic context injection
- Forked subagents
- Path-scoped activation
- Granting and restricting tools
- Hooks in frontmatter
- Deeper reasoning

## Dynamic context injection

`` !`<command>` `` runs a shell command before the skill reaches Claude and replaces the placeholder with its output, so Claude sees the data and never the command.
Use it to ground a skill in live state such as the current diff or branch.

```markdown
## Current changes

!`git diff HEAD`

## Instructions

Summarise the diff above, then list risky changes. If the diff is empty, say so.
```

For several commands, open a fenced block with three backticks followed by `!`:

````markdown
```!
git branch --show-current
git status --short
```
````

The marker must start a line or follow whitespace, and substitution runs once.

The failure rules are strict, so design commands that cannot fail by accident:

- A failed command aborts the whole invocation, and Claude never sees the skill.
- Any non-zero exit counts as failure, except exit code 1 from search and comparison commands such as `grep`.
Append `|| true` to a command that may legitimately exit non-zero.
- stderr is merged into the injected text, and each command has a two-minute timeout.
- Every command goes through permission checks first.
A command that a deny rule matches aborts the invocation, and outside auto mode so does one that is not allowed, unless `allowed-tools` pre-approves it.
- `disableSkillShellExecution: true` replaces each command with `[shell command execution disabled by policy]`, and synced claude.ai skills never run injected commands locally.

If a command is slow or has side effects, let Claude run it through `Bash` instead, so the user sees it happen.

## Forked subagents

`context: fork` runs the skill in a subagent of the type named in `agent`, with the skill body as its prompt and no conversation history.

```yaml
---
name: codebase-survey
description: Survey a codebase area with read-only tools and report file:line findings.
context: fork
agent: Explore
---
```

Fork only skills with an actionable task.
A skill that holds only conventions gives the subagent nothing to do.
Forks run in the background by default, and `background: false` makes the skill wait for the result in the invoking turn.
Edits made by a background fork fall outside session checkpoints, so use git to revert them.

The reverse arrangement is a subagent whose `skills` field preloads this skill's full content at startup.

## Path-scoped activation

`paths` limits automatic loading to work on matching files:

```yaml
paths:
    - "src/api/**/*.py"
    - "tests/api/**/*.py"
```

The globs use the same format as path-specific rules in CLAUDE.md.
The user can still invoke the skill by name anywhere.

## Granting and restricting tools

`allowed-tools` pre-approves tools for the turn that invokes the skill and clears on the next message.
It restricts nothing: every other tool stays available under the user's normal permissions.

To keep Claude away from a tool while the skill is active, list it in `disallowed-tools`.
To block a tool everywhere, add a permission deny rule.

Workspace trust does not gate `allowed-tools`, so a project skill's grant applies to everyone who clones the repository.
Review it before committing.
Administrators can make Claude Code ignore it in project and personal skills with `allowManagedPermissionRulesOnly`.

Use Anthropic's syntax, space-separated: `Bash(git *)`, not `Bash(git:*)`.

## Hooks in frontmatter

A hook defined in the skill's `hooks:` field registers when the skill is invoked and stays active for the rest of the session.
Use it for a rule that must hold every time, because a hook runs whether or not Claude is following the skill.
Delegate the hook design to `meta:create-hook`.

## Deeper reasoning

The word `ultrathink` anywhere in the skill content requests deeper reasoning for that run.
Reserve it for skills where a shallow answer causes harm, such as security review or hard debugging.
The `effort` field is the persistent alternative.
