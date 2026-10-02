# Troubleshooting skills

Symptoms after a skill is in use, their usual causes and the fix for each.

## Contents

- The skill never triggers
- The skill triggers when it should not
- The description is cut off in the listing
- The skill stops being followed
- A frontmatter field has no effect
- A bundled script fails elsewhere

## The skill never triggers

- The description lacks the words the user types.
Add the user's phrasing, including informal versions, and put the key use case first.
- The request is too simple.
Claude consults skills for work it cannot easily do alone, so "read this file" may never trigger a skill.
- A higher-precedence skill with the same name shadows it (enterprise, then personal, then project).
Ask "What skills are available?" to see which one Claude lists.
- `disable-model-invocation: true` is set, which removes the description from Claude's context.
- The frontmatter is malformed, so the skill loaded with no description.
Run `claude --debug` or `claude plugin validate`.
- The description was dropped from an overfull listing.
See "The description is cut off in the listing" below.

Confirm a fix with a trigger evaluation rather than one retried prompt.

## The skill triggers when it should not

- The description is too broad.
Narrow it with specific contexts and remove aggressive wording such as capitals or "MUST", which current models over-follow.
- The skill should be manual only.
Set `disable-model-invocation: true`.
- The skill matters only for some files.
Add `paths:`.

## The description is cut off in the listing

The skill listing has a budget of 1% of the context window, and each entry is capped at 1,536 characters of `description` plus `when_to_use`.
When the listing overflows, Claude Code drops descriptions from the least-invoked skills first, but always lists every name.

- Shorten the description and front-load the key use case.
- Set rarely used skills to `"name-only"` in `skillOverrides`.
- Raise the budget with `skillListingBudgetFraction` (for example `0.02`), or a fixed character count in `SLASH_COMMAND_TOOL_CHAR_BUDGET`, and the per-entry cap with `skillListingMaxDescChars`.
- Run `/doctor` for the listing's cost and largest contributors, `/skill-doctor` for each skill's cost and use, and `/context` for the listing's size after the budget.

## The skill stops being followed

The content is usually still in context, and Claude is choosing other approaches.

- Reword guidance as standing instructions that cover the whole task.
- After auto-compaction only the first 5,000 tokens of each skill return, within a 25,000-token budget filled from the most recent skill, and older skills can be dropped.
Invoke the skill again, and move its most important instructions to the top.
- Move a rule that must hold every time into a hook.

## A frontmatter field has no effect

- The key is misspelt, and Claude Code ignored it silently.
Compare it character by character with `frontmatter.md`.
- `allowed-tools` was expected to restrict tools.
It only pre-approves them for one turn, so use `disallowed-tools`.
- `model` or `allowed-tools` was expected to last all session.
Both apply to the invoking turn only.
- The skill is a plugin skill and `skillOverrides` was used.
Overrides do not apply to plugin skills.

## A bundled script fails elsewhere

- The script relies on packages the author installed long ago.
Use `uv run` with PEP 723 inline metadata.
- The path assumes a working directory.
Refer to the script as `${CLAUDE_SKILL_DIR}/scripts/...`.
- The skill runs through the Claude API, which has no network and cannot install packages.
List requirements in `compatibility` and check that the environment provides them.
