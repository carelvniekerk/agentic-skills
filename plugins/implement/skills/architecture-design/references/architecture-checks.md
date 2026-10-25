# Architecture checks for Python

What to design and what a reviewer can check from a diff and a design document, for module boundaries, dependency direction, decision records, quality attributes and fitness functions.
The sources were read on 2026-10-23, and several primary sources were not read, which the evidence limits section lists.
Where a point rests on one secondary source or on inference, the text says so.

## Contents

- The dependency rule
- Boundaries and dependency direction
- Coupling and cohesion
- Decision records and diagrams
- Quality attributes
- Fitness functions with import-linter
- Python practice
- Reviewer checks by topic
- Evidence limits
- Sources

## The dependency rule

Four sources agree that source-code dependencies point towards the domain, and that the inside of the application must not know the outside.
Cockburn's ports and adapters, Martin's clean architecture and Palermo's onion architecture state this as the defining rule.
Fowler presents inverting the data layer as an optional variation of a three-layer design.
The design states which rule it adopts, and the architecture reviewer holds the change to that rule.

Across a boundary, pass simple data structures and not framework objects, so that the domain does not import a request, a row or a model class from an outer layer.

## Boundaries and dependency direction

Assign every package to a layer in the design.
Where a boundary needs an interface, define a port as a `typing.Protocol`, because structural subtyping lets an adapter satisfy it without importing the domain's base class.
Construct the concrete classes in one composition root, so that high-level modules receive their collaborators and never build a low-level one.
Dependency injection without a framework, through a bootstrap script as the composition root, is documented in one book chapter, which makes it a single-source recommendation.

A reviewer can check from a diff:

- Imports that run from an inner module to an outer one.
- Request, ORM or framework objects entering the core.
- A concrete low-level class constructed inside a high-level module.
- A new cross-package import that the design does not allow.

A reviewer cannot check from a diff the correctness of the layer assignment itself, or imports made dynamically at run time.

## Coupling and cohesion

No source read gives a pass or fail value for the Chidamber and Kemerer metrics (CBO, LCOM and the others), for Instability or for Abstractness.
The empirical support that exists is for predicting faults on specific datasets, and not for a limit that applies to one change.
So the design sets no numeric threshold, and a reviewer treats a rise in the number of imports as a prompt to look closer and never as a finding by itself.

The definitions of afferent and efferent coupling, Instability and distance from the main sequence rest on Wikipedia and search summaries, and Martin's primary texts were not read.
A new import from a stable package to a volatile one is a useful signal [Likely], and it is a judgement and not a measurement.

## Decision records and diagrams

An architecture decision record, in Michael Nygard's form, has a title, a status, a context, a decision and consequences.
Records are numbered in sequence, and a superseded record is marked and kept.
MADR is a maintained template of the same idea, with a Considered Options section and optional sections.
The design document's decisions section follows this shape, and a new dependency or boundary gets a record.

The C4 model describes a system at four levels (context, containers, components, code) and is independent of notation.
The arc42 template has twelve numbered sections, of which sections 1, 2, 4, 9, 10 and 11 carry the most for a reviewer: goals, constraints, the solution strategy, decisions, quality requirements and risks.
A reviewer can check that a record exists and has its sections, and cannot check that it is correct or current from the document alone.

## Quality attributes

ISO/IEC 25010 supplies the vocabulary: in the 2011 edition, eight characteristics (functional suitability, performance efficiency, compatibility, usability, reliability, security, maintainability and portability).
A 2023 edition adds safety and renames usability to interaction capability and portability to flexibility.
That change rests on one secondary source, and the standard's text was not read, and sources disagree on the edition's status, so use the terms as a checklist and not as a citation.
The model supplies vocabulary and no thresholds, so each attribute in a design needs its own measurable target.

ATAM, the Architecture Tradeoff Analysis Method from the Software Engineering Institute, evaluates an architecture through scenarios and a utility tree, with the trade-offs between attributes at its centre.
Its report body was not read, so the design borrows only the habit: name the trade-off each attribute target forces.
A reviewer can map a change to timeouts, retries, caching or validation onto the attribute it affects [Likely], and cannot judge performance, reliability or security without a measurement.

## Fitness functions with import-linter

A fitness function turns a stated architectural characteristic into an automated pass or fail check.
In Python, import-linter is the boundary tool whose contract types the evidence documents.
The version read was 2.15, released 2026-09-04, and the project checks run with `lint-imports`.

The root package is declared in the configuration, which may live in `.importlinter`, `setup.cfg` or `pyproject.toml`:

```ini
[importlinter]
root_package = mypackage
```

A `layers` contract lists layers from the highest to the lowest, and a higher layer may import a lower one and not the reverse (the example below is verbatim from the docs):

```ini
[importlinter:contract:my-layers-contract]
name = My layers contract
type = layers
layers =
    mypackage.high
    mypackage.medium
    mypackage.low
```

The `layers` contract takes optional `containers`, `exhaustive` and `exhaustive_ignores` options.
A `forbidden` contract takes `source_modules` and `forbidden_modules`, with optional `allow_indirect_imports` and `as_packages`.
An `independence` contract takes `modules`.
The shared option `ignore_imports` takes entries of the form `importer -> imported`, with `*` for one module name and `**` for subpackages, and an entry that matches nothing raises an error by default.
The full example blocks for the `forbidden` and `independence` contracts were not verified verbatim, and the docs list two more contract types (`protected` and `acyclic_siblings`) whose options were not read.
Check the live docs before writing a contract with an option not shown above.

Two other tools were found and not read in detail: Tach, for module dependency rules with explicit public interfaces, and deptry, for imports against declared dependencies.

## Python practice

- Use the `src` layout for a package, which the Python Packaging Authority describes as a trade-off and not a rule.
- Define ports as `typing.Protocol`.
`@runtime_checkable` instance checks look at attribute presence only, so do not use an `isinstance` check against a protocol as a signature guard.
The typing specification still slightly prefers nominal subtyping for static checking, so Protocols do not simply replace abstract base classes.
- Modules enter `sys.modules` before they execute, which stops unbounded recursion on a cycle and leaves a half-initialised module visible.
No source gave guidance on breaking cycles.
- A function-local import added to avoid a cycle hides the cycle from the import graph, so a reviewer should read it as a warning sign [Likely].

## Reviewer checks by topic

| Topic | Checks from a diff | Checks from the design document | Evidence gap |
| --- | --- | --- | --- |
| Boundaries and dependency direction | Inner-to-outer imports, framework objects in the core, concrete classes built in high-level modules | Package-to-layer assignment, choice of ports | The dependency inversion text was not read, and layered architecture rests on one source |
| Coupling and cohesion | New cross-package imports, a stable package importing a volatile one [Likely] | The import graph | No threshold in any source, and metric variants are not comparable |
| Decision records | A record for each new dependency or boundary, with its sections and numbering | Considered options, diagram labels | Correctness and currency cannot be read from the document |
| Quality attributes | Changes to timeouts, retries, caching or validation mapped to an attribute [Likely] | Current terms, a measurable target, a named trade-off | The ISO text and the ATAM report were not read |
| Evolutionary architecture | A check exists in CI, fails the build and has not been weakened | Each characteristic has a pass or fail mechanism | The fitness function categories are unverified |
| Python practice | `src` layout, `Protocol` ports, one composition root, import-linter contract changes | The contract set matches the stated layers | Cycle guidance not found, dynamic imports unverified |

A diff reviewer also watches for weakening of the checks themselves: an added `ignore_imports` entry, a loosened contract, a lint suppression on a boundary, or a function-local import that avoids a cycle [Likely].

## Evidence limits

- Martin's Dependency Inversion Principle article, his Stable Dependencies and Stable Abstractions principles, the ISO/IEC 25010 text and the ATAM report were never read, because they failed to fetch or extract.
- The Instability formula and the 2011 characteristic list rest on Wikipedia.
- The 2023 edition of ISO/IEC 25010 rests on one secondary source, and the edition status is unresolved.
- Dependency injection without frameworks rests on one book chapter.
- The Chidamber and Kemerer results rest on abstracts and metadata, and one source dates the paper 2015 against 1994 elsewhere.
- Of 33 sources in the research brief, the verifier re-fetched eight, so the rest rest on the researchers' fetches.

## Sources

- Alistair Cockburn, The Hexagonal (Ports and Adapters) Architecture, 2005. <https://alistair.cockburn.us/hexagonal-architecture/>
- Robert C. Martin, The Clean Architecture, 2012. <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>
- Jeffrey Palermo, The Onion Architecture, part 1, 2008. <https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/>
- Martin Fowler, Presentation Domain Data Layering, 2015. <https://martinfowler.com/bliki/PresentationDomainDataLayering.html>
- Michael Nygard, Documenting Architecture Decisions, 2011. <https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions>
- MADR. <https://adr.github.io/madr/>
- Simon Brown, The C4 model. <https://c4model.com/>
- arc42 documentation. <https://docs.arc42.org/home/>
- arc42 quality model, ISO 25010 update 2023. <https://quality.arc42.org/articles/iso-25010-update-2023>
- Kazman, Klein and Clements, ATAM: Method for Architecture Evaluation, CMU/SEI-2000-TR-004. <https://www.sei.cmu.edu/library/atam-method-for-architecture-evaluation/>
- Ford, Parsons and Kua, Building Evolutionary Architectures. <https://nealford.com/books/buildingevolutionaryarchitectures.html>
- Python Packaging Authority, src layout vs flat layout. <https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/>
- PEP 544, Protocols. <https://peps.python.org/pep-0544/>
- Python documentation, typing and the import system. <https://docs.python.org/3/>
- Import Linter documentation. <https://import-linter.readthedocs.io/en/stable/>
- Percival and Gregory, Architecture Patterns with Python, chapter 13. <https://www.cosmicpython.com/book/chapter_13_dependency_injection.html>
- Package metrics, Wikipedia (secondary). <https://en.wikipedia.org/wiki/Software_package_metrics>
