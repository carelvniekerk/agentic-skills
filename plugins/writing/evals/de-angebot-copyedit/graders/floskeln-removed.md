---
type: regex
target:
  source: file
  path: angebot.md
pattern: 'in der heutigen zeit|integraler bestandteil|es ist wichtig zu beachten|herzstück|sinn macht|wie bereits erwähnt|würden empfehlen'
match: not_contains
flags: i
weight: 2
---
