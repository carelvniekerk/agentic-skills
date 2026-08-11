# Cost model

Architecture choice determines latency, cost, and user experience more reliably than model choice does, and unlike model choice it is expensive to reverse. Cost every recommendation. An ADR without arithmetic is an opinion.

Two metrics. **Model calls** drive latency, especially where sequential, and per-request pricing. **Tokens processed** drive processing cost and determine when you hit context limits. They diverge, and the divergence is the interesting part: the pattern with the fewest calls is often the one with the most tokens.

## Calibration points

These are the LangChain published measurements. Treat them as a sanity check on your own arithmetic, not as your answer — your prompt sizes and tool counts are not theirs.

**Scenario A — one-shot.** "Buy coffee"; a specialist can call a `buy_coffee` tool.

| Pattern | Calls |
| --- | --- |
| Subagents | 4 |
| Handoffs | 3 |
| Skills | 3 |
| Router | 3 |

Subagents pays one extra call because the result returns through the supervisor. That call buys centralised control and context isolation.

**Scenario B — repeat request.** Same request twice in one conversation.

| Pattern | Turn 2 | Total | Saving vs subagents |
| --- | --- | --- | --- |
| Subagents | 4 | 8 | — |
| Handoffs | 2 | 5 | 40% |
| Skills | 2 | 5 | 40% |
| Router | 3 | 6 | 25% |

Stateful patterns skip setup on repeat: the handoff already happened, the skill is already loaded. Subagents' cost is flat by design — statelessness buys isolation and pays for it every turn.

**Scenario C — multi-domain fan-out.** Three domains, roughly 2k tokens of documentation each, consulted for one request.

| Pattern | Calls | Tokens |
| --- | --- | --- |
| Subagents | 5 | ~9k |
| Router | 5 | ~9k |
| Skills | 3 | ~15k |
| Handoffs | 7+ | ~14k+ |

This is where intuition fails most often. Skills uses the fewest calls and the most tokens, because all three documentation sets accumulate in one context and every subsequent call reprocesses all of them. Handoffs cannot parallelise at all and must visit domains in sequence with history growing throughout.

## Formulae

Per turn, with `N` = specialists consulted, `D_i` = domain context size, `P` = orchestrator or base prompt, `C` = conversation history.

**Subagents**
```
calls  = 1 (supervisor decides) + N (specialist work) + 1 (supervisor synthesises)
tokens = (P + C) x 2  +  Σ_i (D_i + q_i)
```
Each `D_i` is paid once, in an isolated context, and never re-enters the main conversation. Multi-hop multiplies the supervisor round-trip, so `calls = 1 + Σ_hops (N_h + 1)`.

**Router**
```
calls  = 1 (classify) + N (parallel) + 1 (synthesise)
tokens = P_classify + Σ_i (D_i + q_i) + P_synth + Σ_i r_i
```
Same token shape as subagents, no conversation history carried, so cheaper per request and unable to build on prior turns.

**Skills**
```
calls  = 1 (load) + work calls + 1 (respond)
tokens = Σ over calls_after_load ( P + C + Σ loaded D_i )
```
The summation is the whole story. Loaded context multiplies by the number of remaining calls. Cost grows with conversation length *after* loading, which is why skills is excellent for short interactions and poor for long sessions with several specialisations active.

**Handoffs**
```
calls  = 1 (transition) + 1 (work) + 1 (respond), then 2 per subsequent turn in the same state
tokens = P_step + C, with C growing monotonically
```
Cheap per turn, no parallelism, and history growth is the binding risk. Plan the summarisation trigger during design.

**Custom workflow**
```
calls  = Σ over agentic nodes traversed (deterministic nodes cost 0)
tokens = Σ over agentic nodes ( P_node + inputs_node )
```
The only pattern where you can drive call count *down* by replacing a node with code. Worth stating in the ADR when it applies, because it is a real and frequently available saving.

## Working an estimate

1. Get the request mix from Phase 1, question 6: rough proportions of one-shot, repeat, and multi-domain.
2. Get or estimate `P`, each `D_i`, and typical conversation length. Ask for real numbers; use a tokeniser on actual prompts rather than guessing, and mark any figure you estimated.
3. Compute calls and tokens per turn for the top two candidates in each scenario.
4. Weight by the mix into a blended per-turn figure.
5. Multiply out to daily or monthly volume and, where models differ per node, price at per-node rates rather than one blended rate.
6. Convert calls to latency using the sequential depth, not the total. Four parallel calls cost roughly one call of wall-clock time; four sequential calls cost four.

Present it as a table with the arithmetic visible and the assumptions listed. Reviewers should be able to disagree with an input rather than with the conclusion.

## Worked example

Internal knowledge assistant. Six verticals, ~3k tokens of context each. Mix: 60% single-vertical lookups, 30% two-vertical comparisons, 10% conversational follow-up. Orchestrator prompt 1.5k.

*Router.* Single-vertical: 3 calls; tokens ≈ 1.5k + 3k + 0.5k ≈ 5k. Two-vertical: 4 calls; ≈ 1.5k + 6k + 1k ≈ 8.5k. Follow-up: full 3 calls again, no memory. Blended ≈ 3.3 calls, ≈ 5.9k tokens. Sequential depth is 3 regardless of fan-out width.

*Skills.* Single-vertical: 3 calls; ≈ 1.5k + 3k, then reprocessed ≈ 7.5k. Two-vertical: 3 calls but both contexts resident ≈ 13k. Follow-up: 2 calls, everything still resident ≈ 9k+. Blended ≈ 2.9 calls, ≈ 9.2k tokens.

Router wins on tokens by roughly a third, loses slightly on calls, and loses outright on follow-up experience. The 10% conversational slice is what decides it: wrap the router as a tool inside a stateful agent, keeping router economics for lookups and paying conversational cost only on turns that need it. That hybrid recommendation falls out of the arithmetic — which is the point of doing the arithmetic.

## What not to do

Do not present token counts to three significant figures from estimated inputs; state the precision honestly. Do not blend model prices when nodes use different models. Do not report call count as a proxy for latency without stating sequential depth. Do not omit the cost of the pattern you are recommending against — a comparison with one column is an advertisement.
