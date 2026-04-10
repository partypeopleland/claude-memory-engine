#!/usr/bin/env bash
# Claude Memory Engine — Gemini CLI Uninstaller
# Removes only the Gemini-specific additions. Shared scripts in ~/.claude/ are NOT removed.

set -e

GEMINI_DIR="$HOME/.gemini"
COMMANDS_DIR="$GEMINI_DIR/commands/memory"
SETTINGS_FILE="$GEMINI_DIR/settings.json"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $1"; }
section() { echo -e "\n${YELLOW}━━ $1 ━━${NC}"; }

section "Removing Gemini slash commands"

if [[ -d "$COMMANDS_DIR" ]]; then
  rm -rf "$COMMANDS_DIR"
  info "Removed: ~/.gemini/commands/memory/"
else
  echo "  (not found — skipped)"
fi

section "Removing hooks from ~/.gemini/settings.json"

if [[ -f "$SETTINGS_FILE" ]] && command -v node &>/dev/null; then
  node - <<'EOF'
const fs = require('fs');
const path = require('path');
const HOME = process.env.HOME || process.env.USERPROFILE;
const settingsPath = path.join(HOME, '.gemini', 'settings.json');

if (!fs.existsSync(settingsPath)) { console.log('settings.json not found — skipped'); process.exit(0); }

let settings;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { process.exit(0); }
if (!settings.hooks) { console.log('No hooks found — skipped'); process.exit(0); }

const memoryHookPattern = /~\/.claude\/scripts\/hooks\//;

for (const [event, groups] of Object.entries(settings.hooks)) {
  settings.hooks[event] = groups
    .map(group => {
      if (group.hooks) {
        group.hooks = group.hooks.filter(h => !memoryHookPattern.test(h.command || ''));
      }
      return group;
    })
    .filter(group => !group.hooks || group.hooks.length > 0);

  if (settings.hooks[event].length === 0) delete settings.hooks[event];
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('Hooks removed from ~/.gemini/settings.json');
EOF
  info "Hooks cleaned from ~/.gemini/settings.json"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Gemini CLI add-on removed."
echo "  Shared scripts (~/.claude/scripts/hooks/) were NOT touched."
echo "  Memory files (~/.claude/projects/) were NOT touched."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
