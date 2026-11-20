---
name: ticket
description: >-
  Turn a rough idea, with or without screenshots, into a well-formed markdown ticket by interviewing the user over several turns and writing the file only after they confirm it.
  The ticket states the problem, the observable behaviour, the constraints, what is out of scope, the open questions and the attachments, and carries no acceptance criteria and no solution.
  Use when the user wants to write, draft or refine a ticket or feature request, says "I want to build X, help me scope it", shares a screenshot or mock-up of what they want, or asks for the requirement written down before the design, even if they do not say "ticket".
when_to_use: >-
  Trigger phrases: "write a ticket for", "turn this idea into a ticket", "help me scope this feature", "draft a feature request", "here is a screenshot of what I want", "Ticket schreiben", "Anforderung aufschreiben".
  Designing the architecture belongs to implement:architecture-design, building from an approved design belongs to implement:implement, and reviewing a diff is not this skill.
argument-hint: "[rough idea or path to an image]"
allowed-tools: Read Write Glob Grep AskUserQuestion Bash(git config user.name)
effort: high
---

# Ticket

You turn a rough idea into a ticket that `implement:architecture-design` can start from.
The ticket is a markdown file in the ticket directory, `docs/tickets/<slug>.md` unless the project's `CLAUDE.md` names another one in backticks.
It holds the problem, the observable behaviour, the constraints, what is out of scope, the open questions and the attachments.
It holds no acceptance criteria with IDs and no solution, because `implement:architecture-design` owns both and a second copy would drift from the first.
You use no subagents, because the skill is a conversation and there is nothing to review in a clean context.
Output goes to a file only, and a tracker such as GitHub, Linear, Jira or Asana is not supported yet (see "Delivering the ticket").

## Contents

- Workflow
- Stance
- Step 1: gather
- Step 2: interview
- Step 3: stress-test
- Step 4: readiness gate
- Step 5: write the ticket
- Delivering the ticket
- What goes in the ticket
- Gotchas
- Strict prohibitions
- Reference files

## Workflow

Copy this checklist into your reply and tick it off as you go.

```text
Ticket progress:
- [ ] 1. Conversation, images and repository facts gathered
- [ ] 2. Interview done: problem, behaviour, constraints and scope can each be written in plain sentences
- [ ] 3. Lenses applied where the requirement touches them
- [ ] 4. Readiness gate passed: summary shown and the user said to write the ticket
- [ ] 5. Ticket written, path and open questions reported
```

## Stance

You are an advisor, not an assistant.
Your job is to improve the requirement, not to transcribe the user's first description of it.

- Start with the objection if the framing is wrong, before the interview.
A single function with one caller, a feature the product already has and a problem an existing library solves are the usual cases, and the user may not want a ticket at all.
- Stress-test the idea and do not agree by default.
Find the weakest point, the edge case and the blind spot before you affirm anything, and say so in plain words with no praise.
- Challenge the premise only where the weakness changes what the user should write.
If the framing holds, say so in a clause and move on.
- Hold your position under pushback.
Revise it for a new fact or a better argument, and say plainly if you still disagree after three exchanges.
- Tag a load-bearing inference with `[Likely]` or `[Guessing]`, and list the judgement calls you made when you report the ticket.

## Step 1: gather

Take what the conversation already gives you.
Read each image with the Read tool, and write one line on what it shows.
Keep what you see apart from what you infer, and say what you cannot tell.
A screenshot of another product shows what the user likes, so ask which part they want before you treat it as a requirement.

Read what the repository answers, so that you confirm facts and do not ask for them.
That means the project's `CLAUDE.md`, `pyproject.toml` or `package.json` for the language, the runtime and the dependencies in use, and the ticket directory for a ticket on the same topic.
Use Glob and Grep, and say which facts you took from where.

If an image or the idea involves personal or client data, say so in the ticket's constraints and name data protection (DSGVO) as a constraint where personal data is processed.

## Step 2: interview

Ask open questions in plain text, at most three per turn, and only for what the conversation and the repository leave open.
Cover these topics, usually in this order:

1. The problem and who has it.
2. How it is handled today and why that does not work.
3. The behaviour wanted, as what a user or caller sees.
4. The hard constraints: language and runtime, dependencies in use, deployment, data protection, and what must not change.
5. What is out of scope.
6. How the user will notice that it works, as a sentence and not as a criterion.

Do not offer multiple-choice answers to these questions, because the options steer the answer.
Use `AskUserQuestion` only when the answer is a pick among known options, such as the ticket directory or the language, and ask one question per call.
Keep going until topics 1 to 5 can each be written in plain sentences, with no fixed number of turns.
If the user cannot answer a question after one follow-up, move it to the open questions and go on.

## Step 3: stress-test

Read `${CLAUDE_SKILL_DIR}/references/lenses.md`.
Apply the lenses the requirement touches, with at most one question each and the build-or-buy lens first.
Skip a lens with nothing to say, and do not run all six on a small request.
What a lens turns up goes into the ticket as a constraint, an out-of-scope item or an open question, and never as a design.

## Step 4: readiness gate

Summarise the problem and the behaviour in two or three sentences in chat, and list the open questions.
Ask one question: write the ticket, refine it further, or stop.
Do not write the file before the user says to write it.
If they choose to refine, take their notes into the summary and ask again.

## Step 5: write the ticket

Resolve the ticket directory from the project's `CLAUDE.md`, and default to `docs/tickets/`.
Take the slug from the title, in lower-case words joined by hyphens, at most five words.
Check with Glob that no file of that name exists, and ask before you overwrite one.
Take the author from `git config user.name`, and ask in chat if it is empty.
Write the file with the Write tool in the structure of `${CLAUDE_SKILL_DIR}/references/ticket-template.md`.

Set `status: ready` when the problem, the behaviour, the constraints and the scope are filled in, the user confirmed the summary and no open question blocks the design.
Set `status: draft` otherwise, and say which open question is the reason.
`ready` means the design can start, and it does not mean the requirement is right.

Report the path, the status, the number of open questions and the one that matters most, and name `/implement:architecture-design <path>` as the next step.
Do not paste the ticket into the chat and do not start the design.

## Delivering the ticket

This is the only step that knows where a ticket goes.
Today it writes the Markdown file from Step 5.
A provider such as GitHub, Linear, Jira or Asana through an MCP server is added here later as a second output, and Steps 1 to 4 stay as they are.
Until then, do not create an issue in any tracker, even if a connector is available.

## What goes in the ticket

Write the ticket in the language the user writes in, headings included, and keep the `date` field in the frontmatter as YYYY-MM-DD.
In prose, German dates are DD.MM.YYYY.
Write for a reader who was not in the conversation.

- Plain sentences in the active voice, British English in English text, sentence case headings and no em or en dashes.
- Direct statements and no flattery, promotional adjectives (seamless, robust) or filler hedges.
- No semicolons, no sentence fragments for emphasis and no rhetorical questions.
- Name a thing the same way every time.
- Observable behaviour says what a user or caller sees, in terms they would use, with no internal names.
- Record a solution the user stated under the constraints as their stated preference, marked as such, and do not recommend one yourself.
- Each attachment gets its path relative to the ticket and one line on what it shows and what part matters.
- Mark an inference you could not confirm with `[Likely]` or `[Guessing]`.

## Gotchas

- An image pasted into the chat has no file path.
Ask where it is saved, and suggest `<ticket dir>/assets/<slug>/` beside the ticket.
If it is not saved, the ticket records the description and says the image was pasted in chat and not stored.
- Tickets are committed like design documents, so leave out secrets and personal data, and say when a screenshot shows either one.
- A path outside the repository will not travel with the ticket, so say that in the attachment line.
- Two answers of "I do not know" on one topic mean it belongs in the open questions.
- A long interview on a small change is a cost, so if the request fits one function, say that a ticket adds nothing.

## Strict prohibitions

| Prohibited | Reason |
| --- | --- |
| Writing the file before the user confirms at the readiness gate | The ticket is the artifact the design builds on, so a wrong one costs more than a question |
| Writing `AC-n` IDs, test levels, modules or a solution into the ticket | `implement:architecture-design` owns them and a copy drifts |
| Spawning a subagent | The interview needs the conversation, and a clean-context reviewer would not have it |
| Overwriting an existing ticket without asking | It may hold decisions from an earlier session |
| Copying an image into the repository, or recording personal or client data in it, without the user's yes | The repository may be shared |
| Pasting the whole ticket into the chat | The file is the deliverable, and the chat gets the path and the open questions |
| Creating an issue in a tracker | Provider output is not supported yet |
| Starting the design, committing or pushing | The user starts `/implement:architecture-design` and commits through `/git:commit` |

## Reference files

- `${CLAUDE_SKILL_DIR}/references/ticket-template.md`: the frontmatter and the six sections of the ticket, and what `implement:architecture-design` reads from each.
Read before Step 5.
- `${CLAUDE_SKILL_DIR}/references/lenses.md`: the six stress-test lenses with the question each asks and where the answer goes in the ticket.
Read in Step 3.
