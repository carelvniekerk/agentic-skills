# Evaluating a skill

How to measure whether a skill triggers on the right prompts and improves the output, with the commands and file formats for each method.

## Contents

- What to measure
- Choosing a method
- Writing cases
- claude plugin eval
- Graders
- Reading the results
- skill-creator
- Trigger queries and description tuning
- Testing across models
- Cost and data

## What to measure

Seeing a skill fire shows only that Claude found it.
Measure two things separately:

- **Triggering**: Claude invokes the skill on prompts that need it and leaves it alone on near misses.
- **Effect**: with the skill, the output is better than without it.

Both need fresh sessions.
A session that wrote the skill still holds the reasoning behind it, which hides gaps in the written instructions.

## Choosing a method

| Skill | Method |
| --- | --- |
| Plugin skill | `claude plugin eval`, which runs every case with and without the plugin |
| Personal or project skill | Two fresh sessions per prompt, the second with the skill set to `"off"` in `skillOverrides`. For repeatable runs, wrap the skill in a skills-directory plugin and use `claude plugin eval` |
| Description tuning for any skill | The `skill-creator` plugin's optimisation loop |

`skillOverrides` does not apply to plugin skills.
`claude plugin eval` and skill-creator use different case formats, and neither reads the other's files.

## Writing cases

Start with two or three cases that cover the skill's main job, and add one near miss: a prompt that shares the skill's vocabulary but needs something else, such as a sibling skill.
Write prompts the way the user types them, with concrete detail and without naming the skill.
A prompt so simple that Claude can answer it unaided will not trigger any skill, whatever the description says.

Each case pairs one grader on the result with one on the steps that produced it, so a pass shows both that the answer was right and that the skill produced it.

## claude plugin eval

`claude plugin eval init` interviews you and writes a suite.
`claude plugin eval init --bare <case>` writes a blank case instead.
A suite lives in `<plugin>/evals/`, one directory per case:

```text
evals/
├── <case>/
│   ├── prompt.md          # frontmatter: run settings; body: the prompt
│   └── graders/
│       └── <name>.md      # one grader per file
└── results/               # written by each run; add it to .gitignore
```

`prompt.md` frontmatter rejects unknown keys.
The useful fields are `description`, `tags`, `runs` (default 3), `model`, `max_turns` (default 10, set it generously because hitting it lowers the score), `timeout_seconds` (default 300) and `allowed_tools`.
`plugins: ["../.."]` points a case at its plugin when auto-detection fails.

```markdown
---
description: Commit message from a described rename.
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

Write me a commit message for this change: I renamed getUser to fetchUser and updated the three call sites.
```

Each run starts in an empty working directory, so put everything the task needs in the prompt.
Runs never ask for permission.
Read-only tools listed in `allowed_tools` are granted, and `Bash`, `Write`, `Edit`, `WebFetch` and `WebSearch` need `--allow-tools` on the command line.
Granted `Bash` runs in the OS sandbox, which cannot read the home directory.

Run it from the plugin root:

```bash
claude plugin eval . --no-publish --max-cost-usd 10
claude plugin eval . --case 'review-*' --runs 2 --judge-model sonnet --no-publish
```

## Graders

Each file under `graders/` has a `type`, an optional `weight` and an optional `arm`.

| Type | Passes when |
| --- | --- |
| `regex` | `pattern` is found in the `target` (`last_message` by default, or `trace`, `files`, or `{ source: file, path: <path> }`). `match: not_contains` requires absence |
| `tool_used` | Calls to `tool` whose input matches `input_match` number between `min` (default 1) and `max` |
| `tool_order` | The first `before` call precedes the first `after` call |
| `file_exists` | A file created during the run matches `path` |
| `llm` | A judge votes PASS on the rubric in the file body in two of three votes |
| `baseline` | A judge rates the run at least as good as a reference transcript |

Check that the skill fired with a `tool_used` grader on the `Skill` tool:

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?my-skill"'
---
```

For a near miss, set `min: 0`, `max: 0` and `arm: both`, so the check counts in both arms.

Write `llm` rubrics as concrete PASS and FAIL conditions, and keep them for short output.
Grade long output with `regex` over the file.
The judge defaults to Haiku, and `--judge-model sonnet` gives steadier verdicts on nuanced rubrics.

## Reading the results

The report shows `WITH`, `W/OUT` and `Δ` per case.
Graders on the `Skill` tool, and any marked `arm: with-only`, are reported as indicators and left out of the score, so the two arms stay comparable.

- A case that scores 1.0 in both arms shows that the skill is not what made it pass.
- A failing Skill grader with `Δ` near zero means the description does not trigger on that phrasing.
- A passing Skill grader with a negative `Δ` points at the judge before the skill.
Re-run with a stronger judge and tighten the rubric.
- Read the transcripts as well as the scores.
If every run writes the same helper, bundle it as a script.
If the skill makes Claude spend turns on unproductive work, cut the instruction that causes it.

The command exits 0 when every case meets `--threshold` (default 1.0), 1 when one falls short or the plugin fails to load, and 2 when the run stopped early, for example at the cost ceiling.

To compare two versions of a skill, copy the old plugin directory aside before editing, and run the same suite against both copies.

## skill-creator

`claude plugin install skill-creator@claude-plugins-official` installs Anthropic's skill-creator.
It keeps cases in `evals/evals.json` inside the skill, runs each case in a subagent with and without the skill, grades assertions, aggregates pass rate, time and tokens into `benchmark.json`, and opens a review viewer for the user's feedback.
It also does blind A/B comparison between two versions.
Use it for iterating on one skill inside a conversation, and `claude plugin eval` for a suite you keep and re-run.

## Trigger queries and description tuning

skill-creator's description loop works from about 20 queries, 8-10 that should trigger and 8-10 that should not.

- Write queries the way users type them: concrete, with file names, context and sometimes typos or abbreviations.
- Cover different phrasings of the same intent, cases that do not name the skill or file type, and cases where this skill competes with another and should win.
- Make the negatives near misses that share keywords with the skill.
"Write a fibonacci function" tests nothing for a PDF skill.

The loop runs each query three times, splits the set 60/40 into training and held-out queries, proposes descriptions for up to five iterations and returns `best_description`, chosen by held-out score.
Pass the model ID of the current session, so the result matches what the user experiences.
Keep the result within 1,024 characters and show the user the before and after.

## Testing across models

Run the cases on each model the skill will meet.
If Haiku misses a step, make the step clearer or turn it into a script.
If Opus does worse with the skill than without it, remove instructions until it does better.
Anthropic's prompting guide for its newest models warns that skills written for older models are often too prescriptive, and that verification steps carried over from them can cause over-verification.

## Cost and data

Every agent run and every judge call is a billed model call.
A suite costs roughly cases × runs × 2 agent runs, plus three judge calls per `llm` grader per run.
Agree the run count and a `--max-cost-usd` ceiling with the user before launching, and use `--ablation none` while iterating on graders to halve the cost.

The HTML report is published to claude.ai by default when the account supports it.
Pass `--no-publish` unless the user wants it shared, because the report contains the prompts and transcripts.
Use `--trust-plugin` only for plugins the user wrote, because the runs execute the plugin's code as the user.
