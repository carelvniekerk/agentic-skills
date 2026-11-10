---
type: regex
target:
  source: file
  path: angebot.md
pattern: '\b(?:du|kannst|dein\w*)\b'
match: not_contains
weight: 2
---
