# Handoffs: state-driven transitions

Behaviour changes based on a state variable. A tool writes `current_step` or `active_agent`; the system reads it and adjusts configuration — system prompt and available tools — or routes to a different agent. The variable persists across conversation turns, which is what makes sequential workflows possible.

This is the only pattern where a specialist both owns the user conversation and remembers where the conversation got to. That combination is why it wins customer support, staged intake, and any flow where capability must unlock on precondition. The price is statefulness: it cannot parallelise, and multi-domain fan-out degrades badly because each domain must be visited in sequence with the conversation history growing throughout.

## Two implementations, and the default

**Single agent with middleware** — one agent whose prompt and tool set are rewritten per model call based on state. **Multiple agent subgraphs** — distinct agents as graph nodes, navigated with `Command.PARENT`.

Prefer single agent with middleware. It is simpler, message history flows naturally, and it removes the entire class of malformed-history bugs. Reach for subgraphs only when a specialist is genuinely a bespoke implementation — a node that is itself a graph with retrieval or reflection steps — not merely because "they are different agents" conceptually. The conceptual distinction is satisfied by different prompts and tools.

## Single agent with middleware

```python
from typing import Callable
from langchain.agents import AgentState, create_agent
from langchain.agents.middleware import ModelRequest, ModelResponse, wrap_model_call
from langchain.messages import ToolMessage
from langchain.tools import ToolRuntime, tool
from langgraph.types import Command


class SupportState(AgentState):
    current_step: str = "triage"
    warranty_status: str | None = None


@tool
def record_warranty_status(status: str, runtime: ToolRuntime[None, SupportState]) -> Command:
    """Record warranty status and advance to the specialist step."""
    return Command(update={
        "messages": [ToolMessage(
            content=f"Warranty status recorded: {status}",
            tool_call_id=runtime.tool_call_id,
        )],
        "warranty_status": status,
        "current_step": "specialist",
    })


STEP_CONFIG = {
    "triage": {"prompt": TRIAGE_PROMPT, "tools": [record_warranty_status]},
    "specialist": {"prompt": SPECIALIST_PROMPT, "tools": [provide_solution, escalate]},
}


@wrap_model_call
def apply_step_config(
    request: ModelRequest,
    handler: Callable[[ModelRequest], ModelResponse],
) -> ModelResponse:
    step = request.state.get("current_step", "triage")
    config = STEP_CONFIG[step]
    request = request.override(
        system_prompt=config["prompt"].format(**request.state),
        tools=config["tools"],
    )
    return handler(request)


agent = create_agent(
    model=init_chat_model(settings.model),
    tools=[record_warranty_status, provide_solution, escalate],
    state_schema=SupportState,
    middleware=[apply_step_config],
    checkpointer=checkpointer,  # required: state must survive turns
)
```

Two points that decide whether this works in practice.

The `ToolMessage` with a matching `tool_call_id` is not optional. When a model calls a tool it expects a response; a `Command` that updates `messages` without the paired acknowledgement leaves malformed history that providers reject — often intermittently, which is why it gets misdiagnosed as model flakiness.

The checkpointer is not optional either. The whole pattern rests on the step variable surviving between turns. Without persistence you have an agent that forgets which stage it reached, which presents as the user being asked for their warranty ID three times.

Because tools gate the transitions, the state machine is enforced structurally rather than by instruction. That is the property worth writing into the ADR: `provide_solution` is not merely discouraged before triage completes, it is absent from the tool set.

## Multiple agent subgraphs

```python
from langchain.messages import AIMessage, ToolMessage
from langchain.tools import ToolRuntime, tool
from langgraph.types import Command


@tool
def transfer_to_sales(runtime: ToolRuntime) -> Command:
    """Transfer the conversation to the sales agent."""
    last_ai_message = next(
        msg for msg in reversed(runtime.state["messages"]) if isinstance(msg, AIMessage)
    )
    transfer_message = ToolMessage(
        content="Transferred to sales agent",
        tool_call_id=runtime.tool_call_id,
    )
    return Command(
        goto="sales_agent",
        update={
            "active_agent": "sales_agent",
            "messages": [last_ai_message, transfer_message],
        },
        graph=Command.PARENT,
    )
```

Crossing a subgraph boundary requires **both** messages: the `AIMessage` that made the handoff call, and the `ToolMessage` acknowledging it. Send only one and the receiving agent inherits an incomplete conversation.

Pass only that pair, not the full subagent history. Forwarding everything is tempting and wrong on two counts: the receiving agent gets confused by another agent's internal reasoning, and the token cost climbs for no benefit. If the receiver needs context, summarise it into the `ToolMessage` content rather than shipping raw history.

Route on message shape rather than a flag alone, so a specialist that answers without handing off actually terminates:

```python
def route_after_agent(state: MultiAgentState) -> Literal["sales_agent", "support_agent", "__end__"]:
    messages = state.get("messages", [])
    if messages:
        last = messages[-1]
        if isinstance(last, AIMessage) and not last.tool_calls:
            return "__end__"
    return state.get("active_agent") or "sales_agent"
```

When returning control to the user, ensure the final message is an `AIMessage`. This keeps history valid and signals to the interface that the turn is over.

## Design questions to settle before building

**Context filtering per specialist.** Full history, a filtered slice, or a summary? Different roles usually want different answers, and "full history everywhere" is the choice that silently reintroduces the context problem.

**Tool semantics.** Does `transfer_to_sales` only move routing state, or does it also create a ticket? Mixing routing with side effects makes the transition non-idempotent, which matters as soon as you add retries.

**Backward transitions.** Can the flow return to an earlier step, and if so, what happens to state written by the later step? Answer this before a user says "actually, wrong warranty number".

**Token growth.** Handoffs accumulate history by design. Decide the summarisation trigger up front, since discovering it in production means discovering it as a context-limit error.
