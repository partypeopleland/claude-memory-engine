# /memory:backup -- Push Memory to GitHub

Sync local memory files to your GitHub backup repository.

## Steps

1. **Read config** — Load backup repo URL from `~/.claude/memory-config.json`
2. **Scan local memory** — Read all `.md` files in `~/.claude/projects/{current-project}/memory/`
3. **Determine project name** — Use the last directory segment of CWD as the project name
4. **Push to backup repo** — Use `gh api` PUT to update changed files under `projects/{project-name}/` in the backup repo:
   a. Fetch the latest SHA for each file first (required by GitHub API)
   b. Only push files that have changed (compare content)
   c. Also update `project-map.json` with the current project hash
5. **Verify** — Confirm push succeeded, list which files were updated
6. **Report** — Brief summary of backup results

## Notes

- Always fetch the latest SHA before updating to avoid conflicts
- Handle non-ASCII filenames with URL encoding
- If GitHub API returns an error, report it — don't retry more than 3 times
- If `~/.claude/memory-config.json` is missing, prompt user to run the installer
