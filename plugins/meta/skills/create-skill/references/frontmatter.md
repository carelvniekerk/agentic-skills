# Frontmatter reference

What every `SKILL.md` frontmatter field does in Claude Code, which fields survive outside it, and how invocation and names resolve.

## Contents

- Parsing rules
- Field table
- The portability rule
- Invocation control
- String substitutions
- Names and reserved names

## Parsing rules

Frontmatter sits between `---` markers, and Claude Code reads it only when the opening `---` is the first line of the file.
Every field is optional, though `description` is the one that matters.
Without `name`, the command name is the directory name.
Without `description`, Claude Code uses the first non-empty line of the body.

Field names must match the table exactly, hyphens included.
Claude Code ignores an unknown or misspelt key without reporting it, so `disable-model-invocaton: true` leaves the skill auto-invocable and says nothing.
Malformed YAML also fails quietly: the skill loads with no fields set, `/name` still works, and Claude cannot match its description.
`claude --debug` shows the parse error, and `claude plugin validate <dir>/skills` reports unparsable frontmatter.

Booleans accept `true`/`false`, `yes`/`no`, `on`/`off` and `1`/`0` in any case on recent versions.
Write `true` and `false`, which every version accepts.

## Field table

| Field | What it does | Spec field |
| --- | --- | --- |
| `name` | Command name. Lowercase letters, digits and hyphens, at most 64 characters. In a plugin it sets the part after `<plugin>:` | Yes, required, must match the directory |
| `description` | What the skill does and when to use it. The triggering signal | Yes, required, 1-1,024 characters |
| `when_to_use` | Extra trigger phrases appended to `description`. The two share the 1,536-character listing cap | No |
| `argument-hint` | Autocomplete hint such as `[issue-number]` | No |
| `arguments` | Named positional arguments for `$name` substitution, as a space-separated string or YAML list | No |
| `disable-model-invocation` | `true` lets only the user invoke the skill and removes its description from Claude's context. Also blocks preloading into subagents | No |
| `user-invocable` | `false` hides the skill from the `/` menu, but Claude can still invoke it | No |
| `allowed-tools` | Tools Claude may use without asking during the turn that invokes the skill. The grant clears on the next message. It does not restrict which tools are available | Yes, space-separated, experimental |
| `disallowed-tools` | Tools removed from Claude's pool while the skill is active, cleared on the next message. Cannot remove `EndConversation` while other tools remain | No |
| `model` | Model for the rest of the current turn (`/model` values or `inherit`). With `context: fork`, the subagent's model. It changes behaviour, so never use it to record an intended model | No |
| `effort` | Effort override: `low`, `medium`, `high`, `xhigh` or `max`, depending on the model | No |
| `context` | `fork` runs the skill in a forked subagent | No |
| `agent` | Subagent type for `context: fork`, such as `Explore`, `Plan` or a custom agent. Default `general-purpose` | No |
| `background` | With `context: fork`, `false` waits for the subagent's result in the invoking turn. Default `true` | No |
| `hooks` | Hooks registered when the skill is invoked, kept for the rest of the session | No |
| `paths` | Globs limiting when Claude loads the skill automatically | No |
| `shell` | `bash` (default) or `powershell` for injected commands | No |
| `license` | Accepted, not acted on | Yes |
| `compatibility` | Environment requirements, up to 500 characters. Accepted, not acted on | Yes |
| `metadata` | Free-form map for your own tooling. Claude Code ignores it. A note on the intended model or a version belongs here | Yes, string keys to string values |

A top-level `version` field does not exist for skills.
Put a version under `metadata`, or in `plugin.json` for a plugin.

## The portability rule

Claude Code accepts every field above.
claude.ai uploads, the Skills API and `package_skill.py` accept only the six spec fields: `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools`.
Any other key fails with a hard error such as `Unexpected key(s) in SKILL.md frontmatter: argument-hint`.
Enabling a personal skill on a claude.ai account for Cowork, cloud sessions or routines counts as an upload.
Dynamic context injection also works only in Claude Code.

A skill meant for claude.ai or the API keeps to the six fields and moves Claude Code behaviour into settings or a plugin.

## Invocation control

| Frontmatter | User invokes | Claude invokes | Context |
| --- | --- | --- | --- |
| Default | Yes | Yes | Description always listed, body loads on invocation |
| `disable-model-invocation: true` | Yes | No | Description not listed, body loads when the user invokes it |
| `user-invocable: false` | No | Yes | Description always listed, body loads on invocation |

Use `disable-model-invocation: true` for workflows with side effects or timing the user controls, such as commit, deploy or sending a message.
If Claude tries such a skill anyway, Claude Code blocks the call.
Use `user-invocable: false` for background knowledge that is not a meaningful command.
It does not stop Claude using the skill.

Two controls work without editing the file.
`skillOverrides` in `.claude/settings.json` or `.claude/settings.local.json` sets a skill to `"on"`, `"name-only"`, `"user-invocable-only"` or `"off"`, and does not apply to plugin skills:

```json
{
  "skillOverrides": {
    "legacy-context": "name-only",
    "deploy": "off"
  }
}
```

Permission rules `Skill(name)` and `Skill(name *)` allow or deny invocation, and denying `Skill` disables all skills.

## String substitutions

| Variable | Expands to |
| --- | --- |
| `$ARGUMENTS` | The full argument string. If no placeholder receives the arguments, Claude Code appends `ARGUMENTS: <value>` |
| `$ARGUMENTS[N]`, `$N` | The zero-based N-th argument. An index with no matching argument stays as literal text |
| `$name` | A named argument from `arguments`. A missing one expands to an empty string |
| `${CLAUDE_SKILL_DIR}` | The directory holding this `SKILL.md`. In a plugin, the skill's own subdirectory, not the plugin root |
| `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` | The plugin root and its data directory, in plugin skills only |
| `${CLAUDE_PROJECT_DIR}` | The project root |
| `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}` | The session ID and current effort level |

A backslash gives a literal dollar sign (`\$1.00`), but it does not escape the `${CLAUDE_*}` variables.

## Names and reserved names

- A skill folder must not be called `synced` in any capitalisation, because Claude Code keeps downloaded claude.ai skills in `~/.claude/skills/synced/`.
- Outside a plugin, a skill named `anthropic-skills` or starting with `anthropic-skills:` does not load.
- The platform pages forbid "anthropic" and "claude" in a skill `name`, and XML tags.
Claude Code may not enforce this, but claude.ai and the API do, so avoid both words.
- Plugin names have their own reserved list, given in `plugin-packaging.md` in this directory.

When two skills share a name, enterprise beats personal and personal beats project.
A skill beats a `.claude/commands/` file of the same name.
Plugin skills never collide, because they are namespaced `<plugin>:<name>`.
A claude.ai synced skill that loses its short name runs only as `/anthropic-skills:<name>`.
