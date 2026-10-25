# Pattern guide for Python

A selection guide for the 23 patterns of Gamma, Helm, Johnson and Vlissides, *Design Patterns: Elements of Reusable Object-Oriented Software* (Addison-Wesley, 1994).
It is paraphrased from open secondary sources and the Python documentation, and it contains no text from the book.
The sources were read on 2026-10-23, and some passed through a summarising model, so quoted wording should be checked against the page before it is reused elsewhere.

## Contents

- How to use the guide
- Creational patterns
- Structural patterns
- Behavioural patterns
- Patterns that are easy to confuse
- When not to apply a pattern
- Selecting by forces
- Where the sources disagree
- Gaps in the evidence
- Sources

## How to use the guide

Run the gate in `SKILL.md` for each candidate: a named force, the Python idiom first, a variation that exists now, and a cost below the force.
The tables give the force that justifies each pattern, its cost, the idiom to check first and an evidence tag.

The evidence tags mean:

- `done`: intent and Python treatment each rest on a source that was read, and the sources agree in direction.
- `thin`: the Python treatment rests on one source or on inference from the Python documentation.
- `not found`: no read source gives a Python treatment.

`[Likely]` and `[Guessing]` mark a mapping from a pattern to a Python feature that no source states, and that the researchers inferred.
Treat a `[Guessing]` mapping as a lead to test in the codebase and not as a recommendation.

## Creational patterns

| Pattern | Force that justifies it | Cost | Python idiom first | Evidence |
| --- | --- | --- | --- | --- |
| Abstract Factory | Product families must stay consistent with each other, and a new family must arrive without client edits | Many classes and interfaces, easy to over-build | Pass a class or a factory function. A mapping or a dataclass of callables carries a family [Likely] | done |
| Builder | One construction process yields several representations, or construction takes many steps | More classes | Keyword arguments, defaults, `dataclass(kw_only=True)` and `dataclasses.replace`. The full pattern is rare, and the convenient stepwise API that returns a product lives on | done, three positions |
| Factory Method | Code is tied to one concrete class that a caller or subclass must be able to swap | Subclass proliferation | Inject a callable, hold the factory in a class or instance attribute, or bind arguments with `functools.partial` | done |
| Prototype | Clone an instance without knowing its class, or offer a menu of classes to construct later | Circular structures are hard to clone | `copy.copy` and `copy.deepcopy` with `__copy__` for an instance. For a menu of classes, a callable or `functools.partial` | done |
| Singleton | Exactly one shared instance with global access | Hidden coupling, harder tests, care with threads | A module-level object, because a module is shared across the program. Overriding `__new__` misleads readers | done, sources disagree |

## Structural patterns

| Pattern | Force that justifies it | Cost | Python idiom first | Evidence |
| --- | --- | --- | --- | --- |
| Adapter | An incompatible interface that cannot be changed must be used by existing code | An extra layer, and changing the service is sometimes simpler | A thin wrapper class or function that implements only the methods the caller uses. `typing.Protocol` states the target interface without a base class | thin, one page of one source |
| Bridge | Two independent dimensions of variation would multiply subclasses | Added complexity when the class is already cohesive | Compose an abstraction object with an implementation object behind a small interface | thin, one Python source |
| Composite | A tree-shaped model where callers should treat leaves and branches alike | Over-general interfaces and awkward special cases | The same method on every node through duck typing, with no shared base class | thin, one Python source |
| Decorator | Behaviour must be added to objects that cannot be subclassed, or a subclass per combination would explode | Order dependence, hard to unwrap, visible to introspection | Plain wrapper classes with the same method. A `__getattr__` wrapper forwards the rest. The `@` syntax is a different thing from the pattern | done, sources disagree |
| Facade | Callers are entangled with the set-up and call order of many objects | A facade can grow into a god object | A module, or a package `__init__` that re-exports the interface names [Likely] | thin, one dated source and inference |
| Flyweight | Very many similar, data-heavy objects exhaust memory | CPU to rebuild context, and a confusing split between shared and per-object state | `sys.intern`, a cached factory function, `weakref.WeakValueDictionary`, and built-ins that already behave this way | done, sources disagree |
| Proxy | Access must be controlled, lazily initialised or reached remotely behind the same interface | More classes and possible delay | `__getattr__` forwarding, `weakref.proxy` and the `multiprocessing` proxies [Likely, assembled from parts] | thin, no source names the idiom |

## Behavioural patterns

| Pattern | Force that justifies it | Cost | Python idiom first | Evidence |
| --- | --- | --- | --- | --- |
| Chain of Responsibility | The number or order of handlers varies, and the sender must not know the receiver | A request can go unhandled | A list of callables tried in order. `logging` handler propagation and `collections.ChainMap` lookup are analogues [Likely] | thin |
| Command | Operations must be queued, logged, undone or passed around as objects | An extra layer between sender and receiver | A function, a closure or `functools.partial`. Keep a class when undo or serialisable state is needed [Likely] | done, equivalence inferred |
| Interpreter | A recurring problem fits sentences of a small language with a grammar | A complex grammar needs a parser instead, and the language must pay for itself | None found for a custom language. `ast.literal_eval` covers only literal subsets and is not a general replacement | not found |
| Iterator | A structure must be traversed without exposing its representation | Overkill for simple collections | The iterator protocol and generators. The `for` statement is the pattern | done, best supported |
| Mediator | Components depend on each other in a tangle that hinders change and reuse | A mediator can grow into a god object | None found | not found |
| Memento | State must be saved and restored without breaking encapsulation | Memory when snapshots are frequent, and caretaker lifecycle | A frozen dataclass with `dataclasses.replace`, or `copy` and the `pickle` state hooks [Likely]. Python cannot hide fields, so immutability is the protection | thin |
| Observer | A change in one object must reach an open set of dependents | Unspecified notification order, and leaks when subscribers stay referenced | A list of callables, with `weakref.WeakMethod` or a `WeakSet` to avoid keeping subscribers alive [Guessing] | thin |
| State | Behaviour depends on state, and conditionals dominate a class | Overkill with few states, and sibling states couple to each other | A dispatch dict, or an `enum` with `match` for few states [Likely] | thin |
| Strategy | Algorithms are interchangeable at runtime, or many classes differ in one behaviour | Clients must know the differences, and two stable variants do not justify it | Pass a callable, and bind parameters with `functools.partial` | done |
| Template Method | A fixed skeleton has a few steps that clients override | The skeleton limits clients, and a suppressed step can break substitutability | A function that takes the varying step, or a context manager for set-up and tear-down. `unittest` still uses subclass hooks | thin, sources disagree |
| Visitor | New operations are needed over a stable element structure without changing the element classes | Every new element type forces every visitor to change | `functools.singledispatch` for one-argument dispatch, `match` with class patterns, or `ast.NodeVisitor`, which dispatches by class name | done |

## Patterns that are easy to confuse

- Adapter changes the interface, while Decorator and Proxy keep it.
Adapter is applied after the code exists, and Bridge is planned up front.
- Decorator and Proxy share a structure and differ in purpose: Decorator adds behaviour, Proxy controls access.
- Strategy is chosen once for an object and State changes as the object runs, and State can be read as Strategy whose states know each other.
- Mediator centralises communication and Observer distributes it, and the two can be combined with the mediator as publisher.
- A Builder that returns no product at the end is closer to a Facade.
- Command and Memento often combine for undo, and Memento can use Prototype when state is cheap to copy.

## When not to apply a pattern

The catalogue is relative to the languages of its time, so a pattern in a Python design is a sign to check whether a language feature already does the job.
One source argues from the language side that patterns in a program signal a missing abstraction in the language.
Another tests each chapter against modern Python to see which patterns survive, and finds that the principle of composition over inheritance matters more than the list.

Five independent sources agree on the cost of a premature abstraction.
Sandi Metz argues that duplication is cheaper than the wrong abstraction and gives a recovery path: inline the shared code and keep only the part each caller needs.
Martin Fowler's Yagni names four costs of a presumptive feature: building it, delay, carrying it and repairing it.
The rule of three says to extract at the third similar case.
The speculative generality smell flags code written for features that never arrive.
PEP 20 prefers the simple and the explainable.

The limit on this advice: a class that collects conditionals has a simplicity that is largely an illusion as the code grows, so removing a pattern for `if` statements is not automatically simpler.
Judge each case by the force, and keep the pattern when the force is present.

## Selecting by forces

Christopher Alexander's pattern language describes a pattern by its problem, context, forces and solution, and the forces are the conflicting interests the solution resolves.
The GoF book is a catalogue and gives little guidance on selection, and no source read supplies a problem-first decision procedure.
The gate in `SKILL.md` is therefore this plugin's own procedure, built from the per-pattern forces above and from the stopping rules in the previous section [Likely].
Treat it as a working method and not as an established one.

## Where the sources disagree

- Facade: Norvig says modules make it invisible, and the catalogue sites describe it as a class.
- Singleton: the Python FAQ, Rhodes and sourcemaking steer away from the classic form, while refactoring.guru presents it and lists its costs.
- Decorator: Rhodes recommends it rarely, and refactoring.guru presents it as routine.
- Builder: Norvig points to multimethods and Rhodes to optional arguments.
- Flyweight: Norvig classes it as simpler through first-class types, and Rhodes keeps it as useful in Python.
- Template Method: Norvig says functions replace it, and `unittest` still uses subclass hooks.
- Iterator: refactoring.guru lists parallel iteration of one collection as a benefit, while Python iterators and generators that return themselves do not support independent traversal [Likely].

## Gaps in the evidence

- No read source gives a Python treatment of Interpreter or Mediator.
- Adapter, Bridge, Composite, Facade and Proxy rest on one Python source, on inference, or on both.
- Rhodes covers nine of the 23 patterns in dedicated pages, and only Iterator among the behavioural ones.
- Norvig's 1996 talk targets Dylan and Lisp and never mentions Python.
His claim that 16 of 23 patterns are invisible or simpler was read second-hand, and only 11 of his 76 slides were read, so do not quote the count.
- Eight creational and structural intents rest on refactoring.guru, with Rhodes or Norvig for some.
- Wikipedia is the only source for Alexander's framing and for the rule of three's attribution.
- The book's text was not retrieved, as intended.
Quotes attributed to it appear in the evidence files only as Rhodes quotes them.

## Sources

The book:
Gamma, Helm, Johnson, Vlissides, *Design Patterns: Elements of Reusable Object-Oriented Software*, Addison-Wesley, 1994 (InformIT lists ISBN-13 978-0-201-63361-0).
<https://www.informit.com/store/design-patterns-elements-of-reusable-object-oriented-9780201633610>

Python-specific guides:
- Brandon Rhodes, Python Design Patterns, with pages for Abstract Factory, Builder, Composite, Decorator, Factory Method, Flyweight, Iterator, Prototype, Singleton and composition over inheritance. <https://python-patterns.guide/>
- Peter Norvig, Design Patterns in Dynamic Languages, first presented 1996-05-05 and put online 1998-03-17. <https://norvig.com/design-patterns/>

Catalogue sites, used for intent, force and cost:
- refactoring.guru, one page per pattern under <https://refactoring.guru/design-patterns>, and its criticism page <https://refactoring.guru/design-patterns/criticism>.
- sourcemaking, one page per pattern under <https://sourcemaking.com/design_patterns>.

Python documentation: `copy`, `functools`, `weakref`, `sys.intern`, `typing.Protocol`, `dataclasses`, `enum`, `contextlib`, `ast`, `unittest`, `collections` and the programming FAQ, under <https://docs.python.org/3/>.

Criticism and selection:
- Sandi Metz, The Wrong Abstraction, 2016-01-20. <https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction>
- Martin Fowler, Yagni, 2015-05-26. <https://martinfowler.com/bliki/Yagni.html>
- Paul Graham, Revenge of the Nerds, 2002. <https://paulgraham.com/icad.html>
- PEP 20, The Zen of Python. <https://peps.python.org/pep-0020/>
- Typing specification, Protocols. <https://typing.python.org/en/latest/spec/protocol.html>
- Wikipedia, Rule of three and Pattern language (secondary).
