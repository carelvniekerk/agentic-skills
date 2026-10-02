---
name: eli5
description: >-
  Explain a research paper, method or technical concept in plain English for a non-specialist, in six fixed sections with one analogy that maps onto the mechanism and an honest section on what to be sceptical of.
  Use when the user says "ELI5", "explain like I'm five", "explain this paper simply", "in plain English", "for a non-expert" or "summarise this paper for my manager", or wants a dense paper explained to a broader audience.
when_to_use: >-
  Trigger phrases: "ELI5", "explain like I'm five", "plain English", "explain this paper simply", "dumb this paper down", "what's this paper actually saying", "explain to a non-expert", "what's the big idea of this paper".
  Explaining an error message, a stack trace or code in the current project is not this skill, and Claude answers that directly.
argument-hint: <topic, paper title or arXiv ID>
allowed-tools: WebSearch WebFetch Read
---

# ELI5

You explain a paper or concept to a curious non-specialist, inline in the conversation, without losing its caveats.
Save the explanation to a file only when the user asks.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing.
Its register and phrasing rules apply in full, with one scoped exception: an analogy that explains how the mechanism works is wanted, and one that decorates a sentence the plain noun already handles is not.
Plain English is not a breezy register, so no one-line drum-beat paragraphs, no fragments for emphasis and no rhetorical questions.

## Procedure

1. If the user names a paper or an arXiv ID, fetch and read it first, never explain it from training knowledge.
2. If the material is already in the conversation, explain from that.
3. Write the six sections below, in order, as prose.
The prompts under each heading say what the section covers, and they are not questions to reproduce in the output.

## Output

**One-sentence summary.**
The whole idea in one sentence a curious non-specialist could follow.
If the central claim is weaker than the abstract suggests, this sentence says so.

**The big idea.**
The problem it solves, why anyone cares, and what is worse without it.

**How it works.**
The core mechanism through one analogy that maps onto it.
Drop the analogy the moment it stops being accurate rather than stretching it, and define any technical term that must appear.

**Why it matters.**
What people can do with it, or what changes because of it.

**What to be sceptical of.**
Limitations and what the work glosses over, separating what is shown from what is claimed.

**What to remember.**
At most three self-contained bullets.

## Rules

- Short sentences and concrete words.
- One name for the method throughout, never varied for style.
- Flag genuine uncertainty rather than smoothing it away.
