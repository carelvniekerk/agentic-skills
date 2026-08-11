# Skills: progressive disclosure

One agent loads specialised prompts and knowledge on demand. Technically a single agent, so calling it multi-agent is a stretch — but it delivers two of the same benefits, distributed development and fine-grained context control, through a prompt-driven mechanism rather than by managing agent instances. Treat it as the quasi-multi-agent option, and as the default when the only binding constraint is distributed ownership.

## Three-level loading

1. **Startup** — the agent knows only skill names and descriptions. Cheap: a few dozen tokens each.
2. **On relevance** — the agent loads a skill's full instructions.
3. **On demand** — additional files inside the skill, discovered only if needed.

The design work is deciding what belongs at which level. Level one must be discriminating enough to route on and short enough to carry for free. Level two must be self-contained enough to act on without immediately pulling level three.

## When it fits

Choose skills when specialisations differ by prompt and knowledge rather than by tool isolation or enforcement; when you have many possible specialisations of which few are active per conversation; when different teams own different skills and want to ship them as directories rather than as services; and when the specialist must keep talking to the user directly.

Coding assistants and creative assistants are the canonical cases: a long tail of specialisations, no need to enforce constraints between them, and the user is in dialogue with one persona throughout.

## The cost profile, which is the reason to be careful

Skills has the best call count and frequently the worst token count. Loaded context lands in conversation history and is reprocessed on **every subsequent call**, so the cost is roughly

```
tokens ≈ Σ over remaining calls ( base_prompt + Σ loaded_skill_sizes )
```

Two skills of 3k tokens each, loaded early in a ten-call conversation, cost something like 60k tokens of reprocessing. The same two specialisations under subagents pay 3k each, once, in isolated contexts — the multi-domain comparison in the LangChain benchmarks comes out at roughly 15k versus 9k tokens, a 67% difference in subagents' favour, and the gap widens with conversation length.

So the discriminator is not "how many skills" but **how many are active simultaneously and how long the conversation runs afterwards**. One skill in a short conversation: skills wins on every axis. Three skills in a fifty-turn session: the accumulation dominates and you want isolation.

Mitigations, in order of preference: keep skill bodies genuinely small and push detail to level three; summarise or drop loaded skill content once the sub-task completes; invoke the heavyweight specialisation as a subagent instead and keep skills for the light ones. The hybrid is legitimate and common.

## Implementation notes

A skill is a directory: instructions, optional scripts, optional resources. Loading is a tool call that reads the instructions into context — so the mechanism is ordinary tool use, and the engineering is in the descriptions.

Where a skill needs to change the agent's *tools* rather than only its knowledge, you have crossed into handoffs territory: use `@wrap_model_call` middleware keyed on a state variable recording which skill is active. That is a legitimate hybrid, and worth naming as such in the ADR so the next reader is not surprised by middleware in a system described as skills.

Parallelism is moderate rather than strong: a single agent can issue parallel tool calls, but it cannot fan out into isolated contexts. If parallel isolated execution is a requirement, this is the wrong pattern.

## Evaluating skill triggering

The failure mode is a skill that never loads because its description does not match how users phrase things. This is measurable: collect real phrasings, assert that the right skill loads, and track the trigger rate. Description tuning is cheap and high-yield — do it before concluding the skill content is wrong.
