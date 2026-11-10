---
type: regex
target:
  source: file
  path: scope.md
pattern: '\b(?:might|could|often|usually|generally|typically|potentially|where possible)\b'
match: not_contains
flags: i
weight: 2
---
