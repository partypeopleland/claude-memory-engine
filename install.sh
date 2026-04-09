#!/usr/bin/env bash
# Claude Memory Engine — Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<you>/claude-memory-engine/main/install.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
CLAUDE_DIR="$HOME/.claude"
SCRIPTS_DIR="$CLAUDE_DIR/scripts/hooks"
HOOKS_DIR="$CLAUDE_DIR/hooks"
COMMANDS_DIR="$CLAUDE_DIR/commands/memory"
CONFIG_FILE="$CLAUDE_DIR/memory-config.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ──────────────────────────────────────────────
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${YELLOW}━━ $1 ━━${NC}"; }

# ──────────────────────────────────────────────
# Node.js prerequisite check
section "Checking prerequisites"

if ! command -v node &>/dev/null; then
  error "Node.js is required but not found. Install it from https://nodejs.org/ and re-run this installer."
fi

NODE_VER=$(node --version)
info "Node.js found: $NODE_VER"

# ──────────────────────────────────────────────
# Backup repo is required
section "Backup Repository"

echo "Claude Memory Engine stores your memory in a private GitHub repository."
echo "Please create a private repo on GitHub (can be empty) and paste its URL below."
echo ""
read -rp "Backup repo URL (e.g. https://github.com/you/claude-memory): " BACKUP_REPO_URL

if [[ -z "$BACKUP_REPO_URL" ]]; then
  error "Backup repo URL is required. Installer aborted."
fi

# Validate it looks like a GitHub URL
if [[ ! "$BACKUP_REPO_URL" =~ ^https://github\.com/ ]]; then
  warn "URL doesn't look like a GitHub HTTPS URL. Continuing anyway..."
fi

# ──────────────────────────────────────────────
# Create directories
section "Creating directories"

mkdir -p "$SCRIPTS_DIR" "$HOOKS_DIR" "$COMMANDS_DIR"
info "Created: $SCRIPTS_DIR"
info "Created: $HOOKS_DIR"
info "Created: $COMMANDS_DIR"

# ──────────────────────────────────────────────
# Download hook scripts
section "Installing hook scripts"

HOOK_SCRIPTS=(
  "session-start.js"
  "session-end.js"
  "memory-sync.js"
  "mid-session-checkpoint.js"
  "pre-push-check.js"
  "write-guard.js"
)

for script in "${HOOK_SCRIPTS[@]}"; do
  curl -fsSL "$REPO_URL/scripts/hooks/$script" -o "$SCRIPTS_DIR/$script"
  info "Installed: scripts/hooks/$script"
done

UTIL_HOOKS=("log-skill-ai.js" "log-skill-user.js")
for script in "${UTIL_HOOKS[@]}"; do
  curl -fsSL "$REPO_URL/hooks/$script" -o "$HOOKS_DIR/$script"
  info "Installed: hooks/$script"
done

# ──────────────────────────────────────────────
# Download slash commands
section "Installing slash commands"

COMMANDS=(
  "save" "reload" "backup" "sync" "recover"
  "reflect" "diary" "learn" "check" "full-check"
  "compact-guide" "health" "search" "tasks"
)

for cmd in "${COMMANDS[@]}"; do
  curl -fsSL "$REPO_URL/commands/memory/$cmd.md" -o "$COMMANDS_DIR/$cmd.md"
  info "Installed: commands/memory/$cmd.md"
done

# ──────────────────────────────────────────────
# Merge settings.json (idempotent — dedup by command string)
section "Configuring hooks in settings.json"

HOOKS_JSON='{
  "SessionStart": [{"type":"command","command":"node ~/.claude/scripts/hooks/session-start.js"}],
  "SessionEnd":   [{"type":"command","command":"node ~/.claude/scripts/hooks/session-end.js"}],
  "UserPromptSubmit": [
    {"type":"command","command":"node ~/.claude/scripts/hooks/memory-sync.js"},
    {"type":"command","command":"node ~/.claude/scripts/hooks/mid-session-checkpoint.js"},
    {"type":"command","command":"node ~/.claude/hooks/log-skill-user.js"}
  ],
  "PreToolUse": [
    {"matcher":"Bash",  "type":"command","command":"node ~/.claude/scripts/hooks/pre-push-check.js"},
    {"matcher":"Write", "type":"command","command":"node ~/.claude/scripts/hooks/write-guard.js"},
    {"matcher":"Skill", "type":"command","command":"node ~/.claude/hooks/log-skill-ai.js"}
  ]
}'

node - <<EOF
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
const newHooks = $HOOKS_JSON;

let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) {}
}
if (!settings.hooks) settings.hooks = {};

for (const [event, entries] of Object.entries(newHooks)) {
  if (!settings.hooks[event]) settings.hooks[event] = [];
  const existing = settings.hooks[event];

  // Merge: deduplicate by command string
  if (Array.isArray(entries)) {
    for (const entry of entries) {
      const isDup = existing.some(e => e.command === entry.command);
      if (!isDup) {
        // Wrap in hooks array if needed (SessionStart/End format)
        if (event === 'SessionStart' || event === 'SessionEnd' || event === 'UserPromptSubmit') {
          const matcherGroup = existing.find(g => g.matcher === '*' || !g.matcher);
          if (matcherGroup && matcherGroup.hooks) {
            const isDupInner = matcherGroup.hooks.some(h => h.command === entry.command);
            if (!isDupInner) matcherGroup.hooks.push(entry);
          } else {
            existing.push({ matcher: '*', hooks: [entry] });
          }
        } else {
          existing.push(entry);
        }
      }
    }
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('settings.json updated');
EOF

info "Hooks merged into settings.json"

# ──────────────────────────────────────────────
# Save config
section "Saving configuration"

echo "{\"backupRepo\": \"$BACKUP_REPO_URL\"}" > "$CONFIG_FILE"
info "Saved: ~/.claude/memory-config.json"

# ──────────────────────────────────────────────
# Handle backup repo (empty → push template, existing → restore memory)
section "Setting up backup repository"

BACKUP_LOCAL="$CLAUDE_DIR/memory-backup"

if [[ -d "$BACKUP_LOCAL/.git" ]]; then
  warn "Backup repo already cloned at $BACKUP_LOCAL — pulling latest..."
  git -C "$BACKUP_LOCAL" pull --quiet
else
  git clone "$BACKUP_REPO_URL" "$BACKUP_LOCAL" --quiet
  info "Cloned backup repo to $BACKUP_LOCAL"
fi

# Check if repo is empty
BACKUP_FILES=$(git -C "$BACKUP_LOCAL" ls-files | wc -l | tr -d ' ')

if [[ "$BACKUP_FILES" -eq 0 ]]; then
  # Empty repo → push template
  info "Backup repo is empty — initializing with template..."

  mkdir -p "$BACKUP_LOCAL/projects"
  curl -fsSL "$REPO_URL/template/MEMORY.md" -o "$BACKUP_LOCAL/MEMORY.md" 2>/dev/null || cat > "$BACKUP_LOCAL/MEMORY.md" << 'TMPL'
# Memory Index

<!-- Add memory file pointers here -->
<!-- Format: - [Title](file.md) — one-line description -->
TMPL

  echo '{}' > "$BACKUP_LOCAL/project-map.json"

  git -C "$BACKUP_LOCAL" add -A
  git -C "$BACKUP_LOCAL" commit -m "chore: initialize memory template" --quiet
  git -C "$BACKUP_LOCAL" push --quiet
  info "Template pushed to backup repo"

else
  # Existing repo → interactive restore
  info "Backup repo has existing memory. Starting restore..."

  if [[ -f "$BACKUP_LOCAL/project-map.json" ]]; then
    PROJECTS=$(node -e "
      const d = require('$BACKUP_LOCAL/project-map.json');
      Object.keys(d).forEach(k => console.log(k));
    " 2>/dev/null)

    if [[ -n "$PROJECTS" ]]; then
      echo ""
      echo "Found these projects in backup:"
      echo "$PROJECTS"
      echo ""
      echo "For each project, enter its current local path (or press Enter to skip)."
      echo ""

      while IFS= read -r project; do
        read -rp "  Path for '$project' (e.g. /d/Code/MyProject, or Enter to skip): " PROJECT_PATH

        if [[ -z "$PROJECT_PATH" ]]; then
          warn "Skipped '$project' — run /memory:recover later to restore it"
          continue
        fi

        # Compute hash from path (drive + -- + rest joined by -)
        HASH=$(node -e "
          const p = '$PROJECT_PATH'.replace(/\\\\/g, '/');
          const parts = p.split('/').filter(Boolean);
          const drive = parts[0].replace(':', '');
          const rest = parts.slice(1).join('-');
          console.log(drive + '--' + rest);
        ")

        MEM_DIR="$CLAUDE_DIR/projects/$HASH/memory"
        SRC_DIR="$BACKUP_LOCAL/projects/$project"

        if [[ -d "$SRC_DIR" ]]; then
          mkdir -p "$MEM_DIR"
          cp -r "$SRC_DIR/." "$MEM_DIR/"
          info "Restored '$project' → $MEM_DIR"
        else
          warn "No memory found for '$project' in backup repo"
        fi
      done <<< "$PROJECTS"
    fi
  fi
fi

# ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Memory Engine installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Available commands (use in Claude Code):"
echo "  /memory:save       Save information to memory"
echo "  /memory:reload     Load memory into context"
echo "  /memory:backup     Push memory to GitHub"
echo "  /memory:reflect    Review and refine memories"
echo "  /memory:check      Quick health check"
echo "  /memory:recover    Restore a project's memory"
echo ""
echo "Restart Claude Code to activate hooks."
echo ""
