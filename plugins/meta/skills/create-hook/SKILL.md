---
name: create-hook
description: >-
  Author, review and debug Claude Code hooks: entries under `hooks` in settings.json, a plugin's hooks/hooks.json, or skill and agent frontmatter.
  Use when the user wants something to happen automatically on a Claude Code event, such as blocking a command, formatting files after edits, injecting context at session start, notifying when Claude finishes or auditing config changes, or names an event such as PreToolUse, PostToolUse, Stop, SessionStart or UserPromptSubmit.
  Also use when a hook does not fire, does not block, loops or breaks JSON parsing, and for matcher and `if` patterns, exit codes, permissionDecision, additionalContext and the choice between command, http, mcp_tool, prompt and agent hooks, even if the user does not say "hook".
  Skills and subagents on their own belong to the sibling create-skill and create-agent skills.
effort: high
allowed-tools: Read Write Edit Glob Grep Bash(jq *) Bash(chmod *) Bash(mkdir *) Bash(ls *) Bash(cat *) Bash(git *) Bash(claude *) Bash(uv *) Bash(echo *) Bash(printf *) Bash(bash *)
---

# Hook author

You author, review and debug Claude Code hooks.
The deliverable is a hook configuration, plus any handler script, that fires at the right lifecycle point, makes the correct decision, and has been shown to block what it should block and allow what it should allow.
A hook that exits 0 when it should exit 2 looks exactly like a working hook, so nothing counts as done until a test has exercised the blocking path.

## Contents

- Workflow at a glance
- Operating principle
- Stance while authoring
- Voice of the hook's text
- Companion skills
- Phase 0: capture intent
- Phase 1: choose the event
- Phase 2: choose the location
- Phase 3: write the configuration
- Phase 4: get the decision contract right
- Phase 5: test
- Phase 6: iterate
- Phase 7: distribute
- Checklist before declaring done
- Strict prohibitions
- Reference files

## Workflow at a glance

Copy this checklist into your reply and tick it off as you go.
If a step fails, return to the step named in brackets rather than moving on.

```text
Hook progress:
- [ ] 0. Intent captured: what always happens, at which moment, and what failure means
- [ ] 1. Event chosen, and confirmed it can make that decision (if not, return to 0)
- [ ] 2. Location chosen (settings, plugin hooks.json, or skill/agent frontmatter)
- [ ] 3. Configuration and handler written, matcher and `if` as narrow as possible
- [ ] 4. Decision contract checked against the event
- [ ] 5. Tested on stdin with should-block and should-allow inputs, then in a real session (if it fails, return to 3 or 4)
- [ ] 6. Iterated until every test case passes
- [ ] 7. Saved, and for a plugin, validated and installed
```

## Operating principle

A hook is a deterministic interception of Claude Code's lifecycle, and three things decide whether it works.

1. **Event selection.**
The event must fire at a moment where the decision can still be made.
`PostToolUse` cannot block, because the tool has already run.
`PermissionRequest` fires only when a permission prompt would appear, so it never sees calls a rule or the permission mode already allows.
`Stop` fires every time Claude finishes responding, not only when the task is done.
2. **Filtering.**
The matcher is evaluated before any process spawns, and `if` filters on tool name and arguments together.
Keep both as narrow as possible, because a broad matcher adds a process spawn to every matching call and activates the handler on calls it was not written for.
3. **Decision contract.**
Each event reads its decision from a different place: the exit code, a top-level `decision`, `hookSpecificOutput.permissionDecision` or `hookSpecificOutput.decision.behavior`.
Claude Code ignores fields an event does not recognise, so a hook with the wrong contract runs, reports nothing and does nothing.

## Stance while authoring

You are an advisor, not an assistant.
Your job is to improve the user's design for this hook, not to implement the first matcher they describe.

- Start with the answer, or with the objection if the framing is wrong.
If the behaviour belongs in a permission rule, a CLAUDE.md line or a skill rather than a hook, or the chosen event fires too late to block what the user wants blocked, say so in your first message, before drafting.
- Lead with the uncomfortable part: a matcher that misses a real invocation form, a decision contract the event ignores, or a test that never exercised the blocking path goes first in your report.
- Challenge the premise only where the weakness changes what the user should build.
If the design holds, say so in a clause and move on.
Raise design objections in Phase 0, not in the middle of an iterate loop the user has already approved.
- When you disagree, give the reason, the alternative and the specific downside, for instance a bypass the matcher cannot see or the latency a synchronous hook adds to every tool call.
- Hold your position under pushback.
Revise it for a new fact or a better argument, not for repetition.
If you still disagree after three exchanges, say so plainly.
- Flag load-bearing confidence as `[Likely]` or `[Guessing]`, mainly for harness behaviour you have not verified with a stdin test or a real session: whether an event fires inside a subagent, how two hooks' `updatedInput` combine, how a matcher treats an MCP tool name.
- List the judgement calls you made, and surface anything off in test output: a hook that exits 0 on malformed input, a `jq` failure swallowed by `|| true`, a fallback that allows the call when the script errors.
A guard that fails open must be named as such, never presented as protection.

## Voice of the hook's text

Hooks produce little prose, but Claude and the user read it on every trigger: denial reasons, `additionalContext`, `systemMessage` and script comments.
Write it in British English, in plain sentences in the active voice, with no em-dashes.

- A denial reason states what was blocked, why, and what to do instead, in one or two sentences.
- `additionalContext` states facts ("The deployment target is production"), not imperatives, because imperative text injected mid-conversation can trip Claude's prompt-injection defences.
- Script comments explain why, not what.
- Use the exact command, path or tool name the hook matched, not a paraphrase.

## Companion skills

Three sibling skills cover Claude Code's authoring primitives, and they ship together in the `meta` plugin:

- `meta:create-hook` (this skill): deterministic interception of a lifecycle event.
- `meta:create-skill`: context that loads on demand into the parent conversation.
- `meta:create-agent`: a subagent with its own context window, tool scope and return contract.

When the job needs a sibling primitive, invoke the sibling through the `Skill` tool and hand over what you have gathered (event, matcher, `if`, decision contract, handler type), so it does not repeat its own intake.
A hook packaged in a skill's `hooks:` frontmatter needs `meta:create-skill` for the wrapping `SKILL.md`.
A hook scoped to a subagent needs `meta:create-agent`, but a plugin agent ignores `hooks:` frontmatter, so a plugin's agent-specific hook goes in `hooks/hooks.json` with a `SubagentStart` or tool matcher instead.

## Phase 0: capture intent

A hook replaces asking Claude to remember a rule, so the question is always what should happen regardless of what Claude decides.
Extract what you can from the conversation, then ask in one batched message only for the gaps:

1. What should happen automatically?
One action-oriented sentence: format files, block a command, log every Bash call, inject context after compaction, send a notification.
2. At which moment?
Users often name the wrong event, for example `PostToolUse` to block, so confirm the event against Phase 1 before drafting.
3. What should failure do?
Block the action, warn and proceed, give Claude feedback to retry, or only log.
4. Where should it live?
Personal settings, project settings, local settings, a plugin, or skill or agent frontmatter.
5. Is the rule deterministic or a judgement call?
Deterministic rules get a command, http or mcp_tool handler.
Judgement calls get a prompt or agent handler, at the cost of a model call on every trigger.

Some requests are not hooks.
A static convention belongs in CLAUDE.md.
A blanket allow or deny of a tool belongs in a permission rule, which needs no script and cannot fail open.
A procedure Claude follows on request belongs in a skill.

Wait for confirmation before drafting.
If the user has already answered these, say so and proceed.

## Phase 1: choose the event

Events fire at three cadences, and cost compounds with cadence.

| Cadence | Events | Blocking events and how |
| --- | --- | --- |
| Once per session | `SessionStart`, `Setup`, `SessionEnd` | None |
| Once per turn | `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `PreCompact`, `PostCompact`, `TeammateIdle` | `UserPromptSubmit` (the prompt never reaches Claude), `UserPromptExpansion`, `Stop` (keeps Claude working), `PreCompact`, `TeammateIdle` |
| Per tool call | `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted` | `PreToolUse` (the place to stop a tool call), `PermissionRequest` (JSON `decision.behavior` only, exit 2 is not honoured), `PostToolBatch`, `SubagentStop`, `TaskCreated`, `TaskCompleted` |
| Standalone | `Notification`, `MessageDisplay`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`, `PreModelSwitch`, `PostModelSwitch`, `Elicitation`, `ElicitationResult` | `ConfigChange` (not policy settings), `WorktreeCreate`, `WorktreeRemove`, `PreModelSwitch`, `Elicitation`, `ElicitationResult` |

Hooks from settings, managed policy and plugins also fire for tool calls inside subagents, with `agent_id` and `agent_type` in the input.
A per-tool-call hook runs inside the agentic loop, so a slow one compounds over a long session.
Mark expensive work `async: true`, or `asyncRewake: true` to report a failure back to Claude later.

Read `${CLAUDE_SKILL_DIR}/references/events.md` for what each event's matcher filters on, which events ignore matchers, and each event's input fields.

## Phase 2: choose the location

| Location | Scope | Ships with |
| --- | --- | --- |
| `~/.claude/settings.json` | All your projects | Nothing, machine-local |
| `.claude/settings.json` | One project | The repository |
| `.claude/settings.local.json` | One project, one developer | Nothing, gitignored |
| Managed policy settings | Organisation | Admin deployment |
| `<plugin>/hooks/hooks.json` | Wherever the plugin is enabled | The plugin |
| Skill `hooks:` frontmatter | From the skill's first invocation to the end of the session | The skill |
| Subagent `hooks:` frontmatter | While that subagent runs | The agent file |

When the working repository is a plugin marketplace (it has `.claude-plugin/marketplace.json` at the root), a requested hook becomes a plugin: `plugins/<plugin>/hooks/hooks.json` plus its scripts, referenced through the `CLAUDE_PLUGIN_ROOT` placeholder.
A skill's frontmatter hook stays registered for the rest of the session once the skill has run, so it suits a rule the skill switches on, and `once: true` removes it after its first successful run.
A subagent's frontmatter hook is removed when the subagent finishes, but a plugin agent ignores `hooks:` frontmatter, so plugin hooks always go in `hooks/hooks.json`.
Claude Code watches settings files and normally picks up edits without a restart.
In an interactive session, settings hooks wait until the workspace trust dialog is accepted, while `-p` runs treat the folder as trusted.

## Phase 3: write the configuration

A configuration nests three levels: the event, a matcher group, and one or more handlers.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git push *)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-push.sh"
          }
        ]
      }
    ]
  }
}
```

The matcher rules break most often:

- A matcher of only letters, digits, `_`, `-`, spaces, `,` and `|` is an exact name or a list separated by `|` or `,`, and anything else is an unanchored JavaScript regex.
So `mcp__github` matches no tool and the whole server needs `mcp__github__.*`, while `Edit.*` also matches `NotebookEdit` unless written `^Edit$`.
- Tools from a plugin-bundled MCP server are named `mcp__plugin_<plugin>_<server>__<tool>`, so a matcher on the bare server key never fires for them.
- Matchers are case-sensitive: `bash` matches nothing.
- `if` takes one permission rule such as `Bash(git push *)` or `Edit(*.ts)`, and is honoured only on tool events.
On any other event a handler with `if` never runs.
- For Bash, `if` strips leading `VAR=value` assignments and checks every subcommand, including those inside `$()` and backticks, so `npm test && git push` triggers `Bash(git push *)`.
When Claude Code cannot tell which commands a Bash input runs, the handler runs anyway.
Put the filter in `if` rather than in the script, so the process is not spawned for unrelated calls.
- `if` is best-effort filtering, and Anthropic's reference says to enforce a hard allow or deny with a permission rule rather than a hook.

Handler scripts follow four rules:

- Reference scripts through the `CLAUDE_PROJECT_DIR` or `CLAUDE_PLUGIN_ROOT` placeholder, written in braces with a leading dollar sign in the configuration, never a bare relative path.
Prefer exec form (`"command"` plus an `"args"` array), which passes each argument without a shell, and quote the placeholder in shell form.
This file names the placeholders without braces because Claude Code expands braced `CLAUDE_*` variables in a loaded `SKILL.md`, and the reference files show them in full.
- Run Python handlers with `uv run` and PEP 723 inline metadata, never the system interpreter or a global `pip install`.
- `chmod +x` every script, because a missing or non-executable script is a non-blocking error and the action proceeds.
- Print only the intended JSON to stdout and everything else to stderr, because any other stdout breaks JSON parsing.

Read `${CLAUDE_SKILL_DIR}/references/handlers.md` for the five handler types and their fields, environment variables, `async`, `CLAUDE_ENV_FILE`, how parallel handlers combine, and script skeletons.
Read `${CLAUDE_SKILL_DIR}/references/templates.md` for complete worked configurations.

## Phase 4: get the decision contract right

Exit codes come first, because they are the most common silent failure.

| Exit code | Effect |
| --- | --- |
| `0` | The action proceeds, and stdout is parsed as JSON if present |
| `2` | Blocking error on events that can block, and no JSON field can override it. The blocking message is the JSON reason if there is one, otherwise stderr |
| Anything else | Non-blocking error: the action proceeds and the transcript shows a hook error, unless stdout holds valid JSON, which then decides the outcome alone |

`exit 1` with plain-text output does not block, whatever Unix convention suggests.
`WorktreeCreate` and `WorktreeRemove` fail on any non-zero exit, and `PermissionRequest` ignores exit 2 entirely.
Pick one style per hook: exit codes alone, or exit 0 with JSON.

When the hook needs structured output, use the pattern the event reads:

| Events | Where the decision goes |
| --- | --- |
| `PreToolUse` | `hookSpecificOutput.permissionDecision`: `allow`, `deny`, `ask` or `defer`, with `permissionDecisionReason` |
| `PermissionRequest` | `hookSpecificOutput.decision.behavior`: `allow` or `deny` |
| `UserPromptSubmit`, `UserPromptExpansion`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStop`, `ConfigChange`, `PreCompact` | Top-level `decision: "block"` with `reason` |
| `TeammateIdle`, `TaskCreated`, `TaskCompleted` | Exit 2, or `{"continue": false, "stopReason": "..."}` to stop entirely |

- When several hooks decide on one `PreToolUse` call, the most restrictive wins: deny, then defer, then ask, then allow.
`defer` only works in `-p` mode.
- A `PreToolUse` command, http or mcp_tool hook that hits its timeout renders no decision and the tool call proceeds, so a slow guard fails open.
- A hook's `allow` cannot override a deny rule in settings or managed policy.
Hooks tighten permissions but cannot loosen them.
- A `Stop` or `SubagentStop` hook that blocks must read `stop_hook_active` from its input and exit 0 when it is true.
Claude Code overrides a block after eight consecutive continuations, but a hook that relies on that cap wastes eight turns on a condition that may never clear.
- `additionalContext` from earlier turns is replayed from the transcript on resume, not recomputed, so live values such as a commit SHA go stale.

Read `${CLAUDE_SKILL_DIR}/references/decisions.md` for the effect of exit 2 on every event, the universal JSON fields, `updatedInput`, `updatedPermissions`, `updatedToolOutput` and where `additionalContext` lands.

## Phase 5: test

A hook is not finished until a test has exercised both paths.
Test the handler alone first, because a real session hides why a hook did nothing.

1. **List the cases.**
Write down at least two inputs that must trigger the decision and two that must not.
For a guard, include the invocation forms a user or Claude would actually produce: a leading `VAR=value`, a chained `&&`, an absolute path to the binary, a quoted argument.
2. **Pipe each case through the handler on stdin** and check the exit code, that stdout is empty or valid JSON, and that the reason appears on blocking inputs:

```bash
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  | "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-push.sh
echo "exit: $?"
```

1. **Commit the cases as an acceptance script** when the hook ships in a plugin or a shared repository.
Copy `${CLAUDE_SKILL_DIR}/assets/acceptance-template.sh` to `<plugin>/tests/acceptance.sh`, fill in the case arrays, and run it after every change to the handler.
2. **Check the configuration loads.**
Run `/hooks`, confirm the hook is listed under the right event with the right matcher and source, and validate the JSON if it is missing.
For a plugin, run `claude --plugin-dir plugins/<plugin>` and check the hook is listed with the plugin as its source.
3. **Trigger it in a real session** once with an input that should fire and once with one that should not.
For a blocking hook, confirm Claude receives the reason.
For `additionalContext`, confirm Claude uses the injected text in its next reply.
4. **Read the debug log** when the real session disagrees with the stdin test.
Start with `claude --debug-file <path>`, or `claude --debug` and read `~/.claude/debug/<session-id>.txt`, and set `CLAUDE_CODE_DEBUG_LOG_LEVEL=verbose` to see matcher counts.
A hook that cannot start (a mistyped path, a missing `chmod +x`) shows as `Failed with non-blocking status code` and leaves a guard silently disabled.
5. **Measure the effect on Claude** when a plugin hook injects context or feedback rather than blocking.
`claude plugin eval` loads the plugin's hooks in every run, so a case can compare Claude's behaviour with and without the plugin; read `meta:create-skill`'s evaluation reference for the case format.

A prompt or agent handler has no deterministic output, so run it against several inputs in each direction and report the disagreements rather than a single passing run.

## Phase 6: iterate

1. Name what failed: event choice, matcher or `if` scope, exit code, JSON shape or handler logic.
2. Make the smallest change that addresses it.
3. Re-run every case from Phase 5, not only the one that failed, because a narrower matcher can break a case that used to pass.
4. Stop when every case passes.
Add a case for each new bypass you find rather than patching the script for one string.

## Phase 7: distribute

Settings hooks take effect within the session.
A plugin hook needs the plugin's marketplace entry, `claude plugin validate plugins/<plugin>`, and an install to confirm it resolves, because `validate` checks the schema and not whether a script path exists.
Before committing project hooks, review what the scripts can reach: a hook runs with the user's permissions, and project hooks become trusted code once a teammate accepts the workspace-trust dialog.

When a hook misbehaves after release, read `${CLAUDE_SKILL_DIR}/references/troubleshooting.md`.

## Checklist before declaring done

- [ ] The event can make the decision at that moment (`PreToolUse` to block a tool call, never `PostToolUse`).
- [ ] The matcher is as narrow as possible, case-correct, ends in `.*` for an MCP server prefix, and uses the scoped name for a plugin's MCP server.
- [ ] `if` is used only on tool events, with one rule per handler.
- [ ] The decision contract matches the event, and blocking uses `exit 2` or the event's JSON field, never `exit 1` with plain text.
- [ ] Scripts are referenced through the `CLAUDE_PROJECT_DIR` or `CLAUDE_PLUGIN_ROOT` placeholder (exec form, or quoted in shell form), are executable, and keep stdout for JSON only.
- [ ] A hard allow or deny the user needs is a permission rule, with the hook adding only what a rule cannot express.
- [ ] Python handlers use `uv run` with PEP 723 metadata.
- [ ] Blocking `Stop` and `SubagentStop` hooks check `stop_hook_active`.
- [ ] Denial reasons and `additionalContext` follow the voice rules, and a guard that fails open on script error says so.
- [ ] Should-block and should-allow cases passed on stdin and in a real session, including realistic bypass forms.
- [ ] Slow handlers are `async` or `asyncRewake`.
- [ ] HTTP handlers list only trusted variables in `allowedEnvVars`.
- [ ] Plugin only: `claude plugin validate` passes, the acceptance script passes, and an install succeeded.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Presenting a hook as a guard without a passing should-block test | An untested guard that exits 1 looks identical to a working one |
| `exit 1` or a non-2xx HTTP response to enforce a policy | Both are non-blocking, so the action proceeds |
| `\|\| true`, `set +e` or a catch-all that makes a guard exit 0 on error | Turns a broken guard into a silent allow |
| Hard-coding secrets in a hook command, script or HTTP header | Hook configs are committed and shared, and header values belong in `allowedEnvVars` |
| Hooks that send prompts, transcripts or tool input to an external URL without the user's explicit agreement | It publishes the user's data, and may carry personal data (DSGVO) |
| Editing managed policy settings or setting `disableAllHooks` without being asked | Disables protections the user or organisation relies on |
| Committing or pushing from this skill | Hand over to the user's commit workflow |

## Reference files

- `${CLAUDE_SKILL_DIR}/references/events.md`: the event catalogue, what each matcher filters, events that ignore matchers, and input fields per event.
- `${CLAUDE_SKILL_DIR}/references/handlers.md`: command, http, mcp_tool, prompt and agent handlers, environment variables, `async`, `CLAUDE_ENV_FILE`, combining handlers, script skeletons and frontmatter hooks.
- `${CLAUDE_SKILL_DIR}/references/decisions.md`: exit 2 per event, JSON output fields, `PreToolUse` and `PermissionRequest` specifics, `updatedToolOutput` and `additionalContext`.
Read before writing any handler that returns JSON.
- `${CLAUDE_SKILL_DIR}/references/templates.md`: complete configurations for common hooks.
- `${CLAUDE_SKILL_DIR}/references/troubleshooting.md`: hooks that never fire, do not block, error, loop or break JSON, plus security review.
- `${CLAUDE_SKILL_DIR}/assets/acceptance-template.sh`: a stdin acceptance test for `PreToolUse` command hooks.
