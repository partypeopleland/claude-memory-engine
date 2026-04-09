# Claude Memory Engine

A portable memory system for [Claude Code](https://claude.ai/code). Install once, and Claude remembers your preferences, feedback, and project context across sessions — even on new machines.

## What It Does

- **Persists memory across sessions** — Claude reads your preferences, past feedback, and project context at session start
- **Backs up to GitHub** — your memory syncs to a private repo you own
- **Restores on new machines** — install with one command, memory comes back automatically
- **14 slash commands** — manage memory directly from Claude Code

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Node.js](https://nodejs.org/) v18+
- [git](https://git-scm.com/) installed
- A private GitHub repository for your memory backup (can be empty)

## Installation

### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install.ps1 | iex
```

The installer will:
1. Check that Node.js is installed
2. Ask for your private backup repo URL (required)
3. Install hook scripts and slash commands to `~/.claude/`
4. Configure hooks in `~/.claude/settings.json` (existing settings are preserved)
5. If the backup repo is empty → push an initial template
6. If the backup repo has memory → restore it to your machine

After installation, **restart Claude Code** to activate the hooks.

## Slash Commands

All commands use the `/memory:` prefix. Type them in Claude Code.

| Command | Description |
|---------|-------------|
| `/memory:save` | Save information to memory (user preferences, feedback, project context, references) |
| `/memory:reload` | Load all memory files into the current conversation context |
| `/memory:backup` | Push memory files to your GitHub backup repo |
| `/memory:sync` | Push or pull memory to/from GitHub |
| `/memory:recover` | Restore a specific project's memory from backup (for new machine setup) |
| `/memory:reflect` | Review recent sessions, refine memory, extract patterns (run weekly) |
| `/memory:diary` | Write a reflection diary entry from the current conversation |
| `/memory:learn` | Save a pitfall or lesson learned manually |
| `/memory:check` | Quick health check of memory files and hooks |
| `/memory:full-check` | Comprehensive audit of the entire memory system |
| `/memory:health` | Status report: memory capacity, session count, hook status |
| `/memory:search` | Search across all memory files by keyword |
| `/memory:compact-guide` | Advice on when to use `/compact` to compress conversation context |
| `/memory:tasks` | View and manage cross-project task list |

## Memory Types

Memory files are categorized into four types:

| Type | Filename prefix | Purpose |
|------|----------------|---------|
| `user` | `user_*.md` | Your role, expertise, preferences |
| `feedback` | `feedback_*.md` | Things Claude should or shouldn't do |
| `project` | `project_*.md` | Current work, goals, incidents |
| `reference` | `reference_*.md` | Links to external resources |

## How Memory Is Stored

```
~/.claude/
├── settings.json               ← hooks configured here
├── scripts/hooks/              ← hook scripts (JS)
│   ├── session-start.js        ← loads context at session start
│   ├── session-end.js          ← saves summary + detects pitfalls
│   ├── memory-sync.js          ← detects memory changes between prompts
│   ├── mid-session-checkpoint.js
│   ├── pre-push-check.js
│   ├── write-guard.js
│   └── memory-backup.sh        ← auto-commits memory after session
├── hooks/
│   ├── log-skill-ai.js
│   └── log-skill-user.js
├── commands/memory/            ← slash commands (14 files)
├── memory-config.json          ← backup repo URL
└── projects/
    └── <project-hash>/
        └── memory/             ← per-project memory files
            ├── MEMORY.md       ← index (loaded every session)
            └── *.md            ← typed memory files
```

## Backup Repository

Your memory is backed up to a private GitHub repo you own. Structure:

```
your-claude-memory/
├── MEMORY.md
├── project-map.json            ← maps project names to local hashes
└── projects/
    └── <project-name>/
        ├── MEMORY.md
        └── *.md
```

The `project-map.json` maps human-readable project names to Claude's internal hashes, enabling memory to survive across machines even when the project path changes.

## Troubleshooting

**Hooks not running after install?**
Restart Claude Code. Hooks require a fresh session to activate.

**`node: command not found` during install?**
Install Node.js from https://nodejs.org/ then re-run the installer.

**Memory not loading at session start?**
Run `/memory:check` to diagnose. Check `~/.claude/sessions/debug.log` for session-end errors.

**Restoring memory on a new machine?**
Run the installer with your backup repo URL. For projects that weren't auto-restored, run `/memory:recover`.

## Uninstall

Remove the installed files:

```bash
rm -rf ~/.claude/scripts/hooks/
rm -rf ~/.claude/hooks/log-skill-ai.js ~/.claude/hooks/log-skill-user.js
rm -rf ~/.claude/commands/memory/
rm ~/.claude/memory-config.json
```

Then remove the hooks section from `~/.claude/settings.json` manually. Your memory files in `~/.claude/projects/` are not affected.
