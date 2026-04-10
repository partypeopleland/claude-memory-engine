# /memory:experience -- Save or Review Experiences

Experiences are automatically extracted at the start of each new session by reviewing the previous session log. This command is for **manual** saving when you want to preserve something specific right now.

## Usage

- `/memory:experience` — Review this session so far and save anything worth preserving (AI decides)
- `/memory:experience save` — Same as above
- `/memory:experience save <description>` — Save a specific thing the user just described
- `/memory:experience list` — Show the full INDEX
- `/memory:experience show <slug>` — Load the full content of a specific experience file

## How Automatic Saving Works

At the start of every new session, if the previous session was substantial (≥5 messages or had file modifications), the session log is automatically injected and you are instructed to review it and save valuable experiences — **without the user needing to ask**.

## Manual Save Steps

1. **Determine if it's worth saving** — Ask: "Would this help future sessions avoid a mistake or handle this better?" If yes, proceed.

2. **Write the experience file**
   - Filename: `~/.claude/experiences/YYYY-MM-DD-short-slug.md`
   - Use the template at `~/.claude/experiences/_template.md`

3. **Update INDEX.md** — Add one line to `~/.claude/experiences/INDEX.md`:
   ```
   - [YYYY-MM-DD] **[Title]** — `filename.md` — one-line summary (category: X)
   ```
   Add under the correct category. Create the category section if needed.

4. **Report** — "Saved: [title] → [filename]"

## Experience File Format

```markdown
---
date: YYYY-MM-DD
project: project-name
agent: Claude Code / Gemini CLI
category: debugging / git / architecture / tooling / api / ...
tags: [tag1, tag2]
---

# [Title]

## Context
...

## What Happened
...

## Root Cause
...

## Lesson
...

## How to Apply
...
```

## INDEX.md Format

```markdown
# Experience Index

## debugging
- [2026-04-09] **Silent API 200 but empty body** — `exp-20260409-api-empty.md` — POST returned 200 with no data; root cause was missing Content-Type header

## git
- [2026-04-10] **Rebase conflict overwrote teammate's work** — `exp-20260410-rebase.md` — always fetch before rebase on shared branches
```

## Notes

- Do NOT save trivial or obvious things
- One experience per distinct event — don't bundle multiple lessons into one file
- Keep INDEX entries under 120 characters
- Experiences are permanent assets — pruning happens during `/memory:reflect`
