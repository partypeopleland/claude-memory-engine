# Claude Memory Engine — Gemini CLI Add-on Installer (Windows PowerShell)
# Adds memory engine support to Gemini CLI (shared memory with Claude Code).
#
# Prerequisites: Claude Memory Engine must already be installed (install.ps1).
# Usage: irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.ps1 | iex

$ErrorActionPreference = "Stop"

$REPO_URL    = "https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
$CLAUDE_DIR  = "$env:USERPROFILE\.claude"
$GEMINI_DIR  = "$env:USERPROFILE\.gemini"
$COMMANDS_DIR = "$GEMINI_DIR\commands\memory"
$SETTINGS_FILE = "$GEMINI_DIR\settings.json"

function Info($msg)    { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ──────────────────────────────────────────────
Section "Checking prerequisites"

try {
  $nodeVer = node --version 2>&1
  Info "Node.js found: $nodeVer"
} catch {
  Write-Host "[X] Node.js is required. Install from https://nodejs.org/ and re-run." -ForegroundColor Red
  exit 1
}

if (-not (Test-Path "$CLAUDE_DIR\scripts\hooks\session-start.js")) {
  Write-Host "[X] Claude Memory Engine not found at $CLAUDE_DIR\scripts\hooks\. Run install.ps1 first." -ForegroundColor Red
  exit 1
}
Info "Claude Memory Engine found at $CLAUDE_DIR"

# ──────────────────────────────────────────────
Section "Creating Gemini directories"

New-Item -ItemType Directory -Force -Path $COMMANDS_DIR | Out-Null
Info "Created: $COMMANDS_DIR"

# ──────────────────────────────────────────────
Section "Installing slash commands to ~/.gemini/commands/memory/"

$Commands = @("save","reload","backup","sync","recover","reflect","diary","learn","check","full-check","compact-guide","health","search","tasks","experience")
foreach ($cmd in $Commands) {
  Invoke-WebRequest "$REPO_URL/commands/memory/$cmd.md" -OutFile "$COMMANDS_DIR\$cmd.md" -UseBasicParsing
  Info "Installed: commands/memory/$cmd.md"
}

# ──────────────────────────────────────────────
# Merge hooks into ~/.gemini/settings.json
# Hooks point to shared scripts in ~/.claude/scripts/hooks/
Section "Configuring hooks in ~/.gemini/settings.json"

$mergeScript = @"
const fs = require('fs');
const settingsPath = String.raw``$SETTINGS_FILE``.replace(/\\/g, '/');
const configuredHooks = {
  SessionStart: [{ matcher:'*', hooks:[
    { type:'command', command:'node ~/.claude/scripts/hooks/session-start.js' }
  ]}],
  SessionEnd: [{ matcher:'*', hooks:[
    { type:'command', command:'node ~/.claude/scripts/hooks/session-end.js' }
  ]}],
  UserPromptSubmit: [{ matcher:'*', hooks:[
    { type:'command', command:'node ~/.claude/scripts/hooks/memory-sync.js' },
    { type:'command', command:'node ~/.claude/scripts/hooks/mid-session-checkpoint.js' }
  ]}],
  PostToolUse: [{ matcher:'*', hooks:[
    { type:'command', command:'node ~/.claude/scripts/hooks/post-tool-logger.js' }
  ]}],
  PreToolUse: [
    { matcher:'Bash',  hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/pre-push-check.js' }] },
    { matcher:'Write', hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/write-guard.js' }] }
  ]
};

let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8')); } catch(e) {}
}
if (!settings.hooks) settings.hooks = {};

for (const [event, groups] of Object.entries(configuredHooks)) {
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
"@

node -e $mergeScript
Info "Hooks merged into ~/.gemini/settings.json"

# ──────────────────────────────────────────────
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Claude Memory Engine — Gemini CLI add-on done!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Memory is SHARED with Claude Code (~\.claude\)."
Write-Host "Sessions, pitfalls, and project memory are visible to both."
Write-Host ""
Write-Host "Restart Gemini CLI to activate hooks."
Write-Host ""
