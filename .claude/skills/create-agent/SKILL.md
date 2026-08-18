---
name: create-agent
description: >-
  Author, edit, and debug Claude Code subagents (Markdown files under `.claude/agents/`, `~/.claude/agents/`,
  or `plugins/<plugin>/agents/`, or JSON passed to `--agents`) following the official subagents reference.
  Use this skill aggressively whenever the user mentions creating, writing, editing, configuring, debugging,
  or distributing a subagent — even if they only say "make a code-reviewer agent", "build a research subagent",
  "agent for running tests", "spawn a worker agent", or reference any of the built-in agents
  (`Explore`, `Plan`, `general-purpose`).
  Also use it when reviewing existing agent frontmatter, choosing between subagent / fork / skill / agent-team,
  designing tool restrictions and permission modes, scoping MCP servers, preloading skills, enabling persistent
  memory, configuring worktree isolation, controlling background vs. foreground execution, designing
  automatic-delegation descriptions, or setting up `--agent` for whole-session use.
  The skill enforces a draft → test → review → iterate loop and keeps frontmatter aligned with the current
  subagents reference.
allowed-tools: Read Write Edit Glob Grep Bash(mkdir *) Bash(ls *) Bash(cat *) Bash(chmod *) Bash(git *) Bash(claude *) Bash(jq *) Bash(uv *) Bash(echo *)
---

# Agent Author

A disciplined workflow for authoring Claude Code subagents.
The deliverable is a working agent definition (Markdown + frontmatter, JSON, or both) that delegates reliably, runs with the right tool/permission scope, and returns a useful summary instead of dumping its raw exploration into the parent conversation.

This skill enforces a **draft → test → review → iterate** loop.
Subagents fail silently in different ways from skills and hooks: a misconfigured `description` means Claude never delegates; a missing `tools` list means the agent gets every MCP tool you have connected and starts probing them; a `permissionMode` override is ignored if the parent is in auto mode.
Testing is the only way to catch these.

---

## Operating principle

A subagent is a **context boundary**.
Three things determine whether it succeeds:

1. **Delegation.**
   Claude routes work to a subagent based solely on the `description` field plus the names and descriptions of other available agents.
   If the description is vague or duplicates another agent, Claude either won't delegate or will pick the wrong one.
2. **Scope.**
   A subagent inherits permissions from the parent conversation by default.
   That means any MCP tool, any file in any working directory, any `Bash` capability the parent has.
   Unrestricted subagents are a security and reliability problem — explicitly narrow scope on every agent.
3. **Return value.**
   The whole point of a subagent is to keep verbose intermediate output (search results, log files, test output) out of the parent context and return only the summary.
   An agent that returns "here's the full file I read" defeats its own purpose.
   Write the system prompt to compel a concise, structured summary.

Optimise for these three properties from the first draft.
Everything below operationalises that.

---

## Agents in this repository

Agents here ship inside a plugin: `plugins/<plugin>/agents/<slug>.md`.
Claude Code reads that frontmatter directly and merges nothing, so the file is complete on its own.

### Anatomy

```markdown
---
name: researcher
description: <what it does, when to use it proactively, and its trigger phrases>
tools: WebSearch, WebFetch, Read, Write
model: sonnet
permissionMode: acceptEdits
color: blue
---

<system prompt>
```

`name` and `description` are required.
Everything else is optional: `tools`, `disallowedTools`, `model`, `effort`, `permissionMode`, `color`, `mcpServers`, `hooks`, `memory`, `background`, `isolation`, `maxTurns`, `skills`, `initialPrompt`.

Note the syntax difference from a skill: an agent's `tools` is **comma-separated** (`Read, Write, WebFetch`), while a skill's `allowed-tools` is **space-separated** (`Read Write WebFetch`).

### Authoring flow

1. Pick the plugin the agent belongs to — the same one as the skills that will delegate to it.
2. Write `plugins/<plugin>/agents/<slug>.md` with complete frontmatter plus the system prompt as the body.
3. Validate: `claude plugin validate plugins/<plugin>/agents`.
4. Smoke-test: `claude --plugin-dir plugins/<plugin>`, then confirm `<plugin>:<slug>` appears in `/context` under Custom Agents, or `@`-mention it.

There is no separate manifest entry per agent.
The `agents/` directory is discovered automatically from the plugin root.

> **Do not create a `.harness/` directory, and do not write a `.toml` sibling.**
> Earlier revisions of this repository split agent frontmatter into `.harness/claude.yaml` and shipped a transpiled Codex `.toml` alongside each `.md`.
> Both mechanisms are gone, along with the Codex and Copilot targets they served.
> A `.harness/` file today is simply ignored and its keys are silently lost.

### Plugin-agent restrictions

Three frontmatter fields are **silently ignored** on a plugin agent:

| Field            | Where it must go instead                     |
| ---------------- | -------------------------------------------- |
| `hooks`          | `plugins/<plugin>/hooks/hooks.json`          |
| `mcpServers`     | `plugins/<plugin>/.mcp.json`                 |
| `permissionMode` | Not available — rely on `tools` scoping       |

Nothing warns you about this.
If an agent depends on a hook or an MCP server, move that configuration to the plugin level before you assume the agent is broken.

### Namespacing and precedence

A plugin agent is addressed as `<plugin>:<slug>` — `research:researcher`, `research:verifier`.

A project or user `.claude/agents/` definition **overrides** a same-named plugin agent.
That differs from skills, where the plugin copy is namespaced and both coexist.
If you migrate an agent into a plugin, delete the original from `.claude/agents/` or the plugin version will never load.

---

## Source formatting — one sentence per line

Whenever you write markdown in this workflow — the agent frontmatter `description`, the system-prompt body, reference files the agent points to, or any commit/PR text — put each sentence on its own line in the source.
This convention is sometimes called *semantic line breaks*.

The rendered output is unchanged: a markdown renderer collapses consecutive non-blank lines within a paragraph into one rendered line, so the visual result is identical to a soft-wrapped paragraph.
The benefit is in `git diff`: editing one sentence produces a one-line diff instead of a re-flowed paragraph that touches every wrapped line.

Within a list item, the same rule applies — the bullet marker stays on the first line, and continuation sentences sit on subsequent unindented lines.
A blank line ends the paragraph or list item.

````markdown
- This is one bullet.
The bullet continues here, still in the same item.

- This is the next bullet.
````

Type each sentence on a new line as you author.
Do not rely on a post-processing script to enforce this — the rule is small and unambiguous when you write sentence-by-sentence.

---

## Companion skills — delegating to siblings

This skill is one of three that together cover Claude Code's authoring primitives:

- **`create-agent`** (this skill) — delegated subagent with its own context window, tool scope, and return-value contract.
- **`create-skill`** — reusable prompt/workflow context that loads on demand into the parent conversation.
- **`create-hook`** — deterministic interception of a lifecycle event (format on save, block a command, inject context).

The "Choose the right primitive" table later in this skill helps you decide *whether* an agent is the correct primitive at all.
This section is the complement: once you have committed to authoring an agent, what other primitives might you also need?

If the user's request requires a sibling primitive, invoke the sibling skill via the `Skill` tool rather than re-deriving its workflow inline.
Hand over the context you have already gathered (the wrapping agent file path, the agent's tool scope, the desired permission mode) so the sibling does not re-ask its own Phase 0 questions.

Common compositions when authoring an agent:

- The agent should **preload custom skills** via its `preloaded-skills` frontmatter — delegate the skill authoring to `create-skill` for each skill that does not already exist.
- The agent should have **agent-scoped hooks** in its `hooks:` frontmatter (e.g. a `SubagentStart` injector or a `PreToolUse` guard) — delegate the hook design to `create-hook`.
- The agent is part of an **agent team** or plugin that also ships skills and hooks — delegate those parts to the matching sibling skill.

Note: subagents cannot spawn other subagents.
That constraint is about *runtime* delegation, not *authoring* — at authoring time you are free to invoke any sibling skill from this conversation.

---

## Phase 0 — Capture intent

Before writing any frontmatter, establish what the agent is for.
The most common authoring mistake is reaching for a subagent when a skill or `/btw` would do — see [§ Choose the right primitive](#choose-the-right-primitive) below.

Ask the user — in a single batched message — to confirm:

1. **What task should this agent handle?**
   One sentence.
   "Review code", "explore the codebase", "run tests and report failures", "validate database migrations".
2. **Why a subagent rather than a skill?**
   The honest answer is usually one of: (a) the work produces verbose output the parent shouldn't see, (b) the work needs different tool/permission scope from the parent, (c) the work should run in parallel with other work, (d) the work needs a fresh context to avoid being biased by parent conversation.
   If none of those apply, the user probably wants a skill, not a subagent.
3. **What tool scope?**
   Inherit everything (rare), allowlist (`tools:`), or denylist (`disallowedTools:`).
   Read-only? File-modifying? Bash? MCP servers?
4. **What model and effort?**
   Inherit from parent (default), or pin to `haiku`/`sonnet`/`opus` for cost/speed reasons?
5. **Does it need persistent memory?**
   Will the agent benefit from accumulating learnings across conversations (codebase patterns, recurring issues)?
6. **Should it run in foreground, background, or always background?**
   Background lets the parent keep working but requires pre-approval of all permissions.
7. **Where should it live?**
   Personal `~/.claude/agents/`, project `.claude/agents/`, plugin `agents/`, or one-off via `--agents` JSON?

Wait for confirmation before drafting.

### Choose the right primitive

| Primitive                                                                                 | Use when                                                                                                              |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **Subagent**                                                                              | Verbose output, different tool/permission scope, parallel work, fresh context needed                                  |
| **[Skill](https://code.claude.com/docs/en/skills)**                                       | Reusable prompt/workflow that runs in the _parent_ context window                                                     |
| **[Fork](#phase-14--forked-subagents)**                                                             | One-off side task that needs the _full conversation history_ (no re-explaining), parallel exploration of alternatives |
| **[Hook](https://code.claude.com/docs/en/hooks)**                                         | Deterministic, automatic action at a lifecycle event (not a judgement call)                                           |
| **[Agent team](https://code.claude.com/docs/en/agent-teams)**                             | Multiple long-running agents coordinating across separate sessions                                                    |
| **[`/btw`](https://code.claude.com/docs/en/interactive-mode#side-questions-with-%2Fbtw)** | Quick side question about something already in the parent conversation; no tool access; answer is discarded           |

Subagents cannot spawn other subagents.
If the workflow needs nested delegation, either chain subagents from the parent, use Skills for the inner step, or move to agent teams.

---

## Phase 1 — Built-in subagents (don't reinvent these)

Claude Code ships with subagents that are automatically invoked when appropriate.
Before authoring a custom agent, check whether one of these covers the use case.

| Built-in              | Model                | Tools                     | Purpose                                                                                                                      |
| --------------------- | -------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Explore**           | Haiku (fast)         | Read-only (no Write/Edit) | File discovery, code search, codebase exploration. Claude specifies a thoroughness level: `quick`, `medium`, `very thorough` |
| **Plan**              | Inherits from parent | Read-only (no Write/Edit) | Research during plan mode. Prevents infinite nesting since subagents can't spawn subagents                                   |
| **general-purpose**   | Inherits from parent | All tools                 | Complex multi-step tasks needing both exploration and modification                                                           |
| **statusline-setup**  | Sonnet               | (specialised)             | Configures status line via `/statusline`                                                                                     |
| **claude-code-guide** | Haiku                | (specialised)             | Answers questions about Claude Code features                                                                                 |

If your use case is "search the codebase and tell me about X", the answer is `Explore`, not a custom agent.
Custom agents earn their place when they encode domain-specific instructions, tool restrictions, or workflow constraints that the built-ins lack.

---

## Phase 2 — Subagent scope and precedence

Where you store the agent file determines who can use it and which agent wins on name collisions.

| Location                     | Scope                  | Priority    | How to create                 |
| ---------------------------- | ---------------------- | ----------- | ----------------------------- |
| Managed settings             | Organisation-wide      | 1 (highest) | Deployed via managed settings |
| `--agents` CLI flag (JSON)   | Current session only   | 2           | `claude --agents '{...}'`     |
| `.claude/agents/`            | Current project        | 3           | Markdown file or `/agents`    |
| `~/.claude/agents/`          | All your projects      | 4           | Markdown file or `/agents`    |
| Plugin's `agents/` directory | When plugin is enabled | 5 (lowest)  | Bundled with plugin           |

When two agents share a name, **higher priority wins** — the lower-priority definition is shadowed entirely.
Plugin agents appear in the typeahead as `<plugin-name>:<agent-name>`, which avoids collisions with your own agents.

**Project-level (`.claude/agents/`) is the recommended default** for agents tied to a codebase — check them into version control so the team uses the same definitions.
**User-level (`~/.claude/agents/`)** is for personal agents available everywhere.
**`--agents` JSON** is for ephemeral testing and CI scripts.

### Plugin agents ignore three fields

For security, plugin-distributed agents silently ignore `hooks`, `mcpServers`, and `permissionMode` — see the table in [§ Plugin-agent restrictions](#plugin-agent-restrictions) above for where each one has to go instead.

If an agent genuinely needs all three, copy the file into `.claude/agents/` or `~/.claude/agents/` and distribute it outside the plugin.
Permission rules can also be added to `permissions.allow` in `settings.json` or `settings.local.json`, but those apply session-wide rather than to one agent.

### Loading and live edits

Agents are loaded **at session start**.
If you edit a file directly on disk, **restart the session** to pick up the change.
Agents created or edited through the `/agents` interactive interface take effect immediately.

`--add-dir` directories grant file access only — they are **not** scanned for agents.
To share agents across projects, use `~/.claude/agents/` or a plugin.

### Listing and inspecting agents

- Inside Claude Code: `/agents` opens the tabbed manager (Running tab + Library tab).
- From the command line: `claude agents` lists all agents grouped by source, with overrides indicated.

---

## Phase 3 — Frontmatter reference

Agent files are Markdown with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices. Use proactively after code changes.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are a senior code reviewer. When invoked, run `git diff` first, then ...
```

Only `name` and `description` are required.
Every other field has a default that's almost always wrong for a focused agent — narrow them explicitly.

Most fields below are Claude Code specific.
For which fields a plugin agent silently drops, see [§ Agents in this repository](#agents-in-this-repository) at the top of this skill.

| Field             | Required | Description                                                                                                                                                                               |
| ----------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`            | **Yes**  | Unique identifier. Lowercase letters and hyphens. Used for `@`-mentions, `/agents` listings, and `Agent(name)` permission rules                                                           |
| `description`     | **Yes**  | When Claude should delegate. The _only_ signal for automatic delegation. See [§ Writing the description](#phase-4--writing-the-description-the-hardest-part)                                                        |
| `tools`           | No       | Comma-separated allowlist. **Inherits all tools (including MCP) if omitted** — almost never what you want                                                                                 |
| `disallowedTools` | No       | Denylist. Removes tools from the inherited or allowlisted pool                                                                                                                            |
| `model`           | No       | `sonnet`, `opus`, `haiku`, full ID (`claude-opus-4-7`), or `inherit`. Defaults to `inherit`                                                                                               |
| `permissionMode`  | No       | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`. Ignored for plugin agents                                                                                       |
| `maxTurns`        | No       | Maximum agentic turns before the subagent stops                                                                                                                                           |
| `skills`          | No       | List of skill names to **preload into context at startup** (full body injected, not just description). Subagent can still invoke unlisted skills via the Skill tool                       |
| `mcpServers`      | No       | List of MCP servers — strings reference already-configured servers, objects define inline servers scoped to this agent. Ignored for plugin agents                                         |
| `hooks`           | No       | Lifecycle hooks scoped to this agent. Ignored for plugin agents                                                                                                                           |
| `memory`          | No       | `user`, `project`, or `local`. Enables persistent cross-session memory directory                                                                                                          |
| `background`      | No       | `true` to _always_ run as a background task. Default `false`                                                                                                                              |
| `effort`          | No       | `low`, `medium`, `high`, `xhigh`, `max`. Overrides session effort. Available levels depend on model                                                                                       |
| `isolation`       | No       | `worktree` to run in a temporary git worktree (auto-cleaned if no changes made)                                                                                                           |
| `color`           | No       | Display colour: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`                                                                                                      |
| `initialPrompt`   | No       | Auto-submitted as first user turn when running as the **main session agent** (via `--agent` or `agent` setting). Skills and commands are processed. Prepended to any user-provided prompt |

The body of the file is the **system prompt**.
The agent receives this plus minimal environment details (working directory) — it does **not** see the default Claude Code system prompt.

### Defaults that bite

These defaults are technically reasonable but almost never what you want for a production agent:

- `tools` omitted → inherits **everything**, including any MCP tools the parent session has connected.
  An "innocent" research agent suddenly has access to your GitHub, Slack, and database MCP servers.
  **Always set `tools` explicitly** unless you have a specific reason to inherit.
- `model: inherit` (default) → if the parent is on Opus, your "fast research" agent runs on Opus too.
  Pin to `haiku` for fast read-only work.
- `permissionMode` omitted → inherits parent.
  If the parent is `bypassPermissions`, the subagent runs with bypass too — except for circuit-breaker actions like `rm -rf /`.

---

## Phase 4 — Writing the `description` (the hardest part)

The `description` is the single signal Claude uses to decide whether to delegate.
A bad description means Claude either ignores the agent entirely or invokes it on the wrong tasks.

### Structure

A reliable description has three parts:

1. **What it does** — one sentence, action-oriented.
2. **When to use it** — concrete trigger phrases or scenarios.
3. **Proactivity hint** — phrases like "use proactively", "use immediately after", "use whenever".

```yaml
description: >
    Expert code review specialist. Proactively reviews code for quality, security,
    and maintainability. Use immediately after writing or modifying code.
```

Compare to a weak version:

```yaml
description: Reviews code # Claude has no idea when to delegate
```

### Be specific about scope, not just function

A description that says "Reviews code" competes with every other reviewer agent.
A description that says "Reviews **TypeScript** code for **React component** patterns and **accessibility** compliance" wins delegation when those triggers match.

### Push for delegation

Claude tends to **under-delegate** to subagents — it'll do work in the parent context that should have been farmed out.
To compensate, lean into proactive language:

- "Use proactively after any test failure"
- "Use immediately when the user mentions performance regressions"
- "Use whenever the user asks about authentication, even tangentially"

This is the same pattern as making skill descriptions "pushy" — over-trigger is recoverable (you ignore the result), under-trigger is invisible (you never knew the agent existed).

### Avoid description collisions

If two agents have similar descriptions, Claude picks unpredictably.
Run `/agents` and review the existing list before adding a new one.
If your new agent overlaps with an existing one, either narrow it (different scope) or replace the existing one.

---

## Phase 5 — Tool scope: `tools` and `disallowedTools`

By default, subagents inherit every tool from the parent — including MCP tools.
Restrict explicitly using one of two patterns.

### Allowlist with `tools:`

Lists exactly which tools the agent may use.
Everything else is denied.

```yaml
tools: Read, Glob, Grep, Bash
```

This is the **safest pattern** for focused agents.
Read-only research agents should use:

```yaml
tools: Read, Glob, Grep
```

### Denylist with `disallowedTools:`

Inherits everything _except_ the listed tools.

```yaml
disallowedTools: Write, Edit
```

Useful when you want the agent to keep MCP tools and Bash but not modify files.

### Combining both

If both are set, **`disallowedTools` is applied first**, then `tools` is resolved against the remaining pool.
A tool listed in both is removed.

### `Skill` tool semantics

Listing `Skill` in `tools` lets the agent invoke skills at runtime via the Skill tool.
This is **separate** from the `skills:` field — see [§ Phase 7: Preloading skills](#phase-7--preloading-skills).

To preload skills _into the system prompt_, use `skills:`.
To allow runtime skill invocation, include `Skill` in `tools`.
To block all skill use, omit `Skill` from `tools` or add it to `disallowedTools`.

### `Agent(...)` for main-thread agents

When an agent runs as the **main thread** (via `claude --agent <name>`), it can spawn subagents through the Agent tool (formerly Task — old `Task(...)` references still work as aliases).
To restrict which subagents the main-thread agent can spawn, use `Agent(...)` syntax in `tools`:

```yaml
# Allowlist of subagent types
tools: Agent(worker, researcher), Read, Bash

# Allow any subagent
tools: Agent, Read, Bash

# Block all subagents (omit Agent entirely)
tools: Read, Bash
```

This restriction **only applies to main-thread agents**.
Subagents can't spawn subagents anyway, so `Agent(...)` in a subagent definition has no effect.

### Built-in tool reference

The internal tools you can list in `tools` / `disallowedTools` include:

`Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `Agent`, `WebFetch`, `WebSearch`, `AskUserQuestion`, `ExitPlanMode`, `Skill`.

MCP tools follow the `mcp__<server>__<tool>` naming pattern.

---

## Phase 6 — Permission modes

`permissionMode` controls how the agent handles permission prompts.

| Mode                | Behaviour                                                                                                     |
| ------------------- | ------------------------------------------------------------------------------------------------------------- |
| `default`           | Standard checking with prompts                                                                                |
| `acceptEdits`       | Auto-accept file edits and common filesystem commands within the working directory or `additionalDirectories` |
| `auto`              | A background classifier reviews commands and protected-directory writes                                       |
| `dontAsk`           | Auto-deny prompts (explicitly allowed tools still work)                                                       |
| `bypassPermissions` | Skip prompts entirely. Circuit breakers like `rm -rf /` still prompt                                          |
| `plan`              | Plan mode (read-only exploration)                                                                             |

### Inheritance gotchas (these cause silent surprises)

- **If the parent uses `bypassPermissions` or `acceptEdits`**, that takes precedence and **cannot be overridden** by the subagent's `permissionMode`.
- **If the parent uses `auto` mode**, the subagent inherits `auto` and **its `permissionMode` frontmatter is ignored entirely** — the classifier evaluates its tool calls with the parent's allow/deny rules.
- Plugin agents **silently ignore** `permissionMode` regardless.

So `permissionMode: plan` on your read-only research agent does nothing if the user launched the parent session with `--dangerously-skip-permissions`.

### `bypassPermissions` warning

`bypassPermissions` skips approval for writes to `.git`, `.claude`, `.vscode`, `.idea`, `.husky`, and almost everything else.
Don't use it as a shortcut for fixing permission noise — narrow the agent's `tools` list instead.

---

## Phase 7 — Preloading skills

The `skills:` field injects **the full body** of named skills into the agent's context at startup:

```yaml
---
name: api-developer
description: Implement API endpoints following team conventions
skills:
    - api-conventions
    - error-handling-patterns
---
Implement API endpoints. Follow the conventions and patterns from the preloaded skills.
```

This is the **inverse** of running a skill in a subagent (`context: fork` in the skill).
With `skills:` here, the **subagent** controls the system prompt and pulls in skill content.
With `context: fork` in a skill, the **skill** controls the prompt and runs inside whatever agent type it specifies.

### Important constraints

- **Skills with `disable-model-invocation: true` cannot be preloaded.**
  Preloading draws from the same pool of skills Claude can invoke.
  A user-only skill can't be auto-injected.
  Missing/disabled skills are skipped with a warning to the debug log.
- **`skills:` controls preloading, not access.**
  Without `skills:`, the agent can still discover and invoke project, user, and plugin skills via the Skill tool at runtime — provided `Skill` is in `tools`.
- **Preloaded skill content adds to the startup token cost.**
  For long skills, this is meaningful.
  Preload only what the agent will need on most invocations.

---

## Phase 8 — MCP servers per agent

Use `mcpServers:` to give an agent access to MCP servers that aren't in the parent session, **or** to restrict which servers a parent's pool reaches the agent.

```yaml
---
name: browser-tester
description: Tests features in a real browser using Playwright
mcpServers:
    # Inline definition: scoped to this subagent only
    - playwright:
          type: stdio
          command: npx
          args: ["-y", "@playwright/mcp@latest"]
    # String reference: reuses an already-configured server
    - github
---
Use the Playwright tools to navigate, screenshot, and interact with pages.
```

Inline servers use the same schema as `.mcp.json` entries (`stdio`, `http`, `sse`, `ws`).
They connect when the agent starts and disconnect when it finishes.
String references share the parent session's connection.

### When to define inline vs. global

If you want the MCP server's tool descriptions kept **out of the parent context window** (and only loaded when the subagent runs), define inline.
The parent never sees those tools; the subagent does.

If multiple agents and the parent all use the same server, put it in `.mcp.json` and reference it by name everywhere.

### Main-session use

`mcpServers:` also applies when the agent runs as the **main session** via `--agent` or the `agent` setting.
Inline definitions connect at startup alongside servers from `.mcp.json` and settings.

### Plugin agents — silently ignored

Plugin agents drop `mcpServers:` entirely.

---

## Phase 9 — Hooks scoped to the agent

Frontmatter hooks fire only while this agent is active.
Same configuration format as settings-based hooks (see the `hook-author` skill if installed, or <https://code.claude.com/docs/en/hooks>).

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
    PreToolUse:
        - matcher: "Bash"
          hooks:
              - type: command
                command: "./scripts/validate-readonly-query.sh"
---
```

### Two important rules

1. **`Stop` becomes `SubagentStop` automatically** when the agent runs as a subagent.
   Don't write `SubagentStop` in frontmatter — write `Stop`, and Claude Code converts it.
2. **When the agent runs as the main session** (via `--agent`), frontmatter hooks fire **alongside** the settings-defined hooks.
   They don't replace them.

### Plugin agents — silently ignored

Plugin agents drop `hooks:` entirely.

### Project-level hooks for subagent events

To hook into _any_ subagent's lifecycle from the parent's perspective, use settings-level `SubagentStart` / `SubagentStop` hooks with a matcher on agent type:

```json
{
    "hooks": {
        "SubagentStart": [
            {
                "matcher": "db-agent",
                "hooks": [{ "type": "command", "command": "./scripts/setup-db-connection.sh" }]
            }
        ],
        "SubagentStop": [
            {
                "hooks": [{ "type": "command", "command": "./scripts/cleanup-db-connection.sh" }]
            }
        ]
    }
}
```

---

## Phase 10 — Persistent memory

`memory:` gives the agent a directory that survives across conversations.
The agent uses it to accumulate codebase patterns, debugging insights, recurring issues — anything that should compound over time rather than be re-learned each session.

```yaml
---
name: code-reviewer
description: Reviews code for quality and best practices
memory: project
---
You are a code reviewer. As you review code, update your agent memory with
patterns, conventions, and recurring issues you discover.
```

### Scope choice

| Scope     | Location                             | Use when                                                       |
| --------- | ------------------------------------ | -------------------------------------------------------------- |
| `user`    | `~/.claude/agent-memory/<name>/`     | Knowledge applies across all projects                          |
| `project` | `.claude/agent-memory/<name>/`       | Knowledge is project-specific and should be in version control |
| `local`   | `.claude/agent-memory-local/<name>/` | Project-specific but should _not_ be checked in                |

`project` is the default recommendation — knowledge becomes shareable via VCS.

### What enabling memory does automatically

- Adds memory-management instructions to the agent's system prompt.
- Injects the **first 200 lines or 25KB** of `MEMORY.md` from the directory (whichever comes first), with curation instructions if the file is larger.
- Auto-enables `Read`, `Write`, `Edit` tools so the agent can manage its own memory files.

### Making memory pay off

Memory only helps if the agent actually consults and updates it:

- Write the system prompt to **explicitly tell the agent** to read `MEMORY.md` at the start of work and update it at the end.
- Ask the agent in your prompt: _"Review this PR and check your memory for patterns you've seen before."_
- After completion: _"Save what you learned to your memory."_

A passive memory directory the agent never touches is just an empty folder.

---

## Phase 11 — Foreground, background, and `isolation: worktree`

### Foreground vs. background

| Mode                                                                       | Behaviour                                                                                                                                                    |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Foreground** (default)                                                   | Blocks the parent until done. Permission prompts and `AskUserQuestion` calls pass through to the user                                                        |
| **Background** (`background: true`, or Claude decides, or Ctrl+B mid-task) | Runs concurrently. **All permissions pre-approved before launch**. Anything not pre-approved is auto-denied. `AskUserQuestion` fails but the agent continues |

If a background subagent fails for missing permissions, retry as a foreground subagent to grant interactively.

To disable background tasks entirely: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

### `isolation: worktree`

```yaml
isolation: worktree
```

Runs the subagent in a **temporary git worktree** — an isolated copy of the repository.
File edits land in the worktree, not your checkout.
The worktree is automatically cleaned up if the agent makes no changes.

Use for:

- Experimentation that shouldn't touch your working tree.
- Parallel agents that would step on each other's edits.
- Agents that should be reviewed before their changes are merged in.

`cd` commands inside a subagent **don't persist** between Bash calls and don't affect the parent's working directory.
For an isolated working directory that _does_ persist within the agent, use `isolation: worktree`.

---

## Phase 12 — Model and effort selection

### Model resolution order

Claude Code resolves the agent's model in this order (first match wins):

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var (overrides everything)
2. Per-invocation `model` parameter (when the parent's Agent tool call passes one)
3. The agent definition's `model` field
4. The parent conversation's model (`inherit` default)

### When to override

- **`haiku`** for fast, read-only research and simple classification.
- **`sonnet`** for general-purpose work that needs reasoning but not the heaviest model.
- **`opus`** for complex synthesis, hard debugging, or design decisions.
- **`inherit`** when you genuinely want the agent to use whatever the user picked.

For the built-in `Explore` agent (Haiku, read-only) the framework's choice already encodes "fast, cheap, read-only".
Custom research agents should generally do the same: `model: haiku, tools: Read, Glob, Grep`.

### Effort

`effort:` overrides the session effort level for the agent's lifetime.
Levels: `low`, `medium`, `high`, `xhigh`, `max` (model-dependent).
Use sparingly — most agents don't need this — but it's appropriate for agents whose whole purpose is hard reasoning.

---

## Phase 13 — Modes of invocation

There are five distinct ways an agent can run.
Each has different semantics.

### 1. Automatic delegation

Claude reads the user's request, looks at every agent's `description`, and decides whether to delegate.
This is what the `description` is optimised for.

```
[user]: Review the auth changes I just made.
[Claude]: [delegates to code-reviewer subagent]
```

### 2. Natural-language naming

User mentions the agent by name; Claude usually delegates.

```
Use the test-runner subagent to fix failing tests
Have the code-reviewer subagent look at my recent changes
```

Not guaranteed — Claude can still decide otherwise.

### 3. `@`-mention (guaranteed)

Type `@` and pick the agent from the typeahead, or type manually as `@agent-<name>` (or `@agent-<plugin>:<name>` for plugin agents).
This **forces** delegation to that agent.

```
@"code-reviewer (agent)" look at the auth changes
```

Claude still writes the task prompt for the agent based on what you asked — the `@`-mention controls **which** agent runs, not **what** prompt it receives.

### 4. Whole-session agent (`--agent` / `agent` setting)

Replaces the **default Claude Code system prompt** with the agent's definition for the entire session:

```bash
claude --agent code-reviewer
```

Or persistently in `.claude/settings.json`:

```json
{ "agent": "code-reviewer" }
```

The CLI flag overrides the setting.
The agent name appears as `@<name>` in the startup header.
`CLAUDE.md` and project memory still load through the normal flow.

For plugin agents, use the scoped name: `claude --agent <plugin>:<agent>`.

This mode honours the agent's frontmatter hooks alongside settings-level hooks, so it's the right path for "this whole repo should be operated by the code-reviewer agent" workflows.

### 5. Forks (experimental)

See [§ Forked subagents](#phase-14--forked-subagents) below.
Forks inherit the _full conversation history_, not just the agent definition — useful when re-explaining context to a subagent would be expensive.

---

## Phase 14 — Forked subagents

Forks are **experimental** and require Claude Code v2.1.117+.
Enable with `CLAUDE_CODE_FORK_SUBAGENT=1` (interactive, `-p`, and SDK).

A fork is a subagent that **inherits the entire conversation so far** instead of starting fresh.
The fork sees the same system prompt, tools, model, and message history as the parent.
Its own tool calls stay out of your conversation — only the final result returns.

Use a fork when:

- A named subagent would need too much background to be useful.
- You want to try several approaches in parallel from the same starting point.

### What enabling fork mode changes

1. Claude spawns a fork **whenever it would otherwise use `general-purpose`**.
   Named agents (`Explore`, custom agents) still spawn as before.
2. **Every subagent spawn runs in the background**, fork or not.
   Set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` to keep spawns synchronous.
3. The `/fork` command spawns a fork instead of acting as an alias for `/branch`.

### Manual `/fork`

```
/fork draft unit tests for the parser changes so far
```

The fork name comes from the first words of the directive.
It appears in a panel below the prompt, runs in the background, and posts its result back as a message when done.

### Steering controls (panel below the prompt)

| Key       | Action                                        |
| --------- | --------------------------------------------- |
| `↑` / `↓` | Move between rows (main session + each fork)  |
| `Enter`   | Open transcript and send follow-up messages   |
| `x`       | Dismiss a finished fork or stop a running one |
| `Esc`     | Return to the prompt                          |

### Fork vs. named subagent

|                       | Fork                             | Named subagent                               |
| --------------------- | -------------------------------- | -------------------------------------------- |
| Context               | Full conversation history        | Fresh, with the prompt the parent passes     |
| System prompt + tools | Same as main session             | From definition file                         |
| Model                 | Same as main session             | From `model` field                           |
| Permissions           | Prompts surface in your terminal | Pre-approved before launch, then auto-denied |
| Prompt cache          | **Shared with main session**     | Separate cache                               |

Cache sharing makes forks **cheaper** than named subagents for tasks that need the same context — the first request reuses the parent's prompt cache.

### Constraints

- **Forks can't spawn further forks.**
- Setting `isolation: "worktree"` on the Agent tool's invocation gives the fork's edits a separate worktree.

---

## Phase 15 — `--agents` JSON for ephemeral agents

For testing, scripting, or one-off CI use, define agents inline:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on quality, security, best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  },
  "debugger": {
    "description": "Debugging specialist for errors and test failures.",
    "prompt": "You are an expert debugger. Analyse errors, identify root causes, provide fixes."
  }
}'
```

The JSON keys are agent names; values use the same fields as frontmatter, with `prompt` taking the place of the Markdown body.
All frontmatter fields are accepted: `description`, `prompt`, `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, `skills`, `initialPrompt`, `memory`, `effort`, `background`, `isolation`, `color`.

Multiple agents can be passed in a single call.
They exist only for that session and aren't saved to disk.

For PowerShell, use the `@'...'@` here-string syntax — see the docs for the exact form.

---

## Phase 16 — Disabling agents

To prevent Claude from using a specific agent, add it to `permissions.deny`:

```json
{
    "permissions": {
        "deny": ["Agent(Explore)", "Agent(my-custom-agent)"]
    }
}
```

Format is `Agent(name)` — case-sensitive, matches the `name` field.
Works for built-in and custom agents alike.

CLI flag equivalent:

```bash
claude --disallowedTools "Agent(Explore)"
```

---

## Phase 17 — Resume and context management

### Resume

Each subagent invocation creates a **new instance** with fresh context — unless explicitly resumed.

To continue a previous subagent's work, ask Claude to resume it.
Resumed subagents retain their full conversation history (tool calls, results, reasoning) and pick up exactly where they stopped.

```
Use the code-reviewer subagent to review the authentication module
[agent completes]

Continue that code review and now analyse the authorization logic
[Claude resumes the same subagent]
```

Mechanically: when a subagent completes, Claude receives its agent ID.
To resume, Claude uses `SendMessage` (only available with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) with that ID as the `to` field.
A stopped subagent receiving a `SendMessage` auto-resumes in the background without a new `Agent` invocation.

Agent IDs and transcripts live at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.

### Transcripts persist independently

- **Main conversation compaction does not affect subagent transcripts** — they're separate files.
- Subagent transcripts persist across restarts within their session; resume the session to resume the subagent.
- Auto-cleanup uses `cleanupPeriodDays` (default 30 days).

### Auto-compaction

Subagents auto-compact at ~95% capacity by default.
Override with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` (or any percentage).
Compaction events are logged in the subagent's transcript:

```json
{
    "type": "system",
    "subtype": "compact_boundary",
    "compactMetadata": { "trigger": "auto", "preTokens": 167189 }
}
```

---

## Phase 18 — Common patterns

### Isolate high-volume operations

The flagship use case.
Tests, log processing, large file reads — keep the verbose output in the subagent's context, return only the summary:

```
Use a subagent to run the test suite and report only the failing tests with their error messages
```

### Run parallel research

Independent investigations spawn in parallel:

```
Research the authentication, database, and API modules in parallel using separate subagents
```

Caveat: each subagent's results return to the parent, so spawning many at once consumes parent context.
For sustained parallelism, use [agent teams](https://code.claude.com/docs/en/agent-teams) instead — each teammate has its own independent context.

### Chain subagents

For multi-step workflows where each step's output feeds the next:

```
Use the code-reviewer subagent to find performance issues, then use the optimizer subagent to fix them
```

Claude passes relevant context between agents.
This is also the workaround for "subagents can't spawn subagents" — chain from the parent.

---

## Phase 19 — Test the agent

A subagent that hasn't been tested is not a finished agent.
The failure modes are particularly silent: Claude may simply not delegate, or delegate to the wrong agent, or the agent may run successfully but return an unhelpful summary.

### 19a. Verify the file loads

1. Run `/agents` — confirm the agent appears in the Library tab.
2. If it's missing, validate the YAML frontmatter (no tabs, no trailing commas in lists, `tools:` is comma-separated _or_ a YAML list).
3. If you edited the file directly, **restart the session** — disk-edited agents only load at session start.

### 19b. Verify delegation

1. Phrase a prompt the way a real user would — using the trigger phrases from your `description`.
2. Confirm Claude actually delegates (you'll see the agent name in the activity stream).
3. Phrase a prompt that _shouldn't_ trigger — confirm it doesn't.
4. If under-triggering, the description is too vague or competes with another agent.
5. If over-triggering, narrow the description with specific contexts.

### 19c. Verify tool scope

1. Inside the agent's run, confirm only the expected tools are used.
2. Try to make the agent do something outside scope (e.g. ask a read-only agent to `Write`) — confirm the call is denied.
3. If the agent has MCP scope, verify the inline servers connect when it starts and disconnect when it ends.

### 19d. Verify the return value

1. Trigger the agent with realistic input.
2. Read what it returns to the parent — is it a useful summary, or did it dump verbose intermediate output?
3. If verbose, tighten the system prompt: _"Return only X, Y, Z. Do not include the raw output of any commands you ran."_

### 19e. Use `/agents` Running tab while it works

The Running tab shows live subagents and lets you open or stop them — useful for watching long-running agents without spamming the parent transcript.

### 19f. Read the debug log

For deeper inspection:

```bash
claude --debug-file /tmp/claude.log
tail -f /tmp/claude.log
```

Or `/debug` mid-session.

---

## Phase 20 — Iterate

After each test pass:

1. **Note the failure mode** — delegation, scope, return-value, or correctness?
2. **Make the smallest change** that addresses the failure.
3. **Restart the session** if you edited the file on disk.
4. **Re-run trigger and execution tests.**
5. **Stop when correct, not perfect.**

For agents you'll edit frequently, use the `/agents` interactive interface — it picks up changes immediately without a restart.

---

## Common failure modes and fixes

### Claude never delegates

- The `description` lacks trigger phrases the user actually types.
  Add their phrasing, including informal versions.
- A higher-priority agent with the same name shadowed yours.
  Run `claude agents` from the CLI to see the resolution.
- The user's task is single-step and Claude can handle it directly without a subagent.
  This is expected — subagents are for verbose, scoped, or specialised work.

### Claude delegates to the wrong agent

- Two agents have overlapping descriptions.
  Narrow one or both, or replace.
- The `description` is too generic.
  Add specific scope words (frameworks, languages, file types).

### Subagent has too much access

- `tools:` was omitted, so it inherited all parent tools including MCP.
  **Always set `tools` explicitly.**
- `permissionMode` was set but the parent is in `bypassPermissions`/`acceptEdits`/`auto` — those override the subagent.
  Either narrow `tools` or change parent mode.

### Agent dumps verbose output into the parent

- The system prompt doesn't compel a structured summary.
  Add explicit return-format instructions: _"Return a JSON object with keys X, Y, Z. Do not include raw command output."_
- The task is genuinely too small for a subagent — skill or `/btw` would have been better.

### Edits to the file don't take effect

- Disk-edited agents only load at session start.
  **Restart the session.**
- `/agents`-edited agents take effect immediately.

### Plugin agent's hooks/MCP/permissionMode silently dropped

- Plugin agents can't use these fields for security.
  Copy the file into `.claude/agents/` or `~/.claude/agents/` to enable them.

### `Skill` tool isn't available to the agent

- `Skill` isn't in `tools`.
  Add it explicitly, or use `disallowedTools` instead of `tools` for an inheritance-with-exceptions pattern.
- The skill being preloaded has `disable-model-invocation: true` — these can't be preloaded.

### Background subagent fails on a permission

- All permissions must be pre-approved before background launch.
  Anything not pre-approved is auto-denied.
- Re-run as a foreground subagent to approve interactively, then mark those approvals durable.

### Memory directory is empty after many runs

- Agent never reads or writes to it.
  Add explicit instructions in the system prompt: _"Before starting, read MEMORY.md. After completing the task, append what you learned."_
- The user's prompts don't ask the agent to consult memory.
  Add prompting hints to the description: _"Consults persistent memory before reviewing."_

### Resume doesn't work

- `SendMessage` requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- Subagent transcript may have been cleaned up (default 30-day window).

---

## Quick checklist before declaring done

- [ ] `name` is lowercase + hyphens, unique within scope.
- [ ] `description` includes proactivity hint, action description, and concrete trigger phrases.
- [ ] `tools` is **explicitly set** — not inherited by default.
- [ ] `model` is appropriate for the workload (Haiku for fast read-only, Sonnet for general, Opus for synthesis).
- [ ] `permissionMode` matches the agent's risk profile; aware that parent mode can override.
- [ ] If MCP servers needed: `mcpServers` declared (inline or by reference).
- [ ] If preloading skills: skills don't have `disable-model-invocation: true`.
- [ ] If using memory: scope is correct (`project` default unless reasoning otherwise); system prompt instructs the agent to read/write `MEMORY.md`.
- [ ] If file-modifying: consider `isolation: worktree`.
- [ ] If long-running: consider `background: true`, ensure permissions can be pre-approved.
- [ ] System-prompt body compels a concise structured summary, not raw output.
- [ ] If running as main session: `initialPrompt` set if appropriate.
- [ ] Saved at the right scope: `plugins/<plugin>/agents/<slug>.md` for publishing, or `.claude/agents/` / `~/.claude/agents/` / `--agents` JSON otherwise.
- [ ] All frontmatter is inline — there is no `.harness/` directory and no `.toml` sibling.
- [ ] If it is a plugin agent, its frontmatter does not **set** `hooks`, `mcpServers`, or `permissionMode` — those are silently dropped, so leaving one in place documents a guarantee the agent does not have.
- [ ] A read-only plugin agent enforces that through `tools` (no write tool listed), not through `permissionMode: plan`.
- [ ] Every skill that delegates to this agent names it as `<plugin>:<slug>`, not by the bare slug.
- [ ] `claude plugin validate plugins/<plugin>/agents` passes.
- [ ] Smoke-tested with `claude --plugin-dir plugins/<plugin>` and confirmed as `<plugin>:<slug>` in `/context`.
- [ ] Tested: `/agents` shows it, delegation triggers correctly, tool scope is respected, return value is useful, plus the don't-trigger negative test.
- [ ] If using bundled validation scripts, they use `uv run` (Python) or `chmod +x` (Bash).

---

## Templates

### Read-only research agent

```markdown
---
name: codebase-explorer
description: Read-only codebase exploration specialist. Use proactively when the user asks about architecture, finds, file locations, "where is X", "how does Y work", or any time deep code search would otherwise dump verbose results into the main conversation.
tools: Read, Glob, Grep
model: haiku
permissionMode: plan
color: blue
---

You are a codebase exploration specialist. Your job is to find and understand
code without modifying it.

When invoked:

1. Identify the question being asked.
2. Use Glob and Grep to find relevant files.
3. Read only the files that matter.
4. Return a structured summary with:
    - The specific files and line ranges that answer the question.
    - A 3-5 sentence explanation in your own words.
    - Pointers to related code the caller might want to look at next.

Do NOT dump full file contents into your reply. The point is to keep verbose
output out of the parent conversation. Quote at most 5-10 lines per file, and
only when the exact code is needed.
```

### Code-reviewing agent

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code, or when the user asks for a review, audit, or critique.
tools: Read, Grep, Glob, Bash
model: sonnet
memory: project
color: green
---

You are a senior code reviewer ensuring high standards of code quality and security.

Before starting:

1. Read your MEMORY.md for project-specific patterns and recurring issues.

When invoked:

1. Run `git diff` to see recent changes.
2. Focus on modified files.
3. Begin review immediately.

Review checklist:

- Clarity and readability
- Naming
- Duplication
- Error handling
- Exposed secrets / API keys
- Input validation
- Test coverage
- Performance

Output organised by priority:

- **Critical** (must fix)
- **Warnings** (should fix)
- **Suggestions** (consider)

Include specific examples for fixes.

After completing the review, append any new patterns or recurring issues you
identified to MEMORY.md so future reviews benefit.
```

### Debugger agent

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behaviour. Use proactively when encountering any traceback, exception, crash, NaN, hang, or "doesn't work" report.
tools: Read, Edit, Bash, Grep, Glob
model: sonnet
color: red
---

You are an expert debugger specialising in root-cause analysis.

When invoked:

1. Capture the error message and stack trace.
2. Identify reproduction steps.
3. Isolate the failure location.
4. Implement a minimal fix.
5. Verify the fix works.

For each issue, return:

- **Root cause** explanation
- **Evidence** supporting the diagnosis (file:line, log lines)
- **Specific code fix**
- **Testing approach**
- **Prevention** recommendations

Focus on the underlying issue, not the symptoms.
```

### Database-query agent with PreToolUse hook

```markdown
---
name: db-reader
description: Execute read-only database queries. Use when analysing data or generating reports, especially when the user mentions SQL, queries, or "what's in the database".
tools: Bash
hooks:
    PreToolUse:
        - matcher: "Bash"
          hooks:
              - type: command
                command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-readonly-query.sh"
color: cyan
---

You are a database analyst with read-only access. Execute SELECT queries to
answer questions about the data.

When asked to analyse data:

1. Identify which tables contain the relevant data.
2. Write efficient SELECT queries with appropriate filters.
3. Present results clearly with context.

You cannot modify data. If asked to INSERT, UPDATE, DELETE, or modify schema,
explain that you only have read access.
```

The validation script (`./scripts/validate-readonly-query.sh`):

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|REPLACE|MERGE)\b' > /dev/null; then
  echo "Blocked: only SELECT queries allowed" >&2
  exit 2
fi
exit 0
```

If the validation script is in Python, use `uv run` with PEP 723 metadata:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
import json, re, sys
data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")
if re.search(r"\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|REPLACE|MERGE)\b", cmd, re.I):
    print("Blocked: only SELECT queries allowed", file=sys.stderr)
    sys.exit(2)
```

### Browser-testing agent with inline MCP

```markdown
---
name: browser-tester
description: End-to-end browser testing specialist. Use proactively when verifying UI behaviour, accessibility, or full-stack flows that need a real browser.
tools: Read, Bash
model: sonnet
mcpServers:
    - playwright:
          type: stdio
          command: npx
          args: ["-y", "@playwright/mcp@latest"]
isolation: worktree
color: purple
---

You are a browser testing specialist using Playwright.

When invoked:

1. Identify the user flow to test.
2. Use Playwright tools to navigate and interact.
3. Take screenshots at key states.
4. Report findings as a structured summary with:
    - Pass/fail for each step.
    - Screenshot paths for visual evidence.
    - Specific selectors or actions that broke, with file:line references if relevant code exists.

Do not dump raw Playwright traces. Summarise.
```

### Whole-session agent (`--agent`)

```markdown
---
name: pair-reviewer
description: Pair-programming reviewer agent. Provides feedback on every change in real time.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
initialPrompt: >
    Greet the user and ask what they want to work on. Set expectations: you'll
    pair on the work but pause to review and discuss after every meaningful
    change rather than rushing ahead.
hooks:
    PostToolUse:
        - matcher: "Edit|Write"
          hooks:
              - type: command
                command: "echo 'review: $(jq -r .tool_input.file_path)'"
---

You are a pair-programming reviewer. After every code change, pause to review
what was done, surface concerns, and confirm the next step before proceeding.

Operating principle: small reversible steps over large irreversible ones.
```

Launch with:

```bash
claude --agent pair-reviewer
```

### `--agents` JSON for one-off CI use

```bash
claude --agents '{
  "release-checker": {
    "description": "Verifies release readiness: changelog, version, tag, tests.",
    "prompt": "Verify the repository is ready for release. Check that CHANGELOG.md has an entry for the current version, package.json version matches the latest git tag, and all tests pass. Return PASS or FAIL with specifics.",
    "tools": ["Read", "Bash", "Glob"],
    "model": "haiku",
    "permissionMode": "default"
  }
}' --agent release-checker -p "Run the release readiness check for this repo."
```

---

## Security considerations

Agents inherit shell environment and the parent's permissions by default.
Before checking project agents into a repo, review:

- **Scope**: which tools, which directories, which MCP servers does the agent reach?
  Anyone who clones the repo and accepts workspace trust gets the same scope.
- **`permissionMode: bypassPermissions`**: never ship this in a project-scoped agent.
  It's a footgun — the agent can write to `.git`, `.claude`, and most other places without prompting.
- **Inline `mcpServers` definitions**: the server runs with the agent's permissions and connects on every spawn.
  Audit the command and args.
- **`hooks`**: arbitrary shell commands fire on the agent's lifecycle events.
  Plugin agents drop hooks for this reason; project-scoped agents should be reviewed before commit.
- **Memory directories**: persistent state in `.claude/agent-memory/` is committed to the repo (under `project` scope).
  Make sure the agent isn't writing secrets there.

---

## Related documentation

- **Subagents reference**: <https://code.claude.com/docs/en/sub-agents>
- **Agent teams (multi-session orchestration)**: <https://code.claude.com/docs/en/agent-teams>
- **Permissions and modes**: <https://code.claude.com/docs/en/permissions> · <https://code.claude.com/docs/en/permission-modes>
- **Hooks reference**: <https://code.claude.com/docs/en/hooks>
- **Skills reference**: <https://code.claude.com/docs/en/skills>
- **MCP**: <https://code.claude.com/docs/en/mcp>
- **Plugins reference**: <https://code.claude.com/docs/en/plugins-reference#agents>
- **Worktrees**: <https://code.claude.com/docs/en/worktrees>
- **Headless / SDK**: <https://code.claude.com/docs/en/headless>
- **Context window visualisation**: <https://code.claude.com/docs/en/context-window>

---

Repeating the core loop one last time:

1. Capture intent — task, why-not-a-skill, scope, model, memory, foreground/background, location. (Phase 0)
2. Check whether a built-in (`Explore`, `Plan`, `general-purpose`) already covers it. (Phase 1)
3. Pick the location and scope. (Phase 2)
4. Write frontmatter with explicit `tools`, `model`, `permissionMode`. (Phases 3, 5–6)
5. Write a pushy, specific `description`. (Phase 4)
6. Add `skills`, `mcpServers`, `hooks`, `memory`, `isolation`, `background` as needed. (Phases 7–11)
7. Pick the right invocation mode (auto-delegate, `@`-mention, `--agent`, fork, or `--agents` JSON). (Phases 13–15)
8. Compel a concise structured summary in the system prompt body — don't let the agent dump raw output back. (Phase 0 principle 3)
9. Verify with `/agents`, trigger and don't-trigger tests, scope tests, return-value review. (Phase 19)
10. Iterate one change at a time; restart the session after disk edits. (Phase 20)

Add these as TodoList entries when authoring an agent so no step is silently skipped.
