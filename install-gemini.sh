#!/usr/bin/env bash
# Claude Memory Engine — Gemini CLI Add-on Installer
# Adds memory engine support to Gemini CLI (shared memory with Claude Code).
#
# Prerequisites: Claude Memory Engine must already be installed (install.sh).
# Usage: curl -fsSL https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
CLAUDE_DIR="$HOME/.claude"
GEMINI_DIR="$HOME/.gemini"
COMMANDS_DIR="$GEMINI_DIR/commands/memory"
SETTINGS_FILE="$GEMINI_DIR/settings.json"

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
# Check prerequisites
section "Checking prerequisites"

if ! command -v node &>/dev/null; then
  error "Node.js is required but not found. Install it from https://nodejs.org/ and re-run."
fi
info "Node.js found: $(node --version)"

# Check Claude Memory Engine is already installed
if [[ ! -f "$CLAUDE_DIR/scripts/hooks/session-start.js" ]]; then
  error "Claude Memory Engine not found at $CLAUDE_DIR/scripts/hooks/. Run install.sh first."
fi
info "Claude Memory Engine found at $CLAUDE_DIR"

# ──────────────────────────────────────────────
# Create Gemini directories
section "Creating Gemini directories"

mkdir -p "$COMMANDS_DIR" "$GEMINI_DIR"
info "Created: $COMMANDS_DIR"

# ──────────────────────────────────────────────
# Install slash commands
section "Installing slash commands to ~/.gemini/commands/memory/"

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
# Merge hooks into ~/.gemini/settings.json
# Hooks point to the shared scripts in ~/.claude/scripts/hooks/
# Memory data is read from ~/.claude/ (MEMORY_ENGINE_HOME defaults to ~/.claude)
section "Configuring hooks in ~/.gemini/settings.json"

HOOKS_JSON='{
  "SessionStart": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node ~/.claude/scripts/hooks/session-start.js" }
  ]}],
  "SessionEnd": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node ~/.claude/scripts/hooks/session-end.js" }
  ]}],
  "UserPromptSubmit": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "node ~/.claude/scripts/hooks/memory-sync.js" },
    { "type": "command", "command": "node ~/.claude/scripts/hooks/mid-session-checkpoint.js" }
  ]}],
  "PreToolUse": [
    { "matcher": "Bash",  "hooks": [{ "type": "command", "command": "node ~/.claude/scripts/hooks/pre-push-check.js" }] },
    { "matcher": "Write", "hooks": [{ "type": "command", "command": "node ~/.claude/scripts/hooks/write-guard.js" }] }
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Memory Engine — Gemini CLI add-on done!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Memory is SHARED with Claude Code (~/.claude/)."
echo "Sessions, pitfalls, and project memory are visible to both."
echo ""
echo "Restart Gemini CLI to activate hooks."
echo ""
