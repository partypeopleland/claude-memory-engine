#!/usr/bin/env bash
# Claude Memory Engine — Gemini CLI Installer
#
# Works in two modes (auto-detected):
#   SHARED mode  — Claude Code is already installed → reuse ~/.claude/ scripts & storage
#   STANDALONE mode — No Claude Code → install scripts to ~/.gemini/, data in ~/.gemini/
#
# Usage: curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
GEMINI_DIR="$HOME/.gemini"
CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$GEMINI_DIR/commands/memory"
SETTINGS_FILE="$GEMINI_DIR/settings.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${YELLOW}━━ $1 ━━${NC}"; }

# ──────────────────────────────────────────────
section "Checking prerequisites"

if ! command -v node &>/dev/null; then
  error "Node.js is required but not found. Install from https://nodejs.org/ and re-run."
fi
info "Node.js found: $(node --version)"

# ──────────────────────────────────────────────
# Auto-detect mode
if [[ -f "$CLAUDE_DIR/scripts/hooks/session-start.js" ]]; then
  MODE="shared"
  SCRIPTS_DIR="$CLAUDE_DIR/scripts/hooks"
  MEMORY_HOME="$CLAUDE_DIR"
  info "Claude Code detected → SHARED mode (scripts: ~/.claude/, storage: ~/.claude/)"
else
  MODE="standalone"
  SCRIPTS_DIR="$GEMINI_DIR/scripts/hooks"
  MEMORY_HOME="$GEMINI_DIR"
  info "No Claude Code found → STANDALONE mode (scripts: ~/.gemini/, storage: ~/.gemini/)"
fi

EXPERIENCES_DIR="$MEMORY_HOME/experiences"

# ──────────────────────────────────────────────
section "Creating directories"

mkdir -p "$COMMANDS_DIR" "$GEMINI_DIR" "$EXPERIENCES_DIR"
info "Created: $COMMANDS_DIR"
info "Created: $EXPERIENCES_DIR"

# ──────────────────────────────────────────────
# In standalone mode: download all hook scripts to ~/.gemini/scripts/hooks/
# In shared mode: scripts already exist in ~/.claude/scripts/hooks/
if [[ "$MODE" == "standalone" ]]; then
  section "Installing hook scripts to ~/.gemini/scripts/hooks/"
  mkdir -p "$SCRIPTS_DIR"

  HOOK_SCRIPTS=(
    "session-start.js" "session-end.js" "memory-sync.js"
    "mid-session-checkpoint.js" "pre-push-check.js" "write-guard.js"
    "post-tool-logger.js"
  )
  for script in "${HOOK_SCRIPTS[@]}"; do
    curl -fsSL "$REPO_URL/scripts/hooks/$script" -o "$SCRIPTS_DIR/$script"
    info "Installed: $script"
  done

  # Write .memory-home so scripts know where the data lives
  echo "$MEMORY_HOME" > "$SCRIPTS_DIR/.memory-home"
  info "Configured data directory: $MEMORY_HOME"

  # Ask for backup repo
  section "Backup Repository"
  echo "Please create a private GitHub repo for memory backup (can be empty)."
  echo ""
  read -rp "Backup repo URL (e.g. https://github.com/you/my-memory): " BACKUP_REPO_URL

  if [[ -z "$BACKUP_REPO_URL" ]]; then
    warn "No backup repo provided — skipping backup setup. Run /memory:backup later."
  else
    echo "{\"backupRepo\": \"$BACKUP_REPO_URL\"}" > "$MEMORY_HOME/memory-config.json"
    info "Saved: memory-config.json"

    BACKUP_LOCAL="$MEMORY_HOME/memory-backup"
    if [[ -d "$BACKUP_LOCAL/.git" ]]; then
      warn "Backup repo already cloned — pulling latest..."
      git -C "$BACKUP_LOCAL" pull --quiet
    else
      git clone "$BACKUP_REPO_URL" "$BACKUP_LOCAL" --quiet
      info "Cloned backup repo to $BACKUP_LOCAL"
    fi

    BACKUP_FILES=$(git -C "$BACKUP_LOCAL" ls-files | wc -l | tr -d ' ')
    if [[ "$BACKUP_FILES" -eq 0 ]]; then
      mkdir -p "$BACKUP_LOCAL/projects" "$BACKUP_LOCAL/experiences"
      cat > "$BACKUP_LOCAL/MEMORY.md" << 'TMPL'
# Memory Index

<!-- Format: - [Title](file.md) — one-line description -->
TMPL
      echo '{}' > "$BACKUP_LOCAL/project-map.json"
      git -C "$BACKUP_LOCAL" add -A
      git -C "$BACKUP_LOCAL" commit -m "chore: initialize memory template" --quiet
      git -C "$BACKUP_LOCAL" push --quiet
      info "Template pushed to backup repo"
    else
      info "Backup repo has existing memory — it will be available via /memory:reload"
    fi
  fi
else
  section "Skipping script installation (shared mode — using ~/.claude/scripts/hooks/)"
fi

# ──────────────────────────────────────────────
section "Installing slash commands to ~/.gemini/commands/memory/"

COMMANDS=(
  "save" "reload" "backup" "sync" "recover"
  "reflect" "diary" "learn" "check" "full-check"
  "compact-guide" "health" "search" "tasks" "experience"
)
for cmd in "${COMMANDS[@]}"; do
  curl -fsSL "$REPO_URL/commands/memory/$cmd.md" -o "$COMMANDS_DIR/$cmd.md"
  info "Installed: commands/memory/$cmd.md"
done

# Install experience template and INDEX
curl -fsSL "$REPO_URL/template/experience.md" -o "$EXPERIENCES_DIR/_template.md" 2>/dev/null \
  && info "Installed: experiences/_template.md" \
  || warn "Could not fetch experience template (non-fatal)"

if [[ ! -f "$EXPERIENCES_DIR/INDEX.md" ]]; then
  cat > "$EXPERIENCES_DIR/INDEX.md" << 'TMPL'
# Experience Index

Loaded at every session start. Use progressive disclosure:
read this first → run `/memory:experience show <file>` to load full details when relevant.

<!-- Format: - [YYYY-MM-DD] **Title** — `filename.md` — one-line summary (category: X) -->

TMPL
  info "Created: experiences/INDEX.md"
fi

# ──────────────────────────────────────────────
section "Configuring hooks in ~/.gemini/settings.json"

# Build hook commands pointing to the correct scripts location
HOOKS_JSON=$(cat <<HOOKEOF
{
  "SessionStart": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node $SCRIPTS_DIR/session-start.js" }
  ]}],
  "SessionEnd": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node $SCRIPTS_DIR/session-end.js" }
  ]}],
  "UserPromptSubmit": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node $SCRIPTS_DIR/memory-sync.js" },
    { "type": "command", "command": "node $SCRIPTS_DIR/mid-session-checkpoint.js" }
  ]}],
  "PostToolUse": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node $SCRIPTS_DIR/post-tool-logger.js" }
  ]}],
  "PreToolUse": [
    { "matcher": "Bash",  "hooks": [{ "type": "command", "command": "node $SCRIPTS_DIR/pre-push-check.js" }] },
    { "matcher": "Write", "hooks": [{ "type": "command", "command": "node $SCRIPTS_DIR/write-guard.js" }] }
  ]
}
HOOKEOF
)

node - <<EOF
const fs = require('fs');
const settingsPath = '$SETTINGS_FILE';
const newHooks = $HOOKS_JSON;

let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) {}
}
if (!settings.hooks) settings.hooks = {};

for (const [event, groups] of Object.entries(newHooks)) {
  if (!settings.hooks[event]) settings.hooks[event] = [];
  const existing = settings.hooks[event];
  for (const group of groups) {
    const existingGroup = existing.find(g => g.matcher === group.matcher);
    if (existingGroup && existingGroup.hooks) {
      for (const hook of (group.hooks || [])) {
        if (!existingGroup.hooks.some(h => h.command === hook.command)) {
          existingGroup.hooks.push(hook);
        }
      }
    } else {
      existing.push(group);
    }
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('~/.gemini/settings.json updated');
EOF

info "Hooks merged into ~/.gemini/settings.json"

# ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$MODE" == "shared" ]]; then
  echo "  Memory Engine — Gemini CLI (shared with Claude Code)"
  echo "  Storage: ~/.claude/"
else
  echo "  Memory Engine — Gemini CLI (standalone)"
  echo "  Storage: ~/.gemini/"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Restart Gemini CLI to activate hooks."
echo ""
