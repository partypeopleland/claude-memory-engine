# /memory:save -- Save Memory Across Sessions

Store information so the next session's Claude knows about it.

## Steps

1. **Dedup check** — Search existing memory files (`memory/*.md`) for related content. If found, update that section instead of creating a new entry
2. **Route to the right file** — Determine which memory file this belongs to based on topic:
   - `user_*.md` — user role, preferences, knowledge
   - `feedback_*.md` — corrections or confirmed approaches
   - `project_*.md` — ongoing work, goals, incidents
   - `reference_*.md` — pointers to external resources
3. **Skip if already in the agent instruction file** — CLAUDE.md (Claude Code) or GEMINI.md (Gemini CLI) is auto-loaded every session; don't duplicate its content
4. **Never write directly to MEMORY.md** — MEMORY.md is an index of pointers, not a content store
5. **Report** — Tell the user: "Saved to {filename}, section {section name}" or "Updated {filename}, changed {what}"

## Memory File Format

```markdown
---
name: {memory name}
description: {one-line description}
type: {user | feedback | project | reference}
---

{memory content}
```

## Notes

- User says "remember this" or "save this" → just save it, don't question it
- Always check for duplicates before creating new entries
- After saving, add a pointer to MEMORY.md if it's a new file
