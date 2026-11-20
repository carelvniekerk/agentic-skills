# Ticket template

The structure of the file that `ticket` writes and `implement:architecture-design` reads in its Phase 0.
Fill in every section.
A section with nothing to say gets one sentence saying so, because the design skill reads an empty section as a gap.
Keep each sentence on its own line in the source.

## Contents

- Frontmatter
- Sections
- What the design skill reads

## Frontmatter

```yaml
---
title: <short name of what is wanted>
slug: <lower-case words joined by hyphens, equal to the file name without .md>
status: draft
date: YYYY-MM-DD
author: <value of git config user.name>
---
```

`status` is `draft` or `ready`.
`ready` means the design can start.
The `date` field is always YYYY-MM-DD, whatever the language of the ticket.

## Sections

1. Problem.
What is wrong or missing, who has the problem, how it is handled today and why that does not work.
Two to five sentences.
2. Desired behaviour.
What a user or caller sees when it works, in their terms, as short statements.
No criterion IDs, no test levels, no module or class names.
3. Constraints.
Language and runtime, dependencies already in use, deployment, data protection (DSGVO) where personal data is involved, and what must not change.
Add a solution the user asked for here, marked as their stated preference.
4. Out of scope.
What the ticket deliberately leaves out.
5. Open questions.
Each one as a question, with who can answer it if that is known, and a note when it blocks the design.
Include the build-or-buy question, with what was checked.
6. Attachments.
One line per file: path relative to the ticket, what it shows and which part matters.
Say when a file lies outside the repository or when an image was pasted in chat and not stored.

## What the design skill reads

| Ticket section | Phase 0 question it answers |
| --- | --- |
| Problem, Desired behaviour | What must the system do, in observable behaviour |
| Constraints | The constraints, including language and data protection |
| Out of scope | What is out of scope |
| Open questions | Asked again, and a blocking one stops the design until answered |
| Attachments | Read as part of the requirement |

The design skill also needs to know whether there is an existing codebase and which part it touches, and the ticket may leave that to the repository.
Acceptance criteria are never in the ticket, and the design writes them.
