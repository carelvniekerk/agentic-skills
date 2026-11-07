# Architecture design for TypeScript and JavaScript

The TypeScript and JavaScript counterpart of the Python rules in `SKILL.md`: the language default, the idiom to check first per pattern, ports and the composition root, project layouts including MERN with MVC, and boundary checks a tool can run.
Read it in Phase 0 when the language is TypeScript or JavaScript, and keep it for Phases 2 to 5.
`patterns.md` and `architecture-checks.md` still apply for the forces, the costs and the language-neutral checks.
Their Python columns do not, and the table below replaces the idiom column.

## Contents

- Evidence tags
- Language default
- Ports and the composition root
- Idiom to check first per pattern
- Layouts for a Node and MERN system
- Boundary checks
- TypeScript practice
- Reviewer checks by topic
- Evidence limits

## Evidence tags

- `[probed]`: run on 2026-11-07 against the installed tool, and the result was read.
- `[docs]`: stated in the tool's documentation, read on the same date.
- `[inferred]`: the author's reasoning from the Python guide and general practice, with no source behind it.
Treat an `[inferred]` row as a lead to test in the codebase, as the guide does for a `[Guessing]` mapping.

## Language default

Design for TypeScript with `strict` enabled, ES modules and a Node LTS runtime.
That is the stated preference, and strict typing is what makes the ports below checkable.
TypeScript 7.0 reports `strict` as default-on and refuses command-line file arguments when a `tsconfig.json` is present (TS5112) `[docs][probed]`, so name the TypeScript major version in the design's constraints.

Design for plain JavaScript only when the existing code is JavaScript.
Then the interface-based ports become JSDoc `@typedef` and `@param` annotations checked with `checkJs` `[docs]`, and the type checker is `tsc` with `allowJs` and `checkJs`.
A JavaScript design loses the compile-time check on a port, so its boundary checks and acceptance tests carry more of the load.
Say so under evidence limits.

## Ports and the composition root

Define a port as an `interface` or a `type` alias owned by the inner layer, and let adapters satisfy it structurally `[inferred]`.
TypeScript typing is structural, so an adapter needs no import of the domain's interface to satisfy it, which mirrors the `Protocol` rule.
Prefer a plain function type for a port with one operation, and an interface for a port with several.

Build the concrete classes in one composition root, for example `src/main.ts` or a `compose()` function called from `main.ts` and from tests `[inferred]`.
Pass collaborators as constructor or function arguments, and do not import a concrete adapter from a domain module.
A DI container is a dependency and a design decision, so add one only with a named force.

Validate data at the outer edge, where JSON, a request body or a database document enters, and pass typed values inward.
Compile-time types do not exist at run time, so an unvalidated `req.body` typed as a domain object is a boundary defect `[inferred]`.
A validation library is a new dependency and goes through the dependency decision record.

## Idiom to check first per pattern

Run step 2 of the pattern gate with this table, then use the forces and costs in `patterns.md`.
All rows are `[inferred]` unless marked.

| Pattern | Idiom to check first |
| --- | --- |
| Abstract Factory | An object of factory functions, or a `Record` keyed by variant |
| Builder | An options object with defaults, optional properties and object spread |
| Factory Method | Pass a function, or a `Map` from key to constructor function |
| Prototype | `structuredClone` or an object spread, and a class only for behaviour |
| Singleton | An ES module, which is evaluated once, and the composition root |
| Adapter | A function that maps one shape to another, or an object satisfying the port |
| Bridge | Composition of two interfaces, usually a function parameter |
| Composite | A recursive type, often a discriminated union with a recursive function |
| Decorator | A higher-order function, or Express and Koa style middleware |
| Facade | A module that re-exports a small public surface from an `index.ts` |
| Flyweight | A shared immutable object, or a `Map` cache |
| Proxy | `Proxy` only when interception is the point, otherwise a wrapper function |
| Chain of Responsibility | Express-style middleware, or an array of handler functions |
| Command | A function value or a plain object with a `type` field |
| Interpreter | A discriminated union and a recursive `switch`, with no class hierarchy |
| Iterator | `Symbol.iterator`, a generator, or an async generator |
| Mediator | A module or an event emitter at the composition root, used sparingly |
| Memento | A frozen copy of the state, as with Redux-style snapshots |
| Observer | `EventTarget`, `EventEmitter` or a plain subscriber array |
| State | A discriminated union with a transition function, with exhaustive `switch` |
| Strategy | A function parameter, or a `Record` of functions |
| Template Method | A function that takes the varying steps as arguments |
| Visitor | An exhaustive `switch` over a discriminated union |

Express middleware is the in-ecosystem form of Chain of Responsibility and Decorator.
Name it as such in the pattern table instead of adding a class hierarchy.

## Layouts for a Node and MERN system

MERN is MongoDB, Express, React and Node.
The conventional server layout is MVC, with `routes`, `controllers` and `models` folders, where a Mongoose model defines both the schema and the persistence.
This section describes MVC so that the designer recognises it and can survey it in an existing codebase.
It is background only.
The designer never proposes MVC for a new design, and it uses MVC in a design only when the user asks for it or the existing code is already MVC and the requirement extends it.
A pattern-gate candidate list therefore does not include MVC unless one of those two conditions holds.

MVC in a MERN API, with its parts in order of request flow:

- A route maps a method and path to a controller and attaches middleware for authentication and validation.
- A controller reads the request, calls a model or a service, and shapes the response.
- A model is a Mongoose schema and its queries.
- The React client plays the view, and the JSON response is the view data `[inferred]`.

When a design does extend an MVC codebase, it states these known strains as risks and does not hide them:

- The Mongoose model is both the domain and the persistence schema, so the domain imports `mongoose` and the dependency points outwards.
That breaks the dependency rule of `architecture-checks.md`, and the design must state which rule it adopts, as that file requires.
- Business rules drift into controllers, because a controller is the only place that sees both the request and the model.
- Tests need a database or a heavy mock, because no port separates the rules from Mongoose.

For a new design, choose among these layouts in the pattern gate:

1. Routes, controllers, services and repositories.
Services hold the rules and depend on a repository interface owned by the service layer.
The repository is the only module that imports Mongoose.
2. Feature folders, each with its own route, service and repository, and a shared kernel for cross-cutting code.
This suits several bounded areas in one deployable `[inferred]`.
3. A hexagonal layout with `domain`, `application` and `adapters`, for a system with a long life or several delivery channels.

Record the choice in the design's decisions section with the alternatives, as for any structural decision.
For the React client, keep components that render, hooks that hold state and an API client module that owns every HTTP call, and give the API client the same boundary rule as a repository `[inferred]`.

## Boundary checks

Record every boundary as a rule that a tool can run.
Biome import patterns are the default when Biome is the project's linter, because they run on every TypeScript version and add no dependency.
dependency-cruiser is the alternative, the TypeScript counterpart of import-linter, and it is the one that sees import cycles and whole-graph rules.

Biome 2.6.6 with `noRestrictedImports` `[probed]`:

```json
{
  "overrides": [
    {
      "includes": ["src/domain/**"],
      "linter": {
        "rules": {
          "style": {
            "noRestrictedImports": {
              "level": "error",
              "options": {
                "patterns": [{ "group": ["**/adapters/**"], "message": "domain must not import adapters" }]
              }
            }
          }
        }
      }
    }
  ]
}
```

Run on a two-layer fixture, this reported both a value import and an `import type` from the adapters module in `src/domain`, and reported nothing for the same import in `src/app`.
`biome check` exits 1 on a violation.
The rule matches the import specifier against the patterns, so a project with path aliases needs a pattern for the alias as well (for example `@/adapters/**`), and the alias case was not tested.
It checks one direction per rule, so a design with several boundaries lists one override per boundary.
It does not detect cycles.

dependency-cruiser, version 18.7.0 `[docs]`:

- The config is `.dependency-cruiser.js` or `.dependency-cruiser.json`, and `dependency-cruiser --init` creates one.
- A `forbidden` rule has `from` and `to` conditions with `path` and `pathNot` regular expressions, and a severity of `error`, `warn`, `info` or `ignore`, where `warn` is the default.
- `--validate` (alias of `--config`) runs the rules, and `--ts-config` points at the `tsconfig.json`, whose `compilerOptions` supply the `paths` aliases.
- `--ts-pre-compilation-deps` includes type-only imports, which are off by default, so a domain module that imports only a type from an adapter is invisible without it.
- The `err` output type exits with the number of violations of severity `error`, and with 0 when there are none.
The binary names `depcruise` and `dependency-cruiser` both exist `[probed]`.

A minimal rule that keeps the domain from importing adapters, constructed from the documented shape and not copied from the docs:

```js
module.exports = {
  forbidden: [
    {
      name: "domain-not-to-adapters",
      severity: "error",
      from: { path: "^src/domain" },
      to: { path: "^src/adapters" },
    },
  ],
};
```

Run it as `depcruise --config .dependency-cruiser.js --ts-config tsconfig.json --ts-pre-compilation-deps src`, with the binary taken from `node_modules/.bin`.
Check the live documentation before using an option not shown here.

Two results from running version 18.7.0 on 2026-11-07 change how the design must use it `[probed]`:

- It requires TypeScript below 7.
With TypeScript 7.0.2 installed it printed `no dependency violations found (0 modules, 0 dependencies cruised)`, exited 0 and gave only a `missing-tsc-transpiler` warning.
That is a silent pass that checks nothing, and a fresh `npm install -D typescript` installs version 7.
The design therefore uses it only when TypeScript is pinned below 7, and records that pin as a decision for the human gate.
Otherwise it uses the Biome patterns above.
A clean dependency-cruiser run that cruised 0 modules is never accepted.
- Without `--ts-pre-compilation-deps`, a type-only import (`import type`) from an adapter into the domain was not reported, even with TypeScript 6.0.3.
With the flag the same rule reported `domain-not-to-adapters` and exited 1.

State in the design's boundary checks how the run proves it bites: the module count in the output is above zero, and a fixture that violates the rule fails.

Two more options, both unverified beyond the documentation, and neither was checked against TypeScript 7:

- `eslint-plugin-boundaries` supports ESLint flat config, with `boundaries/elements` in `settings` and the `boundaries/dependencies` rule `[docs]`.
Its supported ESLint range and current version were not confirmed, and typescript-eslint under TypeScript 7 was not probed.
- Biome has no dedicated layer rule `[docs]`, but its `noRestrictedImports` patterns, scoped by an override, express "domain must not import adapters" `[probed]`, as shown above.

## TypeScript practice

- Keep `strict` on, and treat a new `any`, a non-null assertion or an `as` cast that skips a check as a design smell `[inferred]`.
- Model variants as a discriminated union and make the `switch` exhaustive, so that a new variant fails the type check.
- Use `import type` for type-only imports, and note that such imports are invisible to dependency-cruiser unless `--ts-pre-compilation-deps` is set.
- A dynamic `import()` or `require` added to avoid a cycle hides the cycle from the import graph, so a reviewer reads it as a warning sign, as for a function-local import in Python `[inferred]`.
- Keep the domain free of framework types: no Express `Request`, no Mongoose `Document` and no React type crosses into the inner layer.
- Avoid barrel files that re-export everything, because they widen the public surface and create cycles `[inferred]`.

## Reviewer checks by topic

| Topic | Checks from a diff | Checks from the design document |
| --- | --- | --- |
| Dependency direction | `mongoose`, `express` or `react` imported in the domain, a concrete adapter imported by a service | Package-to-layer assignment, the rule adopted, who owns each port |
| Boundary checks | A loosened or deleted dependency-cruiser rule, a new allow or ignore entry, a lint-disable on a boundary | A rule exists for every boundary and the rule matches the layout |
| Ports | A controller or service that builds `new Repository()` | One composition root, ports as interfaces owned by the inner layer |
| Type discipline | New `any`, `!`, `as`, `@ts-ignore` | `strict` named in the constraints |
| Validation | A request body used without validation | Where validation happens and which library, as a recorded dependency |
| Patterns | A class hierarchy where a function, union or middleware does | The idiom column was checked for every candidate |

## Evidence limits

- Nothing in this file comes from a research brief of the kind behind `patterns.md`.
The tool facts were read from the documentation or run on 2026-11-07, and the idioms, layouts and reviewer checks are the author's inference.
- The Biome boundary override was run against a five-file fixture with Biome 2.6.6, without path aliases and without a monorepo.
- dependency-cruiser 18.7.0 was read from the documentation, and the sample rule was run against a two-file fixture with TypeScript 6.0.3 and 7.0.2.
Its behaviour on a real project with path aliases or a monorepo was not tested.
- The layout comparison rests on general practice, not on a source in the repository.
- The `eslint-plugin-boundaries` rule names and version support were not confirmed.
- JSDoc-based type checking was not read, because its documentation page did not load.
