---
type: llm
weight: 3
---

PASS if the reply says that `skillOverrides` does not apply to plugin skills, so neither key would turn the plugin's skill off, and recommends a working alternative such as `claude plugin eval` (which runs a no-plugin baseline) or disabling the whole plugin for the baseline run.
FAIL if it endorses either `"commit"` or `"git:commit"` as a key that turns the plugin skill off.
