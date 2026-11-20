# Stress-test lenses

Six questions the main session puts to a requirement in Step 3 of `ticket`, before the ticket is written.
They are adapted from the brainstorming lenses of the Elephant-Goldfish Model (see `THIRD_PARTY.md` at the plugin root) and reworded to work on a requirement and not on a design.
The skill applies them itself, with no subagents.

## Contents

- How to use the lenses
- The lenses

## How to use the lenses

Ask a lens only when the requirement touches it, and ask at most one question per lens.
Start with the first lens, because a requirement that an existing tool already meets does not need the rest.
A lens with nothing to say is skipped without comment.
The answer goes into the ticket as a constraint, an out-of-scope item or an open question, as the last column says, and never as a design decision.

## The lenses

| Lens | Question to ask | Goes into |
| --- | --- | --- |
| Build or buy | Does this need new code at all? Could a library, a service or a feature the product already has cover most of it, and what would it cost to be wrong about that? | An open question that names what was checked, or an out-of-scope item |
| Cost and quota | What volume do you expect at the peak, and what does it consume: storage, paid API calls, tokens, rate limits of the services involved? What happens at ten times that volume? | A constraint with a number, or an open question when no one knows |
| Ergonomics | Who uses this and how, and which conventions of the existing interface must it match? When it fails, what should the message let them do next? | Desired behaviour |
| Migration and compatibility | Which existing data, clients, stored formats or versions must keep working, and how would you roll back? | Constraints, under what must not change |
| Observability | How will someone notice in operation that it works or has broken, and what must be visible for that: logs, metrics, alerts? | Desired behaviour or a constraint |
| Maintenance | Who owns this in two years, what does it tie us to, and which part would be painful to change: an external dependency, stored state, a hand-built workaround? | An open question or a constraint |

The Elephant-Goldfish Model has a seventh lens that looks for contradictions in a design and proposes ways to resolve them.
It is left out here because it works on a design and a ticket carries none.
