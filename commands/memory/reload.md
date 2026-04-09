# /memory:reload -- Load Memory into Context

Fully load memory files into the current conversation context.

SessionStart hooks inject a brief summary automatically, but `/memory:reload` does the **full read** — loading actual file contents so Claude can reference specific details.

## Steps

1. **Read MEMORY.md** — Scan all index entries
2. **Read all linked memory files** — Load each `memory/*.md` file listed in the index
3. **Read recent changes** — Note files updated in the last 24 hours
4. **Report** — "Loaded. {N} index entries, recently changed: {summary}"

## Targeted Reload

If the user specifies a topic:
- Only load the file(s) related to that topic
- Example: `/memory:reload feedback` → only load `feedback_*.md` files

## Notes

- This is a **read** operation — it doesn't modify any files
- Use when switching to a topic that needs detailed context
- Useful after long conversations where early context was compressed
