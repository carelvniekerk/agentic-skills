# Custom workflow: deterministic graphs with agentic nodes

An explicit LangGraph graph mixing deterministic logic with agentic behaviour. Other patterns can be embedded as nodes — a router inside an analysis step, a subagent supervisor inside a drafting step.

This is the pattern most often needed and most often skipped, because it is less exciting to describe than a supervisor. It is the right answer whenever the process order is defined by something other than the model's judgement: a regulation, a contract, an approval chain, a validation gate. Making the sequence a graph rather than a prompt instruction converts "the agent usually does the checks first" into "the checks are a node the graph must traverse".

## When to choose it

Reach for a custom workflow when the control flow is largely fixed with agentic pockets; when a step must be auditable as having occurred, in order; when a human approval sits in the middle of the process; when different steps need different models and you want that choice explicit rather than emergent; or when partial failure must be handled per stage rather than by retrying the whole conversation.

For German and EU regulated processes this is usually the correct default. An auditor asking "was the eligibility check performed before the decision" is answerable from a graph topology and a checkpoint history. It is not answerable from a supervisor's prompt, and the difference is not rhetorical — one is evidence, the other is an intention.

## Shape

```python
from typing import Annotated, Literal
import operator
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import interrupt


class CaseState(TypedDict):
    case_id: str
    documents: list[str]
    extraction: dict | None
    checks: Annotated[list[dict], operator.add]
    decision: str | None
    reviewer: str | None


def extract(state: CaseState) -> dict:
    """Agentic: an agent with document tools."""
    result = extraction_agent.invoke({"messages": [...]})
    return {"extraction": result["structured_response"]}


def validate(state: CaseState) -> dict:
    """Deterministic: no model call. Rules are rules."""
    return {"checks": run_rule_engine(state["extraction"])}


def route_after_validation(state: CaseState) -> Literal["human_review", "decide"]:
    if any(c["severity"] == "blocking" for c in state["checks"]):
        return "human_review"
    return "decide"


def human_review(state: CaseState) -> dict:
    """Pause and surface the case to a person."""
    verdict = interrupt({
        "case_id": state["case_id"],
        "extraction": state["extraction"],
        "blocking_checks": [c for c in state["checks"] if c["severity"] == "blocking"],
    })
    return {"decision": verdict["decision"], "reviewer": verdict["reviewer"]}


builder = StateGraph(CaseState)
builder.add_node("extract", extract)
builder.add_node("validate", validate)
builder.add_node("human_review", human_review)
builder.add_node("decide", decide)
builder.add_edge(START, "extract")
builder.add_edge("extract", "validate")
builder.add_conditional_edges("validate", route_after_validation, ["human_review", "decide"])
builder.add_edge("human_review", END)
builder.add_edge("decide", END)

graph = builder.compile(checkpointer=PostgresSaver.from_conn_string(settings.pg_dsn))
```

Points worth internalising.

**Deterministic nodes should not call models.** If a rule engine can decide it, a rule engine should decide it — cheaper, testable, and explicable to an auditor. The most common improvement available to an over-agentified workflow is replacing a model call with fifteen lines of Python.

**Reducers on any key written by more than one node.** Same requirement as the router. `Annotated[list, operator.add]` for accumulating keys; a custom reducer where merge semantics are non-trivial.

**`interrupt` is durable, not a callback.** Execution stops, state persists, and the graph resumes when a `Command(resume=...)` arrives — possibly days later, possibly in a different process. This is what makes genuine human-in-the-loop feasible rather than a blocking web request with a long timeout. It requires a real checkpointer.

**Model choice per node, from configuration.** A cheap model for extraction, a stronger one for the decision, resolved through `init_chat_model`. Make the mapping a config table so it can be retuned and, where residency requires it, repointed at an on-premise endpoint per node.

## Embedding other patterns

A node may invoke a compiled graph of any shape. Compose deliberately:

- A router as the analysis node, when one stage needs parallel multi-source lookup.
- A subagent supervisor as the drafting node, when one stage needs dynamic delegation.
- A handoffs agent as the intake node, when one stage is conversational and staged.

Each embedding is a context boundary. Decide explicitly what crosses it inbound and outbound, and prefer structured state over message history — a workflow node has no reason to inherit another agent's internal reasoning.

## Failure handling per stage

The advantage over a single agentic loop is that failure is localisable. Give each stage its own policy: retry with backoff for transient tool failures, route to human review for validation failures, terminate with a recorded reason for policy failures. A terminal state that records *why* is worth more than a retry that hides it.

Set `recursion_limit` at invocation anyway. Any graph with a cycle can loop, and a bounded failure is diagnosable where an unbounded one is a bill.
