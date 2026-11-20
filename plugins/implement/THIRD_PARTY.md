# Third-party material

This file lists the outside sources the `implement` plugin draws on.
The plugin's own files are MIT licensed.

## Elephant-Goldfish Model (Google)

| | |
| --- | --- |
| Upstream | <https://github.com/google/elephant-goldfish-model> |
| Licence | Apache-2.0 |
| Commit read | `70406c4d22cc7ea8299637c2c5b44625c48b3f08`, the head of `main` on 2026-11-20 |
| File read | `skills/egm-brainstorm/SKILL.md` |
| Used in | `skills/ticket/SKILL.md` and `skills/ticket/references/lenses.md` |
| Status | Adapted |

The two files above are adapted from the ideas in the upstream brainstorming skill and copy none of its text.
The following were taken over in new words: the multi-turn interview before anything is written, the readiness gate before the artifact is created, the artifact-first delivery, the stance of stress-testing an idea and not agreeing with it, and six of the seven review lenses.

The changes are these.
The skill writes a requirement ticket and not an RFC summary.
The lenses are asked by the main session at the level of a requirement, and no subagent runs them.
The upstream seventh lens, which looks for contradictions in a design, is left out.
Structured question tools are allowed where the answer is a pick among known options.

Because no upstream text is copied, no Apache-licensed text is redistributed with this plugin.
If upstream text is ever copied here, add the Apache-2.0 licence text to this file, keep the upstream copyright and SPDX headers, and mark each changed file as changed.

## Elephant-Goldfish Model as a plugin dependency

The `implement` plugin also declares the upstream plugin as a dependency, and the marketplace lists it as `egm` with a `github` source pinned to the commit above.
It is installed unmodified from upstream and is not vendored here, so no upstream file is copied into this repository by that route.
