# Production hardening

Design-time concerns that decide whether a topology survives contact with real traffic. Cover the relevant ones in the ADR's failure-modes and observability sections rather than leaving them to be discovered.

## Persistence

Two distinct stores, often conflated:

**Checkpointer** — thread-scoped short-term state: message history, workflow position, interrupt state. Required for anything conversational, anything with `interrupt`, and anything resumable. `InMemorySaver` in tests; `PostgresSaver` or an equivalent durable backend in production. Name the backend in the ADR, because "we have a checkpointer" and "we have a checkpointer that survives a pod restart" are different claims.

**Store** — cross-thread long-term memory: user preferences, learned facts, entity records. Optional, and worth resisting until there is a concrete need; long-term memory in a multi-agent system is a data-protection surface as much as a feature, since it turns a transient conversation into a retained profile.

Retention is a design decision, not an operational afterthought. Decide checkpoint TTL and deletion path during design. Under GDPR an erasure request must reach checkpoint history, and retrofitting deletion into a checkpoint store is markedly harder than designing it in.

## Observability

Multi-agent systems fail in ways single agents do not, and almost all of them are invisible without traces: the supervisor routed to the wrong specialist, the specialist did the work but omitted it from its final message, a parallel branch failed silently and synthesis proceeded regardless.

Trace the full coordination flow. Ensure every agent has a `name` so nodes are identifiable rather than anonymous. Beyond generic tracing, instrument these specifically:

- **Routing decisions** — which specialist, and why, as structured metadata rather than only inside a prompt. This is the signal that makes routing accuracy measurable in production.
- **Boundary token counts** — inbound and outbound at every context boundary. Your cost model predicted these; compare against them monthly, since drift is usually the first sign of a prompt that grew.
- **Sequential depth per request** — the actual critical path, which is what users feel, as distinct from total calls.
- **Fan-out completeness** — for routers and parallel subagents, how many branches were requested versus returned successfully. Partial-failure rate is the metric most often missing.
- **Interrupt dwell time** — where humans are in the loop, how long cases wait. A human-in-the-loop design with no dwell-time metric is a queue nobody is watching.

Where trace data leaves the EU, see `references/eu-compliance.md`; hosted tracing of a system processing personal data is a transfer, and traces contain the payloads.

## Evaluation

Multi-agent systems have one component that is cheap to evaluate offline and disproportionately load-bearing: the routing decision. Evaluate it separately from end-to-end quality.

**Routing accuracy.** A labelled set of realistic requests mapped to expected specialists. Report precision and recall separately — over-routing wastes tokens quietly, under-routing produces confidently incomplete answers. Assert a floor in CI so a prompt edit cannot silently degrade dispatch.

**Boundary contract tests.** For each specialist, assert that its final message contains what the caller needs, since the caller sees nothing else. This catches the commonest subagent defect deterministically, without a model in the loop.

**End-to-end quality.** Slower and noisier; keep the set small and stable, and use it as a regression gate rather than a development signal.

**Cost regression.** Assert token and call ceilings per scenario. Architecture erosion is gradual and shows up in the bill long before it shows up in quality.

**Determinism where you have it.** Deterministic nodes in a custom workflow are ordinary unit-testable code. Test them as such; do not evaluate a rule engine with an LLM judge.

## Failure modes to control

| Failure | Detection | Control |
| --- | --- | --- |
| Routing loop | Step depth per request | `recursion_limit` at invocation; step budget in state where the semantics need one |
| Malformed message history | Provider 400s, intermittent | Pair every tool call with a `ToolMessage`; include the `AIMessage` across `Command.PARENT` |
| Invalid routing target | Schema violation or fallback rate | Structured output over a closed enum; explicit handling of the invalid case |
| Specialist work not reported | Boundary contract test | Prompt that only the final message is visible; return structured state via `Command` |
| Partial fan-out failure | Requested versus returned branches | Contain per branch, write the error into results, have synthesis state the gap |
| Context bloat | Boundary token counts against the model | Filter at boundaries; summarisation trigger defined during design |
| State write conflict | Runtime error on concurrent write | Reducer on every key written by more than one node |
| State loss between turns | Users repeating themselves | Durable checkpointer; verify across restart, not only in a single process |
| Rate limiting under fan-out | Provider 429s clustered | Backoff with jitter; cap fan-out width; queue rather than burst |
| Unbounded background jobs | Job age distribution | TTL and dead-letter path for async delegation |

## Security

Standard practice applies, with two multi-agent-specific notes.

Untrusted content reaching one agent can influence another through shared state, so treat retrieved documents and tool output as untrusted at every boundary, not only at the user input. Prompt-injection surface scales with the number of agents that read shared state.

Any tool with real-world effect — filesystem writes, shell execution, code execution, payments, outbound messages — belongs behind an approval `interrupt` or a sandbox, and behind a scope narrow enough to state in one sentence. Broad tool grants on a supervisor that a model routes to autonomously are the highest-consequence configuration in this whole design space.

Secrets come from the environment or a secret manager, never from code, and never from state that gets checkpointed.

## Deployment

State the target explicitly: LangGraph Platform, self-hosted server, embedded library. It determines what async delegation and remote subagents can look like, and it determines where checkpoint and trace data live — which is where the compliance conversation starts.
