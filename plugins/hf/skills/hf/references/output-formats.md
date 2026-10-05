# Output formats

The shapes for the search table, the model profile and the dataset profile.
The sections are a maximum, not a quota: drop a section for which the evidence holds nothing, and say so in one line instead of filling it.

## Contents

- Search table
- Model profile
- Dataset profile
- Agentic comparison table

## Search table

Link each model as `https://hf.co/<repo_id>`.

```markdown
| Model | Task | Params | Downloads | Licence | Providers | Gated |
| --- | --- | --- | --- | --- | --- | --- |
```

Write "gated" in the last column and note a restricted commercial licence below the table.

## Model profile

````markdown
## Model: <repo_id>

**Link:** https://hf.co/<repo_id>

The first line states the verdict for the user's purpose and the main caveat.

### At a glance

| Field | Value |
| --- | --- |
| Parameters | ... |
| Architecture | ... |
| Task | ... |
| Licence | ... (commercial use: yes or no) |
| Languages | ... |
| Base model | ... (fine-tune of X, if any) |
| Gated | yes or no |
| Inference providers (live) | ... |
| Downloads (total) | ... |

### Chat template

Name the format, and give the exact role and special tokens as they appear in the repo's template.
Say which file you read it from.

```python
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("<repo_id>")
messages = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"},
]
text = tokenizer.apply_chat_template(
    messages, tokenize=False, add_generation_prompt=True
)
```

### Tool use

State one of: the template renders tools, tags claim it without template support, or neither.
Give the evidence (the `tools` branch, the markers it emits, the card or paper passage).
Report the call format, and whether the card or paper mentions parallel calls or multi-step use, otherwise "not stated".

Add a minimal example only when tool use is supported:

```python
tools = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get current weather for a location.",
        "parameters": {
            "type": "object",
            "properties": {"location": {"type": "string"}},
            "required": ["location"],
        },
    },
}]
inputs = tokenizer.apply_chat_template(
    messages,
    tools=tools,
    add_generation_prompt=True,
    return_dict=True,
    return_tensors="pt",
)
```

### Recommended usage

System prompt, temperature, top_p, top_k and max tokens from `generation_config.json`, the card or the paper, with the source of each.
Context length and long-context caveats.
Known failure modes.

### Benchmarks

| Benchmark | Score | Source |
| --- | --- | --- |

### Related papers

- [Title](https://arxiv.org/abs/XXXX.XXXXX)

### Anomalies and judgement calls

What looked off in the metadata, and the calls you made.
````

## Dataset profile

````markdown
## Dataset: <repo_id>

**Link:** https://hf.co/datasets/<repo_id>

The first line states whether it fits the user's purpose and the main caveat, such as the licence or the label quality.

### At a glance

| Field | Value |
| --- | --- |
| Task | ... |
| Languages | ... |
| Size | ... |
| Format | ... |
| Licence | ... |
| Libraries | ... |

### Loading

```python
from datasets import load_dataset

ds = load_dataset("<repo_id>")
print(ds)
```

### Configs, splits and schema

| Config | Split | Rows |
| --- | --- | --- |

Fields, types and an example row from `dataset_preview`, the card or the paper.

### Models trained on it

| Model | Downloads | Notes |
| --- | --- | --- |

### Baselines and evaluation

The metrics, the reference scores from the paper and what counts as good.

### Related papers

- [Title](https://arxiv.org/abs/XXXX.XXXXX)
````

## Agentic comparison table

```markdown
| Model | Params | Tool-call format | Template has `tools` | Licence | Providers |
| --- | --- | --- | --- | --- | --- |
```

List candidates that carry a tool-use tag but whose template was not checked on a separate line headed "Unverified".
