---
description: Model whose tags carry no tool-use signal but whose chat template renders tools. The skill should say tool use is supported and cite the template, not call the model unsuited because of the tags.
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
tags: [hf, tool-use, hard]
---

Does Qwen/Qwen3-8B on Hugging Face support tool calling? You can't reach the Hub from here, so I'm pasting what I could copy. Tell me what you conclude and how sure you are.

```text
Tags: transformers, safetensors, qwen3, text-generation, conversational, arxiv:2309.00071, arxiv:2505.09388, base_model:Qwen/Qwen3-8B-Base, license:apache-2.0, text-generation-inference, endpoints_compatible

chat_template (excerpt from tokenizer_config.json):
{%- if tools %}
    {{- '<|im_start|>system\n' }}
    ...
    {{- "# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>" }}
    {%- for tool in tools %}{{- "\n" }}{{- tool | tojson }}{%- endfor %}
    {{- "\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call><|im_end|>\n" }}
```
