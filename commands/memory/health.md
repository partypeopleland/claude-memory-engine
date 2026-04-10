# /memory:health -- Memory Health Status

Quick status report of the memory system's key metrics.

## Steps

1. **Scan memory directory** — `~/.claude/projects/{project-id}/memory/` (shared by both Claude and Gemini)
2. **Scan sessions directory** — `~/.claude/sessions/`
3. **Scan learned directory** — `~/.claude/skills/learned/`
4. **Check debug log** — `~/.claude/sessions/debug.log` (last 5 lines)
5. **Check config** — `~/.claude/memory-config.json` (backup repo configured?)
6. **Check Gemini hooks** — `~/.gemini/settings.json` (if using Gemini CLI)

## Output Format

```
Memory Health Report

MEMORY.md: {lines}/200 lines ({Safe/Warning/Critical})

Memory files:
| File | Lines | Last Updated | Status |
|------|-------|-------------|--------|
| {filename} | {N} | {date} | OK/Stale/Too Large |

Sessions: {N} total, latest: {date}
Pitfall records: {N} total, latest: {date}

Backup config: {configured/not configured}

Hook scripts:
- session-start.js: OK
- session-end.js: OK (last debug: {msg})
- memory-sync.js: OK
```

## Thresholds

- MEMORY.md < 170 lines → Safe
- MEMORY.md 170–200 lines → Warning (move content to topic files)
- MEMORY.md > 200 lines → Critical (content beyond line 200 is truncated)
- Memory file not updated for 30+ days → Stale
- Memory file over 200 lines → Too Large
