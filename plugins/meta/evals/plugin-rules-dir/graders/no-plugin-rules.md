---
type: llm
weight: 3
---

PASS if the reply says that a plugin has no rules component (the manifest and standard layout do not list `rules/`, so it should not be relied on), and names at least one working alternative: a skill, or a `SessionStart` hook returning `additionalContext` (with a tool-call hook as an approximation of path-scoped rules), or a plugin `settings.json` `agent` setting. It must not say that a `rules/` folder in a plugin loads like a project `.claude/rules/`.
FAIL if it says the plugin's `rules/` directory is loaded or injected when the plugin is enabled.
