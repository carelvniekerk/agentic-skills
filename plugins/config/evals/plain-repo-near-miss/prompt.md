---
description: Near miss. A plain repository with none of the dotset files and a one-line .gitignore request should not load the dotset skill.
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
tags: [dotset, negative]
---

Add `.venv/` and `.DS_Store` to the .gitignore in this repo. Here is what's in it:

```text
$ ls -a
.  ..  .git  .gitignore  package.json  src  README.md

$ cat .gitignore
node_modules/
dist/
```
