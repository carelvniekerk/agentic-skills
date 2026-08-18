# Router: parallel dispatch and synthesis

A routing step classifies the request, fans out to selected specialists in parallel, and synthesises the results. Routers are stateless by default, handling each request independently.

Four phases: **classify** (decide which specialists, and with what sub-question each), **route** (fan out with `Send`), **query** (each specialist works on its own tailored input), **synthesise** (combine into one coherent answer).

The pattern earns its place when you have distinct verticals with separate knowledge bases, you need low-latency parallel queries, and you want explicit control over routing rather than leaving it to an orchestrator's judgement. Enterprise knowledge bases are the canonical case.

## Router or subagents

Both can dispatch to several specialists. The distinction is where control lives.

Choose **router** when you want specialised preprocessing (query decomposition, per-vertical sub-question rewriting), custom or partly deterministic routing logic, or explicit control over the parallel step. Choose **subagents** when the orchestrator should decide dynamically, in context, across multiple hops.

A supervisor is a full agent that maintains conversation context across turns. A router is a single classification step. Multi-hop is the discriminator to test: routers do not do it, because there is no conversational agent to hold intermediate state between hops.

## Fan-out with `Send`

```python
from typing import Annotated, Literal
import operator
from pydantic import BaseModel, Field
from langgraph.graph import END, START, StateGraph
from langgraph.types import Send


class SubQuestion(BaseModel):
    vertical: Literal["finance", "legal", "engineering"]
    question: str = Field(description="Sub-question tailored to this vertical.")


class RoutingPlan(BaseModel):
    """Zero or more verticals to consult. Empty means answer directly."""
    sub_questions: list[SubQuestion]


class RouterState(TypedDict):
    query: str
    plan: RoutingPlan | None
    findings: Annotated[list[dict], operator.add]   # reducer: concurrent writes
    answer: str


def classify(state: RouterState) -> dict:
    plan = ROUTER_MODEL.with_structured_output(RoutingPlan).invoke(
        CLASSIFY_PROMPT.format(query=state["query"])
    )
    return {"plan": plan}


def dispatch(state: RouterState) -> list[Send] | Literal["synthesise"]:
    plan = state["plan"]
    if not plan or not plan.sub_questions:
        return "synthesise"
    return [
        Send("query_vertical", {"vertical": sq.vertical, "question": sq.question})
        for sq in plan.sub_questions
    ]


def query_vertical(payload: dict) -> dict:
    agent = VERTICAL_AGENTS[payload["vertical"]]
    try:
        result = agent.invoke({"messages": [{"role": "user", "content": payload["question"]}]})
        return {"findings": [{"vertical": payload["vertical"], "content": result["messages"][-1].content}]}
    except Exception as exc:
        # Degrade, do not abort the whole fan-out
        return {"findings": [{"vertical": payload["vertical"], "error": str(exc)}]}


def synthesise(state: RouterState) -> dict:
    answer = SYNTHESIS_MODEL.invoke(
        SYNTHESIS_PROMPT.format(query=state["query"], findings=state["findings"])
    )
    return {"answer": answer.content}


builder = StateGraph(RouterState)
builder.add_node("classify", classify)
builder.add_node("query_vertical", query_vertical)
builder.add_node("synthesise", synthesise)
builder.add_edge(START, "classify")
builder.add_conditional_edges("classify", dispatch, ["query_vertical", "synthesise"])
builder.add_edge("query_vertical", "synthesise")
builder.add_edge("synthesise", END)
graph = builder.compile()
```

Four things in that scaffold carry weight.

**The reducer on `findings`.** Several `query_vertical` invocations write the same key concurrently. Without `Annotated[list, operator.add]` the writes conflict and LangGraph raises rather than silently picking one. This is the single most common defect in hand-written router graphs.

**Structured classification.** The routing decision comes back as a validated Pydantic model over a closed `Literal` set. Parsing a vertical name out of free text is how routers develop the failure mode where a rephrased model response sends every query to the default branch.

**Zero is a valid fan-out width.** Simple queries should reach synthesis without consulting anything. If your classifier cannot return an empty plan, you are paying specialist calls on "hello".

**Per-branch failure containment.** One vertical timing out should degrade the answer, not fail the request. Return the error into `findings` and let the synthesiser state what it could not consult — a partial answer that names its gap is more useful, and more defensible in an audit, than a 500.

## Statelessness, and how to recover memory

Routers pay the classification call on every turn and carry nothing forward. For one-shot analytical queries that is a feature: consistent cost, no history to corrupt.

For conversation, do not bolt state onto the router. Wrap the whole router as a single tool inside a stateful conversational agent. The agent holds memory and decides when a lookup is needed; the router keeps its clean stateless contract; you stop paying classification on turns that need no lookup.

Resist making the router itself stateful across turns. Routing different turns of one conversation to specialists with different prompts and voices produces an assistant that feels inconsistent. If that is the requirement, the requirement is handoffs or subagents.

## Routing accuracy is the thing to measure

The classifier is the load-bearing component, and it is the one component in this pattern that is trivially evaluable offline. Build a labelled set of queries to expected vertical sets, assert on it in CI, and set a target in the ADR. Track precision and recall separately: over-routing wastes tokens, under-routing produces confidently incomplete answers, and only one of those is visible to the user.
