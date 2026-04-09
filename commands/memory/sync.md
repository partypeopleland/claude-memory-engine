# /memory:sync -- Sync Memory to Remote

Push local memory changes to your remote backup, or pull the latest from remote.

## Push (default)

1. Read backup repo path from `~/.claude/memory-config.json`
2. Run push: use `gh api` to update changed files in backup repo
3. Report: what changes were pushed, to which repository

## Pull

If the user says `/memory:sync pull`:

1. Clone or pull the backup repo to `~/.claude/memory-backup/`
2. Copy memory files for the current project to local memory dir
3. If there are conflicts, show them and ask the user how to resolve
4. Report: what was pulled, any conflicts found

## Notes

- The SessionEnd hook auto-commits locally after every conversation
- Push = one-way upload to GitHub; sync pull = download from GitHub
- Run `/memory:backup` for a quick push-only operation
