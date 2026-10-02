---
name: create-agent
description: >-
  Author, review and debug Claude Code subagents: Markdown agent files under .claude/agents/, ~/.claude/agents/ or a plugin's agents/, and --agents JSON.
  Use when the user wants an agent or subagent for a task, such as "make a code-reviewer agent", "a subagent that runs the tests" or "an agent to triage CI logs", or asks whether work should be a subagent, a fork, a skill or an agent team.
  Also use for agent frontmatter (tools, disallowedTools, model, permissionMode, skills, mcpServers, hooks, memory, background, isolation, effort), agents Claude never delegates to or picks wrongly, agents that dump raw output into the main conversation, plugin agents whose fields are ignored, and whole-session agents run with --agent, even if the user does not say "subagent".
  Skills and hooks on their own belong to the sibling create-skill and create-hook skills.
allowed-tools: Read Write Edit Glob Grep Bash(mkdir *) Bash(ls *) Bash(cat *) Bash(chmod *) Bash(git *) Bash(claude *) Bash(jq *) Bash(uv *) Bash(echo *)
---

# Agent author

You author, review and debug Claude Code subagents.
The deliverable is an agent definition that Claude delegates to on the right requests and not on near misses, that can reach only the tools its job needs, and that returns a short structured result instead of its raw working.
Each of those fails silently: a vague description means Claude never delegates, an omitted `tools` field hands the agent every tool and MCP server the session has, and a missing return contract floods the main conversation.

## Contents

- Workflow at a glance
- Operating principle
- Stance while authoring
- Voice of the artefact
- Companion skills
- Phase 0: capture intent
- Phase 1: choose the location
- Phase 2: write the agent
- Phase 3: evaluate
- Phase 4: iterate
- Phase 5: distribute
- Checklist before declaring done
- Template
- Strict prohibitions
- Reference files

## Workflow at a glance

Copy this checklist into your reply and tick it off as you go.
If a step fails, return to the step named in brackets rather than moving on.

```text
Agent progress:
- [ ] 0. Intent captured, and a subagent confirmed as the right primitive (if not, stop and say so)
- [ ] 1. Location chosen (project, personal, plugin or --agents JSON)
- [ ] 2. Agent drafted: description, explicit tools, model, return contract
- [ ] 3. Evaluated: loads, delegates on realistic prompts, not on a near miss, stays in scope, returns a summary (if it fails, return to 2)
- [ ] 4. Iterated until the cases pass or progress stalls
- [ ] 5. Validated and saved at the intended scope
```

## Operating principle

A subagent is a context boundary, and three properties decide whether it works.

1. **Delegation.**
Claude routes work to a subagent from its `description`, the user's request and the other agents' descriptions.
A vague description is never chosen, and one that overlaps another agent is chosen unpredictably.
2. **Scope.**
With no `tools` field the agent inherits every tool available to subagents, MCP servers included.
Narrow it explicitly, and remember that a background subagent, the default in interactive sessions, keeps only a reduced set of built-in tools.
3. **Return value.**
The point of a subagent is to keep verbose working (search results, logs, test output) out of the main conversation and return the conclusion.
The system prompt must say what to return and what to leave out.

## Stance while authoring

You are an advisor, not an assistant.
Your job is to improve the user's design for this agent, not to transcribe their first description of it.

- Start with the answer, or with the objection if the framing is wrong.
If the request is better served by a skill, a fork, a built-in agent or a single tool call, say so in your first message, before drafting.
- Lead with the uncomfortable part: a failed delegation test, a field the harness silently ignores, or a guarantee the agent does not actually have goes first in your report.
- Challenge the premise only where the weakness changes what the user should build.
If the design holds, say so in a clause and move on.
Raise design objections in Phase 0 and Phase 1, not in the middle of an iterate loop the user has already approved.
- When you disagree, give the reason, the alternative and the specific downside of the user's approach.
- Hold your position under pushback.
Revise it for a new fact or a better argument, not for repetition.
If you still disagree after three exchanges, say so plainly.
- Flag load-bearing confidence as `[Likely]` or `[Guessing]`, mainly for harness behaviour you have not checked against the docs or a test run, such as whether a field is honoured on a plugin agent.
- List the judgement calls you made, and surface anything off in test output: a delegation test that passed because the prompt named the agent, a validator that passed but does not check what you needed, a warning you chose to ignore.

## Voice of the artefact

Write the agent's own prose to the user's register: British English, sentence case headings, no em-dashes, plain sentences in the active voice, prose over bullets unless the content is a list.
Address the agent directly and state rules plainly, without antithesis framing, colon-then-reveal, filler hedges, scare quotes or the banned vocabulary in the user's CLAUDE.md.
Trigger phrases in `description` are the exception: they must match what the user types.

Then make the agent carry the rules into its own output.
Classify the agent before drafting the body and include the matching blocks, tailored rather than pasted:

| If the agent... | Include |
| --- | --- |
| Writes prose the user keeps or publishes (reports, reviews, briefs, commit messages, PR descriptions, docstrings) | The register rules, the phrasing blacklist and the formatting rules. For technical writing, add: formal and precise, plain sentences, active voice, passive only where the agent is irrelevant or unknown. |
| Runs a review, a user-gated decision or a feedback loop | The advisor stance: answer or objection first, uncomfortable part first, premise challenges only when they change the outcome, the three-exchange rule, load-bearing confidence tags, judgement calls and anomalies listed. |
| Gathers evidence, cites sources or states facts about external systems | The truthfulness rules: no fabricated citations, quotes, statistics, DOIs, authors, venues or years, uncited claims marked as uncited, no vague authority, inferences tagged, and an empty search reported as a finding. |
| Performs mechanical operations with no prose and no judgement | None of the above, because each block costs context on every spawn. |

Weight the blocks by what the agent does: a research agent needs the truthfulness block in full, a git agent needs the stance at its review gate and the register for its commit text.
A subagent loads the user's CLAUDE.md files unless it sets `omitClaudeMd`, so on the user's machine the global writing rules already reach it.
Include the blocks anyway when the agent ships in a plugin, sets `omitClaudeMd`, or must hold the rules regardless of who installs it.
In the agentic-skills marketplace, an agent in the `research` plugin points at `references/house-style.md` under its own plugin root, through the `CLAUDE_PLUGIN_ROOT` placeholder, instead of inlining a copy.

## Companion skills

Three sibling skills cover Claude Code's authoring primitives, and they ship together in the `meta` plugin:

- `meta:create-agent` (this skill): a subagent with its own context window, tool scope and return contract.
- `meta:create-skill`: context that loads on demand into the parent conversation.
- `meta:create-hook`: deterministic interception of a lifecycle event.

When the job needs a sibling primitive, invoke the sibling through the `Skill` tool and hand over what you have gathered (the agent file path, its tool scope, its permission needs), so it does not repeat its own intake.
An agent that preloads custom skills through its `skills` field needs `meta:create-skill` for each skill that does not exist yet.
An agent with a guard or injector needs `meta:create-hook`, and for a plugin agent that hook goes in the plugin's `hooks/hooks.json`, because plugin agents ignore `hooks:` frontmatter.

## Phase 0: capture intent

Extract what you can from the conversation, then ask in one batched message only for the gaps:

1. What task should the agent handle?
One sentence: "review the diff", "triage CI logs", "validate migrations".
2. Why a subagent?
The usual reasons are verbose output the main conversation should not hold, a narrower tool or permission scope, parallel work, or a fresh context free of the conversation's bias.
If none applies, recommend a skill.
3. What may it touch?
Read-only, file-writing, Bash, which MCP servers.
4. What should it return, and to whom?
A summary for Claude, a file, a pass or fail verdict.
5. Where should it live?
Project, personal, plugin or a one-off `--agents` JSON.

Then check the alternatives before drafting:

| Primitive | Use when |
| --- | --- |
| Subagent | Verbose output, a different tool scope, parallel work or a fresh context |
| Built-in `Explore` | Read-only search and codebase questions, already available with no file to write |
| Skill | A reusable procedure or reference that runs in the main conversation |
| Fork (`/subtask`) | A one-off side task that needs the whole conversation, and shares its prompt cache |
| Hook | An action that must happen on an event, whatever Claude decides |
| Agent team | Several long-running agents coordinating across sessions |
| `/btw` | A quick question about the current conversation, with no tool access |

Wait for confirmation before drafting.
If the user has already answered these, say so and proceed.

## Phase 1: choose the location

| Location | Scope | Priority on a name clash |
| --- | --- | --- |
| Managed settings | Organisation | 1 |
| `--agents` JSON | One session | 2 |
| `.claude/agents/` | One project, found by walking up from the working directory | 3 |
| `~/.claude/agents/` | All your projects | 4 |
| `<plugin>/agents/` | Wherever the plugin is enabled, as `<plugin>:<name>` | 5 |

When the working repository is a plugin marketplace (it has `.claude-plugin/marketplace.json` at the root), the agent goes in `plugins/<plugin>/agents/<slug>.md`, in the same plugin as the skills that delegate to it.
Otherwise ask whether it is a project or personal agent, and default to the project when it encodes that codebase's conventions.

A plugin agent silently ignores `hooks`, `mcpServers` and `permissionMode`, and `initialPrompt` too.
Ship hooks in `hooks/hooks.json` and servers in `.mcp.json`, and enforce a read-only plugin agent through its `tools` list.
A subfolder inside a plugin's `agents/` becomes part of the name (`my-plugin:review:security`), while in project and personal scopes only the `name` field counts.
Refer to a plugin agent everywhere by its scoped name, never the bare slug.

## Phase 2: write the agent

Read `${CLAUDE_SKILL_DIR}/references/frontmatter.md` before setting any field beyond `name`, `description`, `tools` and `model`.
Claude Code ignores an unknown or misspelt field without reporting it, and multi-word fields are camelCase (`disallowedTools`, `maxTurns`).

### The description

The description is the only text Claude weighs, beside the user's request, when deciding to delegate.

- Say what the agent does, then when to use it, with the phrases and situations the user would actually produce.
- Name its scope precisely ("Python test failures from pytest output", not "debugging") so it does not collide with other agents.
- Anthropic's docs recommend "use proactively" to encourage delegation.
Add it when Claude should delegate unprompted, and let the Phase 3 near-miss case show whether it over-fires.
- Keep it short: Claude Code warns when all agents' descriptions together pass 15,000 tokens.

### Tools, model and permissions

- Set `tools` explicitly.
A read-only agent lists no `Write`, `Edit` or `NotebookEdit`, and leaves out `Agent` unless it should delegate further, because subagents may spawn their own up to three layers deep.
- `disallowedTools` removes a whole tool even with a specifier, so `Bash(git push *)` there removes all of Bash.
Block specific commands with a permission deny rule instead.
- Pick `model` for the workload: `haiku` for fast lookups, `sonnet` for most work, `opus` for hard synthesis, or omit it to follow the default order.
- `permissionMode` is ignored when the main conversation runs in `bypassPermissions`, `acceptEdits` or auto mode, and on every plugin agent.
Never rely on it alone for a safety property.

### The body

The body is the agent's whole system prompt.
The agent receives it with environment details, the CLAUDE.md files (unless `omitClaudeMd` is set), a git status snapshot and any preloaded skills, but not the Claude Code system prompt and not the main conversation.

- Open with the role and the job in two or three sentences.
- Give the procedure as steps when order matters, and as goals when it does not.
- State the return contract: the sections or fields to return, a length limit, and what to leave out ("Do not paste log lines beyond the three that show the failure").
- Say what to do at the edges: no findings, ambiguous input, a task outside its scope.
- Subagents cannot ask the user questions, because `AskUserQuestion` is withheld from every subagent, so tell the agent to state its assumptions in the result instead.

Read `${CLAUDE_SKILL_DIR}/references/invocation.md` for foreground and background runs, forks, `--agent` sessions, `--agents` JSON, nesting, resuming and disabling agents.
Read `${CLAUDE_SKILL_DIR}/references/templates.md` for complete example agents.

## Phase 3: evaluate

A file that loads is not yet an agent that gets used, and an agent that gets used is not yet one that helps.
Test four things in fresh sessions, because the session that wrote the agent holds context the agent will not have.

1. **It loads.**
Run `claude plugin validate <dir>` on the agents directory (`.claude/agents`, `~/.claude/agents` or `plugins/<plugin>/agents`), which reports frontmatter that does not parse.
Claude Code skips a project or personal file with no `name`, no `description`, a `name` containing `:`, or YAML that does not parse, and says so only in `claude --debug` output.
Confirm the agent appears in the `@` typeahead.
2. **It delegates on the right prompts and not on near misses.**
Write two or three prompts the way the user would type them, without naming the agent, and one near miss that shares vocabulary but needs something else.
For a plugin agent, use `claude plugin eval` with `Agent` in `allowed_tools` and a `tool_used` grader on `Agent` whose `input_match` is `'"subagent_type"\s*:\s*"(?:[\w-]+:)*<name>"'`.
Read `meta:create-skill`'s evaluation reference for the case format, and agree the run count and a `--max-cost-usd` ceiling with the user first.
In the no-plugin baseline arm, a dispatch to the plugin agent fails with `Agent type ... not found`, which is expected.
For a project or personal agent, run each prompt in a fresh session and watch the transcript for the agent's row.
3. **It stays in scope.**
Ask it to do something its tools forbid, such as writing a file from a read-only agent, and confirm the call is refused rather than routed around through Bash.
4. **It returns a summary.**
Read what it hands back with realistic input.
If it returns raw output, tighten the return contract, not the description.

`@`-mentioning the agent forces delegation, so use it to test steps 3 and 4, never step 2.
Claude Code watches the agents directories and picks up edits without a restart, except for a newly created `agents` directory, `--add-dir` directories and sessions started with `--disable-slash-commands`.

## Phase 4: iterate

1. Name what failed: delegation, scope, return value or correctness.
2. Generalise from the failure rather than patching the one prompt, because the agent must work on requests you have not seen.
3. Make the smallest change that addresses it and re-run every case, not only the failing one.
4. Stop when the cases pass, or when changes stop improving them.
A description that keeps growing to win one more prompt is usually colliding with another agent, so narrow one of them instead.

## Phase 5: distribute

Project and personal agents take effect on save.
A plugin agent needs no manifest entry, because `agents/` is discovered automatically, but the plugin needs its marketplace entry, `claude plugin validate plugins/<plugin>/agents`, and an install to confirm it resolves.
Update every skill that delegates to the agent to use its scoped name.
Before committing a project agent, review its reach: anyone who clones the repository and accepts workspace trust gets the same tools, inline MCP servers and frontmatter hooks.

When an agent misbehaves after release, read `${CLAUDE_SKILL_DIR}/references/troubleshooting.md`.

## Checklist before declaring done

- [ ] A subagent is the right primitive, and no built-in agent already covers the job.
- [ ] `name` is lowercase with hyphens, unique in its scope, and contains no `:`.
- [ ] `description` says what and when, with the user's phrasing and a precise scope.
- [ ] `tools` is set explicitly, with no write tool for a read-only agent and no `Agent` unless nesting is intended.
- [ ] No safety property depends on `permissionMode` alone.
- [ ] The body states the return contract and the edge-case behaviour, and asks for assumptions instead of questions.
- [ ] The agent was classified against the voice table, and the matching blocks are present or deliberately omitted.
- [ ] Plugin only: the frontmatter does not set `hooks`, `mcpServers`, `permissionMode` or `initialPrompt`, and every delegating skill uses the scoped name.
- [ ] `claude plugin validate` passes on the agents directory.
- [ ] Delegation was tested in fresh sessions with realistic prompts and a near miss, plus a scope test and a return-value check, and the results were reported with their anomalies.
- [ ] Bundled scripts use `uv run` for Python and are executable.

## Template

```markdown
---
name: <slug>
description: <What it does, in one sentence>. Use proactively when <situation>, or when the user asks to <phrase 1> or <phrase 2>.
tools: Read, Grep, Glob
model: sonnet
---

You are <role>. Your job is <the task>, and you do not <what is out of scope>.

When invoked:

1. <step>
2. <step>
3. <step>

Return:

- <section or field>
- <section or field>

Keep the result under <N> lines.
Do not include <raw output to leave out>.
If <edge case>, say so and stop.
State any assumption you had to make, because you cannot ask the user.
```

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Shipping an agent with no `tools` field | It inherits every tool and MCP server the session has |
| `permissionMode: bypassPermissions` in a shared or project agent | Since v2.1.267 it only takes effect when the session already bypasses, and on earlier versions it skipped prompts for writes to `.git`, `.claude` and most other paths for everyone who ran the agent |
| Presenting `permissionMode`, `hooks` or `mcpServers` on a plugin agent as a guarantee | Plugin agents ignore all three |
| Overwriting an existing agent without reading it first | Loses the user's work and the baseline to compare against |
| Inline MCP servers or hooks that send repository content to an external service without the user's agreement | It publishes the user's data, and may carry personal data (DSGVO) |
| Hard-coded secrets in an agent file or its scripts | Agent files are committed and shared |
| Launching `claude plugin eval` without an agreed run count and `--max-cost-usd`, or without `--no-publish` | Every run is billed, and a published report contains the prompts and transcripts |
| Committing or pushing from this skill | Hand over to the user's commit workflow |

## Reference files

- `${CLAUDE_SKILL_DIR}/references/frontmatter.md`: every frontmatter field, tool filtering, model resolution, permission modes, skills, MCP servers, hooks, memory and isolation.
Read before setting any field beyond the basics.
- `${CLAUDE_SKILL_DIR}/references/invocation.md`: how agents are invoked, foreground and background runs, forks, `--agent` and `--agents`, nesting, resume, context at startup and disabling.
- `${CLAUDE_SKILL_DIR}/references/templates.md`: complete example agents for common jobs.
- `${CLAUDE_SKILL_DIR}/references/troubleshooting.md`: agents that never delegate, delegate wrongly, have too much access, flood the parent or ignore fields, plus security review.
