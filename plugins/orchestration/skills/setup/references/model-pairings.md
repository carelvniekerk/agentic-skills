# Model pairings for the advisor

Checked on 2026-10-13 against the [advisor page](https://code.claude.com/docs/en/advisor).
Re-read that page before relying on this table if Claude Code is newer than v2.1.296, because the pairing rules change with releases.

## Contents

- Accepted pairings
- Aliases and full model IDs
- Version requirements
- Where the advisor does not run

## Accepted pairings

An advisor must rank at or above the main model.
Rows run from the lowest-ranked main model to the highest.

| Main model | Accepted advisors |
| --- | --- |
| Haiku 4.5 | Fable, Opus, Sonnet, Haiku 5.5 |
| Sonnet 4.6 | Fable, Opus, Sonnet, Haiku 5.5 |
| Opus 4.6 | Fable, Opus, Sonnet 5 or later, Haiku 5.5 |
| Sonnet 5 or Haiku 5.5 | Fable, Opus 4.7 or later, Sonnet 5 or later, Haiku 5.5 |
| Opus 4.7 or Opus 4.8 | Fable, Opus 4.7 or later, Sonnet 5.5 |
| Sonnet 5.5 | Fable, Opus 5 or later, Sonnet 5.5 |
| Opus 5 or Opus 5.5 | Fable, Opus 5 or later |
| Fable 5 | Fable 5.1 or Fable 5 |
| Fable 5.1 | Fable 5.1 |

Haiku 4.5 can call the advisor but cannot act as one.
Subagents inherit the advisor and apply the same check against their own model, so Haiku 5.5 subagents with an Opus advisor pass.

## Aliases and full model IDs

The aliases `sonnet`, `opus`, `haiku` and `fable` resolve to Claude Code's current default version of each family, which moves with releases.
Full IDs pin a version.
IDs known on 2026-10-13: `claude-fable-5-1`, `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`.
Confirm them in `/model` before writing them to settings, because an ID Claude Code does not recognise stops the advisor from attaching.

## Version requirements

- Fable 5.1: Claude Code v2.1.257 or later.
- Haiku 5.5 as main model, advisor or subagent model: v2.1.293 or later.
- Sonnet 5.5 as advisor for an Opus 4.7 or 4.8 main model: v2.1.287 or later.
- Fable also needs Fable access, and on some plans a one-time consent to bill usage credits (`/model fable`).

## Where the advisor does not run

- Amazon Bedrock, Claude Platform on AWS, Google Cloud's Agent Platform and Microsoft Foundry.
- Any session where a variable that turns feature-flag fetching off is set, such as `DISABLE_TELEMETRY`.
- Through an LLM gateway (`ANTHROPIC_BASE_URL`) unless the gateway forwards the request intact.
- When `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` is set.
