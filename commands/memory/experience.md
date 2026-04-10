# /memory:experience -- Save or Review Experiences

Save a meaningful experience from this session, or review past experiences.

## Usage

- `/memory:experience save` — Save a new experience from this session
- `/memory:experience list` — Show the INDEX (same as what loads at session start)
- `/memory:experience show <slug>` — Load the full content of a specific experience file
- `/memory:experience edit <slug>` — Open and update an existing experience

## Saving a New Experience

### Steps

1. **Determine if it's worth saving** — Ask: "Would this help future sessions avoid a mistake or handle a situation better?" If yes, proceed.

2. **Write the experience file**
   - Filename: `~/.claude/experiences/YYYY-MM-DD-short-slug.md`
   - Copy the template from `~/.claude/experiences/_template.md` (or use the format below)
   - Fill in all sections: Context, What Happened, Root Cause, Lesson, How to Apply

3. **Update INDEX.md** — Add one line to `~/.claude/experiences/INDEX.md`:
   ```
   - [YYYY-MM-DD] **[Title]** — `filename.md` — one-line summary (category: X)
   ```
   Add it under the correct category section. Create the section if it doesn't exist.

4. **Report** — Tell the user: "Saved experience: [title] → [filename]"

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

## architecture
- ...
```

## Notes

- Do NOT save trivial or obvious things
- One experience per distinct event — don't bundle multiple lessons into one file
- When in doubt whether to save: save it. It can always be pruned during `/memory:reflect`
- The INDEX is loaded at every session start — keep each line under 120 characters
