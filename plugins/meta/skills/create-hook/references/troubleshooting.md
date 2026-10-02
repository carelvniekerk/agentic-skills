# Troubleshooting hooks

Symptoms after a hook is in place, their usual causes and the fix for each, followed by the security review to run before committing a hook.

## Contents

- The hook never fires
- The hook fires but the action proceeds
- A hook error appears in the transcript
- JSON output has no effect
- A Stop hook keeps Claude going
- updatedToolOutput is ignored
- A hook cannot allow what a rule denies
- Two hooks rewrite the same input
- Security review

## The hook never fires

- It is missing from `/hooks`: the JSON is malformed (trailing comma, comment) or in the wrong file.
In an interactive session, settings hooks also wait for the workspace trust dialog.
- It is listed but never runs:
  - the matcher is case-sensitive, so `bash` matches nothing;
  - `mcp__server` matches no tool, so write `mcp__server__.*`, and use `mcp__plugin_<plugin>_<server>__.*` for a plugin's server;
  - a plugin agent's scoped type contains a colon, so anchor it as `^plugin:agent$`;
  - `if` is set on a non-tool event, where the handler never runs;
  - the event cannot see the action, for example `PermissionRequest` for a call a rule already allows.
- A frontmatter hook in a plugin agent: plugin agents ignore `hooks:`, so move it to `hooks/hooks.json`.
- A project subagent's frontmatter hook in a folder whose trust dialog was never accepted, or in a `-p` run.
- `mcp_tool` on `SessionStart` at launch or on `Setup`: skipped because MCP servers are not yet available.

## The hook fires but the action proceeds

- The script exits 1 with plain text, which is non-blocking.
Exit 2, or exit 0 with the event's JSON decision.
- The event cannot block: `PostToolUse` runs after the tool.
- The script cannot start (`No such file or directory`, missing `chmod +x`), which shows as `Failed with non-blocking status code` and leaves the guard off.
- The hook timed out, and a timed-out `PreToolUse` hook renders no decision.
Make it faster or move the slow part to an async hook.
- An HTTP hook returned non-2xx, which never blocks.
Return 2xx with a JSON decision.
- `PermissionRequest` with exit 2, which that event ignores.
Return `decision.behavior: "deny"`.
- The command form slipped past the script's string match (a leading `VAR=value`, an absolute path, a refspec such as `HEAD:main`).
Add the form to the test cases, then fix the match.

## A hook error appears in the transcript

Run the handler by hand with a realistic input and read the exit code and stderr:

```bash
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | ./hook.sh
echo "exit: $?"
```

- `command not found` for the script: reference it through `${CLAUDE_PROJECT_DIR}` or `${CLAUDE_PLUGIN_ROOT}`.
- `jq: command not found`: install `jq` with Homebrew, or rewrite the handler in Python under `uv run`.
- A validation message: the JSON parsed but does not match the event's schema, for example a decision field the event does not accept.

## JSON output has no effect

- Shell-profile text is on stdout before the JSON.
Wrap profile output in `if [[ $- == *i* ]]; then ... fi`.
- The output does not start with `{` and end with `}`, so it is read as plain text.
- Several JSON lines where one sets a field is a parse failure.
Print one object.
- `hookEventName` is missing from `hookSpecificOutput`, or the field belongs to a different event.
- The field is one the event ignores, such as top-level `decision` on `PreToolUse` (deprecated) or `suppressOutput` (no effect anywhere).

## A Stop hook keeps Claude going

The script blocks on a condition that does not clear, such as a flaky test.
Read `stop_hook_active` from stdin and exit 0 when it is `true`:

```bash
INPUT=$(cat)
if [ "$(jq -r '.stop_hook_active' <<<"$INPUT")" = "true" ]; then
  exit 0
fi
```

Claude Code overrides the block after eight consecutive continuations, so a loop ends eventually, but only after eight wasted turns.
For a prompt handler, allow `impossible: true` in the response.

## updatedToolOutput is ignored

The replacement must match the tool's output shape, such as `{stdout, stderr, interrupted, isImage}` for Bash, or Claude Code uses the original.
MCP tool output is passed through unvalidated.

## A hook cannot allow what a rule denies

That is by design.
Deny and ask rules are evaluated whatever a hook returns, so hooks can tighten permissions but never loosen them.

## Two hooks rewrite the same input

`updatedInput` replaces the whole input object, and the reference does not say which of two parallel rewrites wins.
Consolidate the rewriting into one hook.

## Security review

Run this before committing a project hook or publishing a plugin hook.

- A command hook runs with the user's full permissions and can read, write or send anything the user can.
- Interactive sessions hold settings hooks back until the workspace trust dialog is accepted, but `-p` and SDK runs treat any folder as trusted, so hooks committed to a repository run on the first scripted invocation.
Review `.claude/` in a repository you did not write before running `claude -p` over it.
- Validate input, quote every variable, reject `..` in paths, and skip `.env`, `.git/` and key files.
- `allowedEnvVars` should list only variables the target URL may see, and the URL should be one the user trusts.
An HTTP hook that sends prompts or tool output to an external service publishes that data, which matters under DSGVO when it contains personal data.
- Plugin hooks fire without a per-call confirmation, and in `claude plugin eval` they run outside the agent's sandbox.
- Managed settings can set `allowManagedHooksOnly`, which blocks user, project, local and plugin hooks except plugins force-enabled in managed `enabledPlugins`.
