# EU and German context

Raise these proactively when the system will run in the EU, process personal data, or sit inside a regulated process. They change architecture, not only paperwork, and they are cheaper to design in than to retrofit.

This is engineering guidance for architecture decisions, not legal advice. Regulatory timelines in this area move; verify current status against primary sources before relying on a date, and route anything consequential through counsel or the responsible data protection officer.

## Why multi-agent changes the compliance surface

Three shifts, each with an architectural consequence.

**Decisions multiply.** Every routing decision is a decision an autonomous system made. Where a single agent produced one traceable action, a supervisor with four specialists produces a chain. If the process is subject to logging or explainability duties, that chain is what must be reconstructible — so routing decisions need to be recorded as structured data at the time they are made, not inferred from prompts afterwards.

**Data crosses more boundaries.** Each agent boundary is a potential transfer. On-premise model serving with hosted tracing still exports the payload, because traces contain the content. Map every boundary and ask where the data physically goes.

**Human oversight becomes harder to locate.** Distributing a decision across agents makes it easy to end up with a system where nobody can point to the human control point. Where oversight is required, put it in the graph as an `interrupt` at a named node so it is a topology fact rather than a policy statement.

## EU AI Act

Determine the role first — provider, deployer, or both. Consultancies frequently become providers of a high-risk system on a client's behalf without having framed it that way, and the obligations differ substantially between roles.

Classify the system, not the technology. A multi-agent architecture is not itself high-risk; the use case is. Annex III areas include employment and worker management, education, essential private and public services including creditworthiness, law enforcement, and migration. If the system touches one, the high-risk obligations govern the design.

Where high-risk obligations apply, these have direct architectural consequences:

- **Automatic logging over the system's lifetime** (Art. 12). Decide log content, retention, and tamper-resistance during design. Prompts and routing decisions belong in this record — a checkpointer chosen for convenience is unlikely to satisfy it.
- **Transparency and instructions for use** (Art. 13). The deployer must understand the system's capabilities and limits, which for a multi-agent system means documenting what each specialist does and when it is invoked. The ADR is genuinely useful input here.
- **Human oversight** (Art. 14). Effective oversight requires a named control point with the information and authority to intervene. Implement it as an interrupt node with the relevant state surfaced, not as a dashboard someone might check.
- **Accuracy, robustness, cybersecurity** (Art. 15). Your evaluation suite and failure controls are the evidence.

Separately, systems interacting directly with people generally carry a disclosure duty (Art. 50) — the user must know they are dealing with an AI system. In a handoffs architecture, confirm the disclosure survives every transition rather than appearing only at the start.

If a general-purpose model is fine-tuned or substantially modified, check whether provider obligations for GPAI attach; post-training work can move you into that role.

Timelines are phased and have been subject to amendment proposals. Check the current position rather than working from memory.

## GDPR

**Lawful basis and minimisation** (Art. 5, 6). Each agent should receive the minimum data for its task. This is the rare case where the compliance requirement and the cost optimisation are the same instruction: filtering context at boundaries reduces both token spend and data exposure. Say so in the ADR — it makes the architecture easier to defend on two fronts at once.

**Data subject rights** (Art. 15, 17). Access and erasure must reach checkpoint history, long-term stores, and traces. Design the deletion path before choosing the persistence backend; a store you cannot selectively delete from is a liability regardless of how well it performs.

**Automated decision-making** (Art. 22). Where the system produces decisions with legal or similarly significant effect without meaningful human involvement, the special regime applies, including a right to human intervention and to contest. An agent chain that reaches a decision without a human node is squarely in scope — this is the single most common way an otherwise sensible agent design acquires a legal problem.

**Storage limitation.** Checkpoints are personal data when they contain conversation. Define TTLs.

**International transfers** (Chapter V). Hosted model APIs, hosted tracing, and hosted vector databases outside the EEA are transfers requiring a valid mechanism and, in practice, a transfer impact assessment. Tracing is the one teams forget, because it feels like telemetry and is actually content.

**DPIA** (Art. 35). Likely required for large-scale or systematic processing, and for automated decision-making. The architecture section of the ADR feeds it directly.

**Records of processing** (Art. 30). Each agent's processing activity belongs in the register.

## Germany specifically

**BDSG** supplements the GDPR, notably on employee data.

**Works council participation** (BetrVG § 87). Introducing technical systems capable of monitoring employee performance or conduct is subject to co-determination. An internal multi-agent assistant that logs employee interactions typically falls in scope, and the works council process has a lead time that belongs in the project plan rather than in a surprise two weeks before launch.

**Public sector procurement.** Expect EVB-IT contract templates, BSI IT-Grundschutz and often C5 attestation, and requirements on data location and operator control. Self-hosted or sovereign-cloud deployment is frequently a hard requirement rather than a preference — which shapes model choice, tracing choice, and checkpoint backend from the first design conversation. Where thresholds are met, GWB and VgV procedures apply and the specification you write may become a tender document.

**Sector regimes.** Financial services: BaFin expectations including MaRisk and BAIT, plus DORA on operational resilience and third-party ICT risk — relevant because each hosted model provider is a third-party dependency. Healthcare: MDR where the system has a medical purpose. Critical infrastructure: NIS2 as transposed.

## Sovereign and on-premise deployment

Where residency or operator control is required, the architecture must hold under these substitutions — and a design that only works against hosted APIs is not portable.

- **Model serving.** Self-hosted open-weight models behind an OpenAI-compatible endpoint, typically vLLM. Resolve via `init_chat_model` from configuration so the switch is a config change, and validate per node — smaller local models tolerate a narrow specialist prompt far better than a supervisor's routing decision, which frequently argues for asymmetric deployment with the routing model kept strongest.
- **Persistence.** Self-hosted Postgres for checkpoints and store.
- **Tracing.** Self-hosted tracing, or a documented decision to accept a transfer. Do not let this default silently.
- **Grounding.** Self-hosted retrieval or a knowledge graph in a self-hosted triple store. Where explainability duties apply, an ontology-backed grounding layer gives a more defensible account of why a specialist produced an answer than embedding similarity does.

Test structured output and tool-calling reliability against the target local model early. Routing quality under a smaller model is the thing most likely to break a design that worked against a frontier API, and discovering it late invalidates the cost model as well as the topology.
