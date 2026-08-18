# Subagents: centralised orchestration

A main agent — the supervisor — coordinates specialists by calling them as tools. It decides which to invoke, what input to give, and how to combine results. Specialists are stateless by default and remember nothing between invocations; all conversation memory lives with the supervisor.

The property that justifies the pattern is **context isolation**: each invocation runs in a clean context window, so a specialist's 4k of domain documentation never enters the main conversation and never gets reprocessed on subsequent turns. Note the corollary — specialists may have identical capabilities to the supervisor and the pattern still pays for itself, because isolation alone is the benefit.

The property that disqualifies it is that specialists cannot own the user conversation. Results flow back through the supervisor, which costs one extra model call per interaction and means the user only ever hears the supervisor's voice.

## Basic mechanism

```python
from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain.tools import tool

SPECIALIST_MODEL = init_chat_model(settings.specialist_model)  # e.g. "openai:gpt-5.5"
SUPERVISOR_MODEL = init_chat_model(settings.supervisor_model)

research_agent = create_agent(
    model=SPECIALIST_MODEL,
    tools=[search_corpus, fetch_document],
    system_prompt=RESEARCH_PROMPT,
    name="research_agent",  # surfaces in traces and as a subgraph node name
)


@tool("research", description="Research a topic against the internal corpus and return cited findings.")
def call_research(query: str) -> str:
    result = research_agent.invoke({"messages": [{"role": "user", "content": query}]})
    return result["messages"][-1].content


supervisor = create_agent(
    model=SUPERVISOR_MODEL,
    tools=[call_research, call_analysis],
    system_prompt=SUPERVISOR_PROMPT,
)
```

Asymmetric model selection is normal and usually correct: a stronger model for the supervisor, cheaper models for specialists whose task is narrow. Keep both as configuration so the split can be retuned without a code change.

## Tool per agent, or one dispatch tool

**Tool per agent** gives each specialist its own tool with a bespoke signature. Choose it when specialists need different inputs, different output shaping, or different context slices. Cost: every new specialist touches the supervisor's tool list.

**Single dispatch tool** exposes one parameterised `task(agent_name, description)` tool over a registry. Choose it when teams ship specialists independently, when the registry is large or dynamic, or when convention beats configuration. Cost: uniform input and output contracts, so per-agent context engineering is limited.

```python
from enum import Enum

class AgentName(str, Enum):
    RESEARCH = "research"
    ANALYSIS = "analysis"
    REVIEW = "review"

REGISTRY = {AgentName.RESEARCH: research_agent, ...}

@tool
def task(agent_name: AgentName, description: str) -> str:
    """Launch an ephemeral specialist for one self-contained task."""
    agent = REGISTRY[agent_name]
    result = agent.invoke({"messages": [{"role": "user", "content": description}]})
    return result["messages"][-1].content
```

The enum constraint matters: it moves the closed set into the tool schema, so an invalid agent name becomes a schema violation the model can see and correct rather than a `KeyError` at runtime.

Three ways to tell the supervisor what exists, in increasing order of scale: enumerate in the system prompt (fewer than ten, static); enum on the dispatch tool (fewer than ten, wanting type safety); a `list_agents` discovery tool (many, or dynamic — this is progressive disclosure applied to the registry itself).

## Context engineering at the boundary

Three levers, each affecting a different failure mode.

**Specs** — the name and description are the entire basis on which the supervisor routes. Treat them as prompt engineering under version control, and when routing accuracy is the observed problem, fix descriptions before touching topology.

**Inputs** — decide what each specialist receives. Query-only maximises isolation; full context maximises capability. Pull from state via `ToolRuntime` when the specialist needs more than the query:

```python
from langchain.agents import AgentState
from langchain.tools import ToolRuntime, tool

class SupervisorState(AgentState):
    case_id: str

@tool("research", description="...")
def call_research(query: str, runtime: ToolRuntime[None, SupervisorState]) -> str:
    result = research_agent.invoke({
        "messages": select_relevant(runtime.state["messages"], query),
        "case_id": runtime.state["case_id"],  # declare in both state schemas
    })
    return result["messages"][-1].content
```

**Outputs** — the supervisor sees only the specialist's final message. This produces the pattern's most common and most confusing failure: the specialist does the work, the tool results sit in its own history, and the final message summarises rather than reports. Instruct specialists explicitly that the caller sees only their last message. Where structured data must cross the boundary, return a `Command` that writes state keys alongside the `ToolMessage`:

```python
from typing import Annotated
from langchain.messages import ToolMessage
from langchain.tools import InjectedToolCallId
from langgraph.types import Command

@tool("research", description="...")
def call_research(query: str, tool_call_id: Annotated[str, InjectedToolCallId]) -> Command:
    result = research_agent.invoke({"messages": [{"role": "user", "content": query}]})
    return Command(update={
        "citations": result["citations"],
        "messages": [ToolMessage(content=result["messages"][-1].content, tool_call_id=tool_call_id)],
    })
```

## Synchronous or asynchronous delegation

Distinct from Python's `async`/`await`. Synchronous means the supervisor blocks until the specialist returns — correct when the next action depends on the result. Asynchronous means the supervisor starts a background job and stays responsive, which needs three tools (start, check status, fetch result) and an application-level story for notifying the user on completion. Reach for it when a specialist's work is measured in minutes, such as reviewing a long document, and the user should not be held at a spinner.

## Persistence and state visibility

Specialists default to **inherited checkpointer** mode: fresh state per invocation, interrupts supported, safe in parallel. Compile with `checkpointer=True` for continuations mode if a specialist must keep its own history across invocations — but note that this contradicts the stateless assumption the cost model relies on, so record the change in the ADR.

One operational sharp edge worth flagging in any design review: because specialists are invoked inside tool functions, LangGraph cannot discover them statically, so `get_state` with `subgraphs=True` will not return their state. If you need to inspect nested state — typically during an interrupt — invoke the specialist from a node in a custom graph instead of from inside a tool.

## Parallelism

Concurrent execution happens when the supervisor emits multiple tool calls in one step. This is a model behaviour, not a framework guarantee, so prompt for it explicitly ("when tasks are independent, launch them in a single message") and verify it in traces rather than assuming it.

## Do not use `langgraph-supervisor`

The `langgraph-supervisor` package and `create_supervisor` are no longer actively maintained; this pattern supersedes them. If reviewing a codebase that uses them, treat migration as a scheduled task rather than an emergency, and pay particular attention to interrupt and resume flows, which is where the migration is least mechanical.
