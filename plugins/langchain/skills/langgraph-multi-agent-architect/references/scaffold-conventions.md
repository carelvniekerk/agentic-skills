# Scaffold conventions

The rules for the minimal scaffold that accompanies the ADR.
Its job is to pin the API surface and the state contract, so the team argues about the design and not about imports.

## Contents

- Verify the API surface first
- Conventions and their reasons
- What the scaffold omits

## Verify the API surface first

The names below are version-dependent.
Before emitting code, check them against the installed `langchain` and `langgraph` versions (read the installed source, or the current docs if nothing is installed) and say which version you checked.
If the project has no LangChain installed, state that the scaffold follows the documentation as of the date you read it.

Names this skill was written against:

- `create_agent` from `langchain.agents`, `AgentState` for state extension, `ToolRuntime` for tool-side state and `tool_call_id`, `Command` for combined control flow and state updates, and `@wrap_model_call` middleware for dynamic prompt and tool configuration.
- `langgraph-supervisor` and `create_supervisor` are no longer maintained, and the subagents pattern replaces them. LangChain's migration guide says so (<https://docs.langchain.com/oss/python/migrate/langgraph-supervisor>, read 2026-10-05), so do not use them in new designs.
- Do not reach for `langgraph.prebuilt.create_react_agent` in new designs.
[Guessing] This one is from earlier knowledge and was not rechecked, so verify it as well.

## Conventions and their reasons

- **Provider-agnostic model selection.** Take model identifiers from configuration and resolve them with `init_chat_model`, never a hard-coded provider class. Self-hosted serving then becomes a config value and not a code change, which matters when the same graph runs against a hosted API in development and an on-premise endpoint in production.
- **Return partial state updates.** Nodes and tools return only the keys they change. Mutating the state object and returning it whole defeats the reducers, makes concurrent writes unsafe, and is the most common defect in inherited LangGraph code.
- **Pair tool calls with tool messages.** A tool that returns a `Command` updating `messages` must include a `ToolMessage` carrying the matching `tool_call_id`. When handing off across a subgraph boundary with `Command.PARENT`, include both the `AIMessage` that made the call and the acknowledging `ToolMessage`. Omitting the pair leaves the receiving agent with a history no provider accepts.
- **Structured routing, not string parsing.** A router or supervisor decision comes back as structured output validated against a closed set (an enum or `Literal`), never as free text matched with `.strip().lower()`. Handle the invalid case explicitly and do not default silently to one branch.
- **Bound the loop.** Set `recursion_limit` at invocation. Add a step budget in state only where the semantics need one, such as a reflection loop with a maximum number of revisions, and make exhausting it a visible outcome and not a silent end.
- **Persist deliberately.** Attach a checkpointer whenever state must survive a turn, and say in the ADR which store backs it in production. `InMemorySaver` belongs in tests and nowhere else.
- **Filter context at every boundary.** Decide explicitly what each specialist receives. Passing full history everywhere is the default that quietly produces the token bill the architecture was meant to avoid.
- **Leave the sharp edges out.** No secrets in code, no unsandboxed code execution, and no shell tools without an approval interrupt.

## What the scaffold omits

Mark clearly what it leaves out: retries, real tools, prompt content and the persistence backend.
