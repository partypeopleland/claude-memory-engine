# Claude Memory Backup

This repository stores memory files for Claude Code sessions, organized by project.

## Structure

```
claude-memory/
├── MEMORY.md              ← Global index template
├── project-map.json       ← Maps project names to Claude project hashes
└── projects/
    ├── my-project/        ← One folder per project
    │   ├── MEMORY.md      ← Project-specific memory index
    │   ├── user_role.md
    │   ├── feedback_*.md
    │   └── project_*.md
    └── another-project/
        └── ...
```

## How It Works

- **Backup**: Run `/memory:backup` in Claude Code → files are pushed here
- **Restore**: On a new machine, run the installer with this repo URL → memory is restored automatically
- **Manual recovery**: Run `/memory:recover` to restore a specific project

## Memory File Types

| Type | Prefix | Purpose |
|------|--------|---------|
| `user` | `user_` | Your role, preferences, knowledge |
| `feedback` | `feedback_` | Corrections and validated approaches |
| `project` | `project_` | Ongoing work, goals, incidents |
| `reference` | `reference_` | Pointers to external resources |

## project-map.json

Maps human-readable project names to Claude's internal project hashes:

```json
{
  "my-project": "D--Code-MyProject",
  "another-project": "C--Work-AnotherProject"
}
```

This file is automatically updated by the installer and `/memory:backup`.
