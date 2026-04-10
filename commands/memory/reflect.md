# /memory:reflect -- Learning Loop

Review recent sessions, refine memory files, and extract experiences. Run after accumulating several sessions (recommended: weekly or every 10+ sessions).

## Phase 1: Review Sessions

1. **Read session logs** — Load session files from `~/.claude/sessions/` (last 7 days, max 10 files)
   - If a project is specified (e.g., `/memory:reflect myproject`) — only review that project's sessions
2. **Read existing experiences** — Load `~/.claude/experiences/INDEX.md` to know what's already captured
3. **Identify new experiences** — From the session logs, extract events worth preserving:
   - Mistakes made and corrected
   - Surprising system behaviours
   - Useful patterns or approaches discovered
   - Things the user explicitly taught or corrected

## Phase 2: Extract Experiences

4. **For each new experience worth saving:**
   - Write a new file to `~/.claude/experiences/YYYY-MM-DD-slug.md` using the template format
   - Update `~/.claude/experiences/INDEX.md` with one-line entry under correct category
5. **Prune or merge existing experiences** — Flag duplicates, outdated entries for discussion

## Phase 3: Refine Memory

6. **Read all memory files** — Scan `memory/*.md`
7. **Tag each item** — `valid` / `stale` / `duplicate` / `needs-update`
8. **Merge duplicates** — Combine entries covering the same topic
9. **Propose instruction file updates** — List suggestions for CLAUDE.md or GEMINI.md (don't auto-modify — wait for confirmation)
10. **Save reflect report** — Write to `~/.claude/sessions/reflect-{date}.md` (shared storage)

## Output Format

```
=== Reflect Report ({date}) ===

Sessions reviewed: {N} (last 7 days)

New experiences extracted: {N}
- [title] → saved to {file}

Memory files: {valid} valid / {stale} stale / {duplicate} duplicates

Actions taken:
- Merged: {N} duplicate entries
- Updated: {N} stale entries

Instruction file suggestions (CLAUDE.md / GEMINI.md) — confirm before applying:
- [ ] Add rule: {rule}
```

## Notes

- CLAUDE.md / GEMINI.md changes are proposed, not auto-applied — user confirms first
- Experiences are permanent assets — only delete when clearly obsolete
- If no sessions exist yet, just report current memory and experience status
