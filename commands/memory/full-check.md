# /memory:full-check -- Comprehensive Health Check

Run a thorough scan of the entire memory ecosystem. Recommended weekly or after major changes.

Includes everything from `/memory:check` plus:

## Additional Checks

### Command Layer
- List all commands/memory/*.md files
- Detect overlapping commands (similar function, different name)

### Memory File Audit
- Every file indexed in MEMORY.md? (find orphans)
- Every MEMORY.md entry has a matching file? (find broken links)
- Cross-file duplicate content detection
- Flag files over 200 lines

### Environment Config
- `~/.claude/settings.json` — hooks configured?
- `~/.claude/scripts/hooks/` — all hook scripts exist?
- `~/.claude/sessions/` — session directory exists?
- `~/.claude/skills/learned/` — learned directory exists?
- `~/.claude/memory-config.json` — backup repo configured?

### Hook Scripts Status
- Check each hook script exists and is readable
- Check `debug.log` for recent errors

## Output Format

```
=== Full Health Check ===

--- Basic ---
{same as /memory:check output}

--- Commands ---
- commands/memory/: {N} commands
- [OK] save.md, reload.md, backup.md ...

--- Memory Files ---
- memory/: {N} files, {total} lines
- [OK] {file} ({N} lines) — indexed in MEMORY.md
- [ORPHAN] {file} — not in MEMORY.md

--- Environment ---
- settings.json: OK (hooks configured)
- scripts/hooks/: {N} scripts
- memory-config.json: OK (backup repo configured)
- sessions/: OK
- skills/learned/: {N} pitfall records

Suggestions:
1. ...
```

## Notes

- List all findings but do NOT auto-modify any files
- Wait for user confirmation before making changes
