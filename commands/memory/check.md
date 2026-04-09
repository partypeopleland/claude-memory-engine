# /memory:check -- Quick Health Check

Run a quick scan of the memory system's health. For daily use.

## Usage

- `/memory:check` — Scan everything (default)
- `/memory:check memory` — Only check memory files
- `/memory:check hooks` — Only check hook scripts

## What It Checks

### 1. Memory File Structure
- Does each memory file exist and is it readable?
- Are MEMORY.md index entries pointing to real files?

### 2. MEMORY.md Capacity
- Line count vs. 200-line system limit
- Below 170 = safe, 170–200 = warning, above 200 = danger (content truncated)

### 3. Orphan Check
- Memory files not indexed by MEMORY.md
- MEMORY.md entries pointing to non-existent files

### 4. Environment Status
- CLAUDE.md: exists and readable?
- MEMORY.md: line count and capacity
- commands/memory/: how many commands
- skills/learned/: how many pitfall records

## Output Format

```
=== Quick Health Check ===

Environment:
- CLAUDE.md: OK ({N} lines)
- MEMORY.md: OK/WARNING ({N}/200 lines)
- commands/memory/: {N} commands
- skills/learned/: {N} pitfall records

Index:
- [OK] All MEMORY.md entries point to existing files
- [BROKEN] {entry} → non-existent {file}

Suggestions:
1. ...
```

## Notes

- List suggestions but do NOT auto-modify any files
- Wait for user confirmation before making changes
