# Agents built on the API or Agent SDK

How to handle `stop_reason`, loop limits and structured output when the agent runs on the Claude API or the Agent SDK and not as a Claude Code subagent.
Read this when the user's "agent" is code that calls the Messages API in a loop, or an Agent SDK program.
A Claude Code subagent never shows its author a `stop_reason`, so none of this applies to the Markdown agents in the rest of this skill.

The facts come from the API docs (<https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons>, <https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works>, <https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools>, <https://platform.claude.com/docs/en/build-with-claude/structured-outputs>) and from Anthropic's Claude Certified Architect exam guide, read on 2026-10-23.
Quotes reached the research agents through a summarising model, so check the live page before quoting any of this in a document.
The built-in `claude-api` skill covers the API in more depth, and it is the place to look for current model IDs and parameters.

## Contents

- The loop
- Stop reasons
- Limits and budgets
- Structured output
- Where the exam guide and the docs differ
- What the sources leave open

## The loop

The docs describe the canonical shape as a `while` loop keyed on `stop_reason`: send the request, run any tools the response asks for, return the results, and repeat while `stop_reason` is `tool_use`.
The exam guide asks for the same control flow and lists three anti-patterns: parsing natural-language signals to decide the loop is over, treating an iteration cap as the primary stop, and treating the presence of assistant text as completion.
The docs' loop exits on every reason other than `tool_use` and lists `end_turn`, `max_tokens`, `stop_sequence` and `refusal` as exits.
That list leaves out `pause_turn` and `model_context_window_exceeded`, so a loop built that way mishandles `pause_turn`, which needs another request.

## Stop reasons

| Value | What happened | What the loop does |
| --- | --- | --- |
| `end_turn` | Claude finished | Use the response |
| `tool_use` | Claude is calling a tool | Run it and return the result, with the `tool_result` blocks first in the user message |
| `max_tokens` | The response hit `max_tokens` | Raise the limit or continue the response |
| `stop_sequence` | A configured stop sequence fired | Read `stop_sequence` to see which |
| `pause_turn` | A server-tool loop reached its iteration limit (default 10) | Send the assistant content back as it is to continue |
| `refusal` | Safety classifiers declined | Read `stop_details` and retry on a fallback model |
| `model_context_window_exceeded` | The response filled the context window | Treat it as truncated |

A refusal arrives as a normal HTTP 200 and is billed.
`stop_details.category` names the policy area, and `reasoning_extraction` has no recommended fallback, so change the prompt and do not retry.
Server-side fallback is in beta, and Haiku 5.5 has none.
A response can carry `stop_reason: "tool_use"` next to a `server_tool_use` block that has no result yet.
Reply with only the client `tool_result` blocks and keep the same `tools` array.

The docs page on stop reasons was read only up to 100,000 of 120,332 characters, so anything in its last part is unchecked.

## Limits and budgets

The docs give no iteration cap for a client loop.
The exam guide treats a cap as acceptable only as a backstop, with the real stop condition coming from `stop_reason`.
The Agent SDK has `max_turns`, which counts tool-use turns, and `max_budget_usd`.
Both default to no limit, and the docs recommend setting a budget for production.
The budget covers subagent spend, and it can be exceeded by up to one response plus whatever subagents are still running.
The SDK result subtypes include `error_max_turns`, `error_max_budget_usd`, `error_during_execution` and `error_max_structured_output_retries`, and the loop should handle each.

Tool errors go back as a `tool_result` with `is_error: true` and an instructive message that says what went wrong and what to try next.
The docs say Claude retries an invalid call two to three times before it apologises.
The exam guide adds that a subagent should recover from transient errors itself and return only what it cannot resolve, with what it attempted and any partial results.

## Structured output

Two features cover it, and a request can use both.
`output_config.format` with `type: "json_schema"` controls the shape of Claude's reply, and `strict: true` on a tool controls the shape of its inputs, using grammar-constrained sampling.
A strict tool needs no validate-and-retry loop for syntax.
The limits are 20 strict tools per request and 24 optional parameters across all strict and JSON schemas, and an over-complex schema returns a 400.
Unsupported schema features include recursive schemas, numeric and string-length constraints, an `additionalProperties` other than `false`, and a `minItems` above 1.
The model sees a simplified schema, so validate in your code as well.

Two stop reasons bypass the schema.
A `refusal` takes precedence over it, and `max_tokens` can leave the output incomplete, so branch on `stop_reason` before parsing.
Prefill is incompatible with JSON outputs.

Semantic errors survive strict schemas.
The exam guide gives line items that do not sum to the total as the example, and suggests extracting a calculated total beside the stated one.
It also says to make a field optional (nullable) when the source may lack it, so the model does not invent a value, and to add an `unclear` enum value and an `other` value with a detail string.
A retry that appends the specific validation error helps with format and structure errors and does nothing when the information is missing from the source.

## Where the exam guide and the docs differ

The exam guide teaches `tool_choice` `any` and forced selection as the way to guarantee structured output.
The define-tools page says `any` and `tool` return a 400 on Claude Opus 5.5, Sonnet 5.5, Fable 5.1 and Mythos 5.1, and that they are unsupported with manual extended thinking.
The documented replacement is `auto` with `strict: true`, or `output_config.format`.
Forcing a tool also skips thinking on every model that accepts it.
For the models in this repository's sessions, follow the docs.

## What the sources leave open

- Whether prefill is rejected on current models, since only a paraphrase of a migration guide was found.
- What the exam asks about `pause_turn`, `refusal`, `stop_sequence` and `model_context_window_exceeded`, since the guide tests only `tool_use` and `end_turn`.
- The model support list for structured outputs and the first-request compile latency of a grammar.
- Anything in Anthropic Academy lessons, which need a sign-in.
