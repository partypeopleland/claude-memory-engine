# Claude Memory Engine — Gemini CLI Installer (Windows PowerShell)
#
# Works in two modes (auto-detected):
#   SHARED mode     — Claude Code is already installed → reuse ~/.claude/ scripts & storage
#   STANDALONE mode — No Claude Code → install scripts to ~/.gemini/, data in ~/.gemini/
#
# Usage: irm https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main/install-gemini.ps1 | iex

$ErrorActionPreference = "Stop"

$REPO_URL     = "https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
$GEMINI_DIR   = "$env:USERPROFILE\.gemini"
$CLAUDE_DIR   = "$env:USERPROFILE\.claude"
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

# ──────────────────────────────────────────────
# Auto-detect mode
if (Test-Path "$CLAUDE_DIR\scripts\hooks\session-start.js") {
  $MODE        = "shared"
  $SCRIPTS_DIR = "$CLAUDE_DIR\scripts\hooks"
  $MEMORY_HOME = $CLAUDE_DIR
  Info "Claude Code detected → SHARED mode (scripts: ~/.claude/, storage: ~/.claude/)"
} else {
  $MODE        = "standalone"
  $SCRIPTS_DIR = "$GEMINI_DIR\scripts\hooks"
  $MEMORY_HOME = $GEMINI_DIR
  Info "No Claude Code found → STANDALONE mode (scripts: ~/.gemini/, storage: ~/.gemini/)"
}

$EXPERIENCES_DIR = "$MEMORY_HOME\experiences"

# ──────────────────────────────────────────────
Section "Creating directories"

New-Item -ItemType Directory -Force -Path $COMMANDS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $EXPERIENCES_DIR | Out-Null
Info "Created: $COMMANDS_DIR"
Info "Created: $EXPERIENCES_DIR"

# ──────────────────────────────────────────────
if ($MODE -eq "standalone") {
  Section "Installing hook scripts to ~/.gemini/scripts/hooks/"
  New-Item -ItemType Directory -Force -Path $SCRIPTS_DIR | Out-Null

  $HookScripts = @(
    "session-start.js","session-end.js","memory-sync.js",
    "mid-session-checkpoint.js","pre-push-check.js","write-guard.js",
    "post-tool-logger.js"
  )
  foreach ($script in $HookScripts) {
    Invoke-WebRequest "$REPO_URL/scripts/hooks/$script" -OutFile "$SCRIPTS_DIR\$script" -UseBasicParsing
    Info "Installed: $script"
  }

  # Write .memory-home so scripts know the data directory
  $MEMORY_HOME | Set-Content "$SCRIPTS_DIR\.memory-home" -Encoding UTF8
  Info "Configured data directory: $MEMORY_HOME"

  # Backup repo setup
  Section "Backup Repository"
  Write-Host "Please create a private GitHub repo for memory backup (can be empty)."
  Write-Host ""
  $BACKUP_REPO_URL = Read-Host "Backup repo URL (e.g. https://github.com/you/my-memory, or Enter to skip)"

  if ([string]::IsNullOrWhiteSpace($BACKUP_REPO_URL)) {
    Warn "No backup repo — skipping. Run /memory:backup later."
  } else {
    @{ backupRepo = $BACKUP_REPO_URL } | ConvertTo-Json | Set-Content "$MEMORY_HOME\memory-config.json" -Encoding UTF8
    Info "Saved: memory-config.json"

    $BACKUP_LOCAL = "$MEMORY_HOME\memory-backup"
    if (Test-Path "$BACKUP_LOCAL\.git") {
      Warn "Backup repo already cloned — pulling latest..."
      git -C $BACKUP_LOCAL pull --quiet
    } else {
      git clone $BACKUP_REPO_URL $BACKUP_LOCAL --quiet
      Info "Cloned backup repo to $BACKUP_LOCAL"
    }

    $backupFiles = (git -C $BACKUP_LOCAL ls-files | Measure-Object -Line).Lines
    if ($backupFiles -eq 0) {
      New-Item -ItemType Directory -Force -Path "$BACKUP_LOCAL\projects" | Out-Null
      New-Item -ItemType Directory -Force -Path "$BACKUP_LOCAL\experiences" | Out-Null
      "# Memory Index`n`n<!-- Format: - [Title](file.md) — one-line description -->" |
        Set-Content "$BACKUP_LOCAL\MEMORY.md" -Encoding UTF8
      '{}' | Set-Content "$BACKUP_LOCAL\project-map.json" -Encoding UTF8
      git -C $BACKUP_LOCAL add -A
      git -C $BACKUP_LOCAL commit -m "chore: initialize memory template" --quiet
      git -C $BACKUP_LOCAL push --quiet
      Info "Template pushed to backup repo"
    } else {
      Info "Backup repo has existing memory"
    }
  }
} else {
  Section "Skipping script installation (shared mode — using ~/.claude/scripts/hooks/)"
}

# ──────────────────────────────────────────────
Section "Installing slash commands to ~/.gemini/commands/memory/"

$Commands = @(
  "save","reload","backup","sync","recover","reflect","diary","learn",
  "check","full-check","compact-guide","health","search","tasks","experience"
)
foreach ($cmd in $Commands) {
  Invoke-WebRequest "$REPO_URL/commands/memory/$cmd.md" -OutFile "$COMMANDS_DIR\$cmd.md" -UseBasicParsing
  Info "Installed: commands/memory/$cmd.md"
}

# Experience template + INDEX
try {
  Invoke-WebRequest "$REPO_URL/template/experience.md" -OutFile "$EXPERIENCES_DIR\_template.md" -UseBasicParsing
  Info "Installed: experiences/_template.md"
} catch { Warn "Could not fetch experience template (non-fatal)" }

if (-not (Test-Path "$EXPERIENCES_DIR\INDEX.md")) {
  @"
# Experience Index

Loaded at every session start. Use progressive disclosure:
read this first -> run ``/memory:experience show <file>`` to load full details when relevant.

<!-- Format: - [YYYY-MM-DD] **Title** — ``filename.md`` — one-line summary (category: X) -->

"@ | Set-Content "$EXPERIENCES_DIR\INDEX.md" -Encoding UTF8
  Info "Created: experiences/INDEX.md"
}

# ──────────────────────────────────────────────
Section "Configuring hooks in ~/.gemini/settings.json"

# Use forward slashes for node command paths
$ScriptsDirFwd = $SCRIPTS_DIR -replace '\\', '/'

$mergeScript = @"
const fs = require('fs');
const settingsPath = String.raw``$SETTINGS_FILE``.replace(/\\/g, '/');
const scriptsDir = '$ScriptsDirFwd';
const configuredHooks = {
  SessionStart: [{ matcher:'*', hooks:[
    { type:'command', command:'node ' + scriptsDir + '/session-start.js' }
  ]}],
  SessionEnd: [{ matcher:'*', hooks:[
    { type:'command', command:'node ' + scriptsDir + '/session-end.js' }
  ]}],
  UserPromptSubmit: [{ matcher:'*', hooks:[
    { type:'command', command:'node ' + scriptsDir + '/memory-sync.js' },
    { type:'command', command:'node ' + scriptsDir + '/mid-session-checkpoint.js' }
  ]}],
  PostToolUse: [{ matcher:'*', hooks:[
    { type:'command', command:'node ' + scriptsDir + '/post-tool-logger.js' }
  ]}],
  PreToolUse: [
    { matcher:'Bash',  hooks:[{ type:'command', command:'node ' + scriptsDir + '/pre-push-check.js' }] },
    { matcher:'Write', hooks:[{ type:'command', command:'node ' + scriptsDir + '/write-guard.js' }] }
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
if ($MODE -eq "shared") {
  Write-Host "================================================" -ForegroundColor Green
  Write-Host "  Memory Engine — Gemini CLI (shared mode)"     -ForegroundColor Green
  Write-Host "  Storage: ~/.claude/"                           -ForegroundColor Green
} else {
  Write-Host "================================================" -ForegroundColor Green
  Write-Host "  Memory Engine — Gemini CLI (standalone)"       -ForegroundColor Green
  Write-Host "  Storage: ~/.gemini/"                           -ForegroundColor Green
}
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Restart Gemini CLI to activate hooks."
Write-Host ""
