# Claude Memory Engine — Windows PowerShell Uninstaller
# Usage: .\uninstall.ps1
#
# This removes all files installed by Claude Memory Engine.
# Your memory files in ~/.claude/projects/ are NOT deleted.

$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$SCRIPTS_DIR = "$CLAUDE_DIR\scripts\hooks"
$HOOKS_DIR = "$CLAUDE_DIR\hooks"
$COMMANDS_DIR = "$CLAUDE_DIR\commands\memory"
$CONFIG_FILE = "$CLAUDE_DIR\memory-config.json"
$SETTINGS_FILE = "$CLAUDE_DIR\settings.json"

function Info($msg)    { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

Section "Claude Memory Engine — Uninstall"
Write-Host ""
Write-Host "This will remove:"
Write-Host "  ~\.claude\scripts\hooks\   (hook scripts)"
Write-Host "  ~\.claude\hooks\log-skill-*.js"
Write-Host "  ~\.claude\commands\memory\ (slash commands)"
Write-Host "  ~\.claude\memory-config.json"
Write-Host ""
Write-Host "Your memory files in ~\.claude\projects\ will NOT be touched."
Write-Host ""
$confirm = Read-Host "Continue? [y/N]"
if ($confirm -notmatch '^[Yy]$') {
  Write-Host "Aborted."
  exit 0
}

Section "Removing hook scripts"
if (Test-Path $SCRIPTS_DIR) {
  Remove-Item -Recurse -Force $SCRIPTS_DIR
  Info "Removed: scripts\hooks\"
} else {
  Warn "Not found: scripts\hooks\ (already removed?)"
}

foreach ($f in @("log-skill-ai.js", "log-skill-user.js")) {
  $p = "$HOOKS_DIR\$f"
  if (Test-Path $p) {
    Remove-Item -Force $p
    Info "Removed: hooks\$f"
  }
}

Section "Removing slash commands"
if (Test-Path $COMMANDS_DIR) {
  Remove-Item -Recurse -Force $COMMANDS_DIR
  Info "Removed: commands\memory\"
} else {
  Warn "Not found: commands\memory\ (already removed?)"
}

Section "Removing config"
if (Test-Path $CONFIG_FILE) {
  Remove-Item -Force $CONFIG_FILE
  Info "Removed: memory-config.json"
} else {
  Warn "Not found: memory-config.json (already removed?)"
}

Section "Cleaning up settings.json"
$nodeAvailable = $null
try { $nodeAvailable = node --version 2>&1 } catch {}

if ($nodeAvailable -and (Test-Path $SETTINGS_FILE)) {
  $cleanScript = @"
const fs = require('fs');
const settingsPath = String.raw`$SETTINGS_FILE`.replace(/\\/g, '/');
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
"@
  node -e $cleanScript
  Info "Hooks removed from settings.json"
} else {
  Warn "Skipped settings.json cleanup (Node.js not found or file missing)"
  Warn "Manually remove memory engine hooks from ~\.claude\settings.json"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Claude Memory Engine uninstalled." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your memory files are preserved in:"
Write-Host "  ~\.claude\projects\<hash>\memory\"
Write-Host ""
Write-Host "Restart Claude Code to deactivate hooks."
Write-Host ""
