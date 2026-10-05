---
type: llm
weight: 3
---

PASS if the final response does all of the following:
(a) concludes that the model supports tool calling, and bases that on the chat template's `tools` branch and its `<tool_call>` output format;
(b) does not conclude that the model is not designed for tool use because the tags lack a `tool-use` or `function-calling` tag, and notes that tags are self-reported and incomplete;
(c) states the call format (JSON in `<tool_call></tool_call>` tags) and that the template renders tool schemas into the system prompt;
(d) marks what it could not verify from the pasted excerpt, such as parallel calls or multi-step use, as unknown or not stated, and does not assert them.
FAIL if any of (a) to (d) is missing.
