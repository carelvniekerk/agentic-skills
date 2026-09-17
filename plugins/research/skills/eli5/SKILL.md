---
name: eli5
description: >
  Explain any research paper, technical concept, or complex idea in plain English with minimal jargon, concrete analogies, and clear takeaways.
  Use this skill aggressively whenever the user says "ELI5", "explain simply", "explain this to me", "what does this actually mean", "break this down", "in plain English", or "summarise this for a non-expert".
  Also use it when the user wants to share a dense paper or concept with a broader or non-specialist audience.
when_to_use: >
  Trigger phrases: "ELI5", "explain simply", "plain English", "what does this mean", "break it down",
  "dumb it down", "explain like I'm five", "summarise this simply", "what's the gist", "what's the big idea",
  "explain to a non-expert", "what's this paper actually saying".
argument-hint: <topic, paper title, or arXiv ID>
allowed-tools: WebSearch WebFetch Read Write
---

# ELI5 — Explain Like I'm Five

Explain research, papers, or technical ideas in plain English with minimal jargon, concrete analogies, and honest caveats.

Read `${CLAUDE_PLUGIN_ROOT}/references/house-style.md` before writing.
Its register, phrasing blacklist and punctuation rules apply here in full, with one scoped exception: this skill exists to explain mechanisms, so an analogy that genuinely explains how something works is wanted.
An analogy that decorates a sentence the plain noun already handles is not.

Plain English is not the same as a breezy register.
Do not write one-line paragraphs as drum beats, sentence fragments for emphasis, or rhetorical questions the user did not ask.
The section prompts below name the content each section must cover; answer them in prose rather than reproducing them as questions in the output.

## Procedure

If the user names a specific paper or arXiv ID, fetch and read it first before explaining.
If the topic is already in the conversation, explain from that material.

## Output Structure

Always produce all six sections in order:

**One-Sentence Summary**
The entire idea in one sentence a curious non-specialist could follow.

**The Big Idea**
What problem does this solve, and why does anyone care?
What would the world look like without this?

**How It Works**
The core mechanism, using one strong analogy rather than several weak ones.
Avoid jargon; define any technical term immediately if it must appear.

**Why It Matters**
Practical implications — what can people do with this, or what changes because of it?

**What to Be Sceptical Of**
Limitations, caveats, and things the paper or concept glosses over.
Separate what is actually shown from what is claimed or speculated.

**If You Remember Three Things**
Three self-contained bullet points capturing the most important takeaways.

## Rules

- Use short sentences and concrete words throughout.
- One strong analogy beats three weak ones — choose carefully.
The analogy must map onto the actual mechanism; drop it the moment it stops being accurate rather than stretching it.
- Call the thing by one name throughout. Having picked a term for the method, use that term every time instead of varying it for style.
- Never smooth away genuine uncertainty; flag it explicitly.
If the paper's central claim is weaker than its abstract suggests, that belongs in the One-Sentence Summary, not only in What to Be Sceptical Of.
- Keep the explanation inline in the conversation unless the user asks to save it as a file.
- If the user asks about a specific arXiv paper, always fetch it rather than relying on training knowledge.
