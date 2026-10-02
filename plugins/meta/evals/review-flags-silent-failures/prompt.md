---
description: Review of a skill with defects the harness hides. The current skill misdescribes allowed-tools and does not cover silently ignored keys.
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill]
tags: [create-skill, review]
---

can you review this skill before i share it with the team? i'd like it to never be able to run Bash, and it should only run when i type /release-notes myself.

```markdown
---
name: release-notes
description: Release notes helper.
disable-model-invocaton: true
allowed-tools: Read Grep
---

# Release notes

ALWAYS read references/guide.md first. The guide links to references/detail/format.md, which has the format rules.

1. Collect merged PRs since the last tag.
2. Group them by label.
3. Write RELEASE_NOTES.md.
```

references/guide.md is about 400 lines with no headings list at the top. Just give me the review, don't write any files.
