#!/usr/bin/env bash
# Auto-commit memory files to backup repo (called by session-end.js)
# Only commits locally — does NOT push (push is manual via /memory:backup)

set -e

AGENT_DIR="${MEMORY_ENGINE_HOME:-$HOME/.claude}"
CONFIG_FILE="$AGENT_DIR/memory-config.json"
BACKUP_LOCAL="$AGENT_DIR/memory-backup"
PROJECTS_DIR="$AGENT_DIR/projects"

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0  # Not configured — skip silently
fi

BACKUP_REPO=$(node -e "const d=require('$CONFIG_FILE'); console.log(d.backupRepo||'')" 2>/dev/null)
if [[ -z "$BACKUP_REPO" ]]; then
  exit 0
fi

# Check backup repo is cloned
if [[ ! -d "$BACKUP_LOCAL/.git" ]]; then
  exit 0  # Not set up yet — skip silently
fi

# Sync global experiences (cross-project, stored in backup root)
EXPERIENCES_DIR="$AGENT_DIR/experiences"
if [[ -d "$EXPERIENCES_DIR" ]]; then
  mkdir -p "$BACKUP_LOCAL/experiences"
  cp -r "$EXPERIENCES_DIR/." "$BACKUP_LOCAL/experiences/"
fi

# Find all project memory directories and sync them
if [[ -d "$PROJECTS_DIR" ]]; then
  for project_dir in "$PROJECTS_DIR"/*/; do
    memory_dir="${project_dir}memory"
    if [[ ! -d "$memory_dir" ]]; then
      continue
    fi

    # Derive project name from directory hash
    # Hash format: DRIVE--path-segments (e.g., D--Code-MyProject)
    hash=$(basename "$project_dir")
    # Try to find a project-map entry, otherwise use hash as name
    project_name=$(node -e "
      const fs = require('fs');
      const mapFile = '${BACKUP_LOCAL}/project-map.json';
      if (!fs.existsSync(mapFile)) { console.log('$hash'); process.exit(0); }
      const map = JSON.parse(fs.readFileSync(mapFile, 'utf-8'));
      const entry = Object.entries(map).find(([name, h]) => h === '$hash');
      console.log(entry ? entry[0] : '$hash');
    " 2>/dev/null || echo "$hash")

    dest_dir="$BACKUP_LOCAL/projects/$project_name"
    mkdir -p "$dest_dir"

    # Copy memory files
    cp -r "$memory_dir/." "$dest_dir/"
  done
fi

# Commit if there are changes
cd "$BACKUP_LOCAL"
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "auto: memory sync $(date +%Y-%m-%d)" --quiet
fi

exit 0
