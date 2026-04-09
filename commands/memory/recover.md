# /memory:recover -- Restore Memory from Backup Repo

Restore memory files from your GitHub backup repo for a specific project.

## When to Use

- Switched to a new computer and need to restore a specific project's memory
- Local memory files were accidentally deleted
- The installer didn't auto-restore a project (you skipped it during install)

## Steps

1. **Read config** — Load backup repo URL from `~/.claude/memory-config.json`
2. **List available projects** — Fetch `project-map.json` from backup repo, show available projects
3. **Select project** — If user specifies a name, use it; otherwise ask which project to restore
4. **Compute local path** — Ask user for the current local path of the project (e.g., `D:\Code\MyProject`)
5. **Compute hash** — Derive the Claude project hash from that path (drive letter + `--` + path segments joined by `-`)
6. **Copy memory files** — Download files from `projects/{project-name}/` in backup repo, copy to `~/.claude/projects/{hash}/memory/`
7. **Update project-map.json** — Record the new hash mapping in backup repo
8. **Report** — "Recovered {N} memory files for project {name}"

## Notes

- This is a manual recovery command — the installer handles auto-recovery during fresh install
- You can run this multiple times for different projects
- If the project doesn't exist in backup repo, it has never been backed up
