---
name: langgraph-multi-agent-architect
description: Select and specify multi-agent architectures for LangChain and LangGraph — subagents, handoffs, skills, router, or custom workflow — and deliver an architecture decision record with an explicit call/token cost model plus a minimal provider-agnostic scaffold. Use this skill whenever the user mentions multi-agent systems, agent orchestration, supervisors, subagents, handoffs, swarms, agent routing, LangGraph state graphs, deepagents, or asks how to split one agent into several. Also use it when they describe the symptoms rather than the pattern — an agent with too many tools, prompt bloat, context overflow, several teams editing one system prompt, or a wish to run agents in parallel. Use it before writing any orchestration code, and use it when reviewing, costing, or debugging an existing multi-agent design.
---

# LangGraph Multi-Agent Architect

Multi-agent architecture is a cost and coupling decision disguised as a topology decision. Topology is easy to draw and hard to reverse, so the value you add is in refusing the wrong topology early and making the chosen one's costs explicit before anyone writes a graph.

Work through four phases in order. Do not skip to code, even when the user opens with "build me a supervisor with three subagents" — that request names a topology, which is an output of this process, not an input to it.

| Phase | Purpose | Output |
| --- | --- | --- |
| 0. Gate | Establish that multi-agent is warranted at all | An explicit single-agent rejection, or a stop |
| 1. Elicit | Recover the constraints that discriminate between patterns | A filled constraint table |
| 2. Select | Map constraints to a pattern and cost it | A ranked choice with arithmetic |
| 3. Specify | Make the decision reviewable and buildable | ADR plus minimal scaffold |

## Phase 0: The single-agent gate

Most systems described as needing multi-agent need better tool descriptions. Adding agents adds model calls, serialisation boundaries, and failure modes that are invisible in a diagram, so the burden of proof sits with the multi-agent proposal.

State the gate explicitly and answer it in writing. Multi-agent is warranted only if at least one of these holds:

1. **Context pressure.** The specialised knowledge for the capabilities genuinely cannot coexist in one prompt — not "is long", but measured: sum the per-domain prompt and tool-schema tokens and compare against the context budget you actually intend to run at, allowing for conversation growth.
2. **Distributed ownership.** Separate teams must ship and version capabilities independently. This is an organisational constraint and no amount of prompt engineering dissolves it.
3. **Parallelism.** Independent subtasks must execute concurrently to meet a latency target, and you can name that target.
4. **Sequential constraint enforcement.** Capabilities must remain locked until preconditions are satisfied, and prompt-level instruction is insufficient because the consequence of violation is material (a refund issued without a warranty check, a trade placed without a limit check).
5. **Tool-selection degradation.** A single agent demonstrably picks wrong among too many tools. Demand evidence: an eval or trace showing the failure, not an intuition.

If none holds, say so plainly and propose the cheaper fix instead — sharpen tool descriptions, split one tool into two with narrower contracts, add a retrieval step, or apply dynamic tool filtering via middleware within a single agent. Recommending against multi-agent is a successful use of this skill, not a failure to engage.

If one holds, record which one. The binding constraint drives Phase 2 far more than the user's domain does: two systems in unrelated industries with the same binding constraint want the same pattern.

## Phase 1: Constraint elicitation

Ask only what changes the answer. These eight questions are ordered by discriminating power; stop early if the user's brief already answers them, and never ask more than five in one turn.

| # | Question | What it discriminates |
| --- | --- | --- |
| 1 | Must a specialist converse with the end user directly, in its own voice, across several turns? | Rules subagents and router out if yes |
| 2 | Must capabilities unlock only after preconditions are met, and is violation materially costly? | Selects handoffs if yes |
| 3 | Are the domains independent enough to query concurrently for one request? | Selects subagents or router if yes |
| 4 | Is the choice of specialist a classification you could write down, or a judgement the model must make in context? | Router if classifiable, subagents if judgement |
| 5 | How large is each specialisation's context, and how many are typically active per conversation? | Feeds the token model; large × few favours isolation |
| 6 | What is the request mix — mostly one-shot, mostly multi-turn repeat, or mostly multi-domain fan-out? | Selects the cost scenario that dominates |
| 7 | Who owns each capability, and do they release on independent schedules? | Weights distributed development |
| 8 | Is any part of the control flow non-negotiable — a fixed sequence, an approval, an audit checkpoint? | Pulls towards custom workflow |

Two answers deserve follow-up rather than acceptance. When a user says "everything must be parallel", ask what the latency target is and whether the domains genuinely have no data dependencies; false parallelism costs tokens for no wall-clock gain. When a user says "the agents should just talk to each other freely", ask who is accountable when they loop; unconstrained many-to-many messaging is the topology most likely to fail in production and least likely to survive an audit.

## Phase 2: Pattern selection

Five patterns are available. Four come from the LangChain taxonomy; the fifth — custom workflow — is the one practitioners most often need and most often skip past, because deterministic structure with agentic nodes is usually a better fit for regulated processes than a fully agentic orchestrator.

| Pattern | Mechanism | Reference |
| --- | --- | --- |
| Subagents | Main agent calls specialists as tools; specialists stateless, context isolated | `references/subagents.md` |
| Handoffs | Tools write a state variable; behaviour or active agent changes and persists across turns | `references/handoffs.md` |
| Skills | One agent progressively loads specialised prompts and resources on demand | `references/skills-pattern.md` |
| Router | Classify, fan out in parallel, synthesise; typically stateless | `references/router.md` |
| Custom workflow | Explicit LangGraph graph mixing deterministic nodes with agentic ones | `references/custom-workflow.md` |

Read only the reference file for the pattern you select, plus `references/cost-model.md`. Loading all five wastes the context you are supposedly economising on.

### The discriminator ladder

Walk down. The first rule that fires wins; note which rule fired, because that sentence becomes the core of the ADR's decision rationale.

1. **A specialist must hold the user conversation itself, with persistent stage state** → **handoffs**. Subagents return to a supervisor and never own the user relationship; a router is stateless. Only handoffs give a specialist both the microphone and a memory of where the conversation got to.
2. **Sequential preconditions must be enforced structurally** → **handoffs**, or **custom workflow** if the sequence is fully fixed and the enforcement must be auditable rather than model-mediated. Prefer custom workflow when a regulator, not a product manager, defines the order.
3. **Several large-context domains must be consulted concurrently for one request** → **router** if the selection is a classification with useful preprocessing (query decomposition, per-domain sub-question rewriting); **subagents** if the orchestrator must decide dynamically, mid-conversation, possibly across several hops.
4. **Capabilities differ only by prompt and knowledge, not by tool isolation or enforcement** → **skills**. This is the lightest option and correspondingly the easiest to retire; treat it as the default when the constraint is distributed development alone.
5. **Control flow is largely deterministic with agentic pockets** → **custom workflow**.
6. **Nothing above fires cleanly** → return to Phase 0. An unclear pattern choice is usually evidence that the constraint was not real.

### Capability matrix

Use this to sanity-check the ladder's output, not to make the decision — a matrix invites the user to want every column, which is how systems acquire a supervisor they did not need.

| Pattern | Distributed development | Parallelisation | Multi-hop | Direct user interaction | State across turns |
| --- | --- | --- | --- | --- | --- |
| Subagents | Strong | Strong | Strong | None | Main agent only |
| Handoffs | Weak | None | Strong | Strong | Strong |
| Skills | Strong | Moderate | Strong | Strong | Strong |
| Router | Moderate | Strong | None | Moderate | None by default |
| Custom workflow | Moderate | Strong | Strong | Depends on design | Strong |

### Cost the candidates before recommending

Never present a pattern choice without arithmetic. Read `references/cost-model.md` and compute expected model calls and tokens per turn for the top two candidates against the user's actual request mix from question 6. Show the working, because the numbers frequently overturn the intuitive choice — skills looks cheapest by call count and is often the most expensive by tokens, since loaded context is reprocessed on every subsequent call while isolated subagent context is paid once.

If the top two candidates land within roughly 15% of each other on both calls and tokens, say so and decide on operability instead: which one the team can debug at 03:00, which one has fewer places for conversation history to become malformed.

### Composition

Patterns compose, and the honest answer is often a hybrid: a custom workflow whose analysis node is a router, a subagent that internally uses skills, a router wrapped as a single tool inside a stateful conversational agent to recover multi-turn memory without paying routing cost on every turn.

Recommend a hybrid only when a single pattern demonstrably fails a stated constraint. Each composition boundary is a place where message history can become malformed and traces become hard to read, so make the user pay for it with an explicit constraint rather than with enthusiasm.

## Phase 3: The deliverable

Produce two artefacts, in this order, in one response. The ADR carries the decision; the scaffold proves the decision is buildable and pins the API surface.

### Architecture decision record

Use this structure exactly. It is deliberately close to a conventional ADR so it can be committed alongside the code and reviewed by people who were not in the conversation.

```markdown
# ADR-NNN: <system name> multi-agent architecture

## Status
Proposed | Accepted | Superseded by ADR-NNN

## Context
<The workload in two or three sentences. The binding constraint from Phase 0, named
explicitly. The request mix. Any latency, cost, residency, or audit target with numbers.>

## Decision
<Pattern>, because <the ladder rule that fired>.

## Rejected alternatives
<For each pattern seriously considered: one line on what it would have cost or broken.
Include "single agent with better tools" as a rejected alternative every time — reviewers
will ask, and the answer belongs in the record.>

## Cost model
<Table: calls per turn and tokens per turn for the chosen pattern and the runner-up,
across the request mix. Show the arithmetic, state the assumptions, and mark which
numbers are measured versus estimated.>

## Architecture
<Mermaid diagram. Nodes, edges, and where state is written. Mark every boundary where
context is filtered or dropped.>

## State schema
<The typed state, with a note on which keys are shared between agents and which are
private. Name the reducer for any key written by more than one node.>

## Failure modes and controls
<Table: failure mode, detection signal, control. Cover at minimum: routing loops,
malformed message history at handoff or composition boundaries, subagent returning
work that is absent from its final message, partial failure during parallel fan-out,
and unbounded recursion.>

## Observability and evaluation
<What is traced, what is asserted in CI, what the regression suite covers. State the
routing-accuracy target and how it is measured.>

## Compliance notes
<Only where applicable. See references/eu-compliance.md before writing this section.>

## Consequences
<What becomes easy. What becomes hard. What must be revisited, and on what trigger.>
```

### Minimal scaffold

Emit the smallest code that makes the topology concrete and runnable — typically 60 to 150 lines. The scaffold's job is to pin the API surface and the state contract so the team argues about the design rather than about imports.

Conventions to hold to, each for a reason:

- **Provider-agnostic model selection.** Take model identifiers from configuration and resolve with `init_chat_model`, never a hardcoded provider class. Self-hosted serving then becomes a config value rather than a code change, which matters when the same graph must run against a hosted API in development and an on-premise endpoint in production.
- **Current API surface.** `create_agent` from `langchain.agents`; `AgentState` for state extension; `ToolRuntime` for tool-side state and `tool_call_id` access; `Command` for combined control flow and state updates; `@wrap_model_call` middleware for dynamic prompt and tool configuration. Do not use `langgraph-supervisor` or `create_supervisor` — that package is no longer maintained and the subagents pattern supersedes it. Do not reach for `langgraph.prebuilt.create_react_agent` in new designs.
- **Return partial state updates.** Nodes and tools return only the keys they change. Mutating the state object and returning it whole defeats the reducers, makes concurrent writes unsafe, and is the single most common defect in inherited LangGraph code.
- **Pair tool calls with tool messages.** Any tool returning a `Command` that updates `messages` must include a `ToolMessage` carrying the matching `tool_call_id`. When handing off across a subgraph boundary with `Command.PARENT`, include both the `AIMessage` that made the call and the acknowledging `ToolMessage`. Omitting the pair leaves the receiving agent with a conversation history that no provider will accept.
- **Structured routing, not string parsing.** A router or supervisor decision must come back as structured output validated against a closed set — an enum or Literal — never as free text matched with `.strip().lower()`. Handle the invalid case explicitly rather than defaulting silently to one branch.
- **Bound the loop.** Set `recursion_limit` at invocation. Add a step budget in state only where the semantics need one, such as a reflection loop with a maximum number of revisions, and make exhausting the budget a visible outcome rather than a silent end.
- **Persist deliberately.** Attach a checkpointer whenever state must survive a turn, and say in the ADR which store backs it in production. `InMemorySaver` belongs in tests and nowhere else.
- **Filter context at every boundary.** Decide explicitly what each specialist receives. Passing full history everywhere is the default that quietly produces the token bill the architecture was meant to avoid.
- **Leave the sharp edges out.** No secrets in code, no unsandboxed code execution, no shell tools without an approval interrupt.

Mark clearly what the scaffold omits — retries, real tools, prompt content, persistence backend — so nobody mistakes it for a starting point that is nearly done.

## Reviewing an existing architecture

When the user brings a system rather than a blank page, run Phases 0 to 2 as a diagnosis and report against this structure. Resist the pull towards a rewrite: identify the smallest change that resolves the binding constraint.

```markdown
## Observed symptom
## Diagnosis
<Which constraint the current topology fails, and why the topology causes the symptom
rather than merely correlating with it.>
## Pattern mismatch
<Current pattern versus indicated pattern, or "pattern is correct, implementation is not".>
## Minimal correction
## Migration path
<Ordered steps, what breaks, what is reversible.>
## Cost delta
```

Before proposing anything, check for these, in order of how often they turn out to be the actual cause:

1. Nodes mutating and returning whole state, so reducers never run and parallel writes race.
2. Handoff tools omitting the `ToolMessage` pair, producing intermittent provider errors that look like model flakiness.
3. Supervisor routing parsed from free text, so a rephrased model response silently ends the run.
4. Every agent receiving full conversation history, so the context isolation the architecture exists to provide was never actually achieved.
5. Subagents performing work correctly but omitting it from their final message, since only that message reaches the supervisor.
6. No checkpointer, or `InMemorySaver` in production, so state loss presents as amnesia between turns.
7. A supervisor added for a system with one binding constraint that a single agent with filtered tools would satisfy.

## German and EU context

Consult `references/eu-compliance.md` whenever the system will run in the EU, handle personal data, or touch a regulated process, and raise the relevant points without waiting to be asked. Autonomous routing between agents changes the compliance surface in ways that a single agent does not: it multiplies the number of decisions requiring records, and it usually multiplies the number of jurisdictions the trace data passes through.

## Reference files

Read on demand. Each is self-contained.

- `references/subagents.md` — supervisor with specialists as tools; tool-per-agent versus single dispatch tool; context engineering at the boundary; checkpointer modes.
- `references/handoffs.md` — single agent with middleware versus agent subgraphs; state-driven transitions; message pairing across `Command.PARENT`.
- `references/skills-pattern.md` — progressive disclosure; the three-level loading model; when accumulation becomes the dominant cost.
- `references/router.md` — classify, fan out with `Send`, synthesise; structured classification; partial failure handling.
- `references/custom-workflow.md` — deterministic graphs with agentic nodes; human-in-the-loop interrupts; audit checkpoints.
- `references/cost-model.md` — call and token accounting per pattern, calibration points, worked examples.
- `references/production-hardening.md` — persistence, observability, evaluation, failure controls, deployment.
- `references/eu-compliance.md` — AI Act, GDPR, data residency, sovereign deployment, public procurement.
