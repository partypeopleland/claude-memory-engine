#!/usr/bin/env bash
# Claude Memory Engine — Uninstaller
# Usage: bash uninstall.sh
#
# This removes all files installed by Claude Memory Engine.
# Your memory files in ~/.claude/projects/ are NOT deleted.

set -e

CLAUDE_DIR="$HOME/.claude"
SCRIPTS_DIR="$CLAUDE_DIR/scripts/hooks"
HOOKS_DIR="$CLAUDE_DIR/hooks"
COMMANDS_DIR="$CLAUDE_DIR/commands/memory"
CONFIG_FILE="$CLAUDE_DIR/memory-config.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${YELLOW}━━ $1 ━━${NC}"; }

section "Claude Memory Engine — Uninstall"
echo ""
echo "This will remove:"
echo "  ~/.claude/scripts/hooks/   (hook scripts)"
echo "  ~/.claude/hooks/log-skill-*.js"
echo "  ~/.claude/commands/memory/ (slash commands)"
echo "  ~/.claude/memory-config.json"
echo ""
echo "Your memory files in ~/.claude/projects/ will NOT be touched."
echo ""
read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

section "Removing hook scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
  rm -rf "$SCRIPTS_DIR"
  info "Removed: scripts/hooks/"
else
  warn "Not found: scripts/hooks/ (already removed?)"
fi

if [[ -f "$HOOKS_DIR/log-skill-ai.js" ]]; then
  rm -f "$HOOKS_DIR/log-skill-ai.js"
  info "Removed: hooks/log-skill-ai.js"
fi
if [[ -f "$HOOKS_DIR/log-skill-user.js" ]]; then
  rm -f "$HOOKS_DIR/log-skill-user.js"
  info "Removed: hooks/log-skill-user.js"
fi

section "Removing slash commands"
if [[ -d "$COMMANDS_DIR" ]]; then
  rm -rf "$COMMANDS_DIR"
  info "Removed: commands/memory/"
else
  warn "Not found: commands/memory/ (already removed?)"
fi

section "Removing config"
if [[ -f "$CONFIG_FILE" ]]; then
  rm -f "$CONFIG_FILE"
  info "Removed: memory-config.json"
else
  warn "Not found: memory-config.json (already removed?)"
fi

section "Cleaning up settings.json"
if [[ -f "$SETTINGS_FILE" ]] && command -v node &>/dev/null; then
  node - <<'EOF'
const fs = require('fs');
const settingsPath = process.env.HOME + '/.claude/settings.json';
if (!fs.existsSync(settingsPath)) process.exit(0);

let settings;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { process.exit(0); }
if (!settings.hooks) process.exit(0);

const MEMORY_COMMANDS = [
  'node ~/.claude/scripts/hooks/session-start.js',
  'node ~/.claude/scripts/hooks/session-end.js',
  'node ~/.claude/scripts/hooks/memory-sync.js',
  'node ~/.claude/scripts/hooks/mid-session-checkpoint.js',
  'node ~/.claude/scripts/hooks/pre-push-check.js',
  'node ~/.claude/scripts/hooks/write-guard.js',
  'node ~/.claude/hooks/log-skill-ai.js',
  'node ~/.claude/hooks/log-skill-user.js',
];

function removeHooks(arr) {
  if (!Array.isArray(arr)) return arr;
  const result = [];
  for (const item of arr) {
    if (item.hooks) {
      item.hooks = item.hooks.filter(h => !MEMORY_COMMANDS.includes(h.command));
      if (item.hooks.length > 0) result.push(item);
    } else if (!MEMORY_COMMANDS.includes(item.command)) {
      result.push(item);
    }
  }
  return result;
}

for (const event of Object.keys(settings.hooks)) {
  settings.hooks[event] = removeHooks(settings.hooks[event]);
  if (settings.hooks[event].length === 0) delete settings.hooks[event];
}
if (Object.keys(settings.hooks).length === 0) delete settings.hooks;

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('settings.json cleaned');
EOF
  info "Hooks removed from settings.json"
else
  warn "Skipped settings.json cleanup (Node.js not found or file missing)"
  warn "Manually remove memory engine hooks from ~/.claude/settings.json"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Memory Engine uninstalled."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your memory files are preserved in:"
echo "  ~/.claude/projects/<hash>/memory/"
echo ""
echo "Restart Claude Code to deactivate hooks."
echo ""
