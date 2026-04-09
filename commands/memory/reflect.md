# /memory:reflect -- Learning Loop

Review recent sessions, refine memory files, and extract patterns. Run this after accumulating several sessions (recommended: weekly or every 10+ sessions).

## Phase 1: Review + Organize

1. **Read session index** — Load `~/.claude/sessions/project-index.md`
   - If a project is specified (e.g., `/memory:reflect myproject`) — only review that project's sessions
2. **Read session summaries** — Load session files from the last 7 days (max 10)
3. **Read pitfall records** — Scan `~/.claude/skills/learned/auto-pitfall-*.md`
4. **Read memory files** — Scan all `memory/*.md` files
5. **Tag each item** — `valid` / `stale` / `duplicate` / `needs-update`

## Phase 2: Refine

6. **Merge duplicates** — Combine memory entries that cover the same topic
7. **Update stale content** — Flag outdated entries for review
8. **Move misplaced content** — Relocate entries to the correct memory file

## Phase 3: Analysis + Cleanup

9. **Analyze patterns** — Most common work types, recurring pitfalls, new preferences
10. **Propose CLAUDE.md updates** — List suggestions (don't auto-modify — wait for confirmation)
11. **Cleanup list** — Flag internalized pitfall records and merged duplicates for deletion (delayed one cycle)
12. **Save reflect report** — Write to `~/.claude/sessions/reflect-{date}.md`

## Output Format

```
=== Memory Reflect Report ({date}) ===

Sessions reviewed: {N} (last 7 days)
Memory files: {valid} valid / {stale} stale / {duplicate} duplicates

Actions taken:
- Merged: {N} duplicate entries
- Updated: {N} stale entries
- Flagged for cleanup: {N} items

Patterns found:
1. {pattern} → Suggestion: {action}

CLAUDE.md suggestions (confirm before applying):
- [ ] Add rule: {rule}

Cleanup queue (will delete next reflect cycle):
- [ ] {item}
```

## Notes

- CLAUDE.md changes are proposed, not auto-applied — user confirms first
- Cleanup is delayed one cycle: flag now, delete next time
- If no sessions exist yet, just report current memory status
