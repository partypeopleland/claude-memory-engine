# Claude Memory Engine — Gemini CLI Uninstaller (Windows PowerShell)
# Removes only the Gemini-specific additions. Shared scripts in ~/.claude/ are NOT removed.

$ErrorActionPreference = "Stop"

$GEMINI_DIR    = "$env:USERPROFILE\.gemini"
$COMMANDS_DIR  = "$GEMINI_DIR\commands\memory"
$SETTINGS_FILE = "$GEMINI_DIR\settings.json"

function Info($msg)    { Write-Host "[OK] $msg" -ForegroundColor Green }
function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

Section "Removing Gemini slash commands"

if (Test-Path $COMMANDS_DIR) {
  Remove-Item $COMMANDS_DIR -Recurse -Force
  Info "Removed: ~/.gemini/commands/memory/"
} else {
  Write-Host "  (not found — skipped)"
}

Section "Removing hooks from ~/.gemini/settings.json"

if ((Test-Path $SETTINGS_FILE) -and (Get-Command node -ErrorAction SilentlyContinue)) {
  $cleanScript = @"
const fs = require('fs');
const settingsPath = String.raw``$SETTINGS_FILE``.replace(/\\/g, '/');

if (!fs.existsSync(settingsPath)) { console.log('settings.json not found'); process.exit(0); }

let settings;
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) { process.exit(0); }
if (!settings.hooks) { console.log('No hooks found'); process.exit(0); }

const pattern = /~\/.claude\/scripts\/hooks\//;

for (const [event, groups] of Object.entries(settings.hooks)) {
  settings.hooks[event] = groups
    .map(group => {
      if (group.hooks) {
        group.hooks = group.hooks.filter(h => !pattern.test(h.command || ''));
      }
      return group;
    })
    .filter(group => !group.hooks || group.hooks.length > 0);

  if (settings.hooks[event].length === 0) delete settings.hooks[event];
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
console.log('Hooks removed from ~/.gemini/settings.json');
"@

  node -e $cleanScript
  Info "Hooks cleaned from ~/.gemini/settings.json"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Gemini CLI add-on removed." -ForegroundColor Green
Write-Host "  Shared scripts (~\.claude\scripts\hooks\) were NOT touched." -ForegroundColor Green
Write-Host "  Memory files (~\.claude\projects\) were NOT touched." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
