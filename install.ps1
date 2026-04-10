# Claude Memory Engine — Windows PowerShell Installer
# Usage: irm https://raw.githubusercontent.com/<you>/claude-memory-engine/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$REPO_URL = "https://raw.githubusercontent.com/partypeopleland/claude-memory-engine/main"
$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$SCRIPTS_DIR = "$CLAUDE_DIR\scripts\hooks"
$HOOKS_DIR = "$CLAUDE_DIR\hooks"
$COMMANDS_DIR = "$CLAUDE_DIR\commands\memory"
$CONFIG_FILE = "$CLAUDE_DIR\memory-config.json"
$SETTINGS_FILE = "$CLAUDE_DIR\settings.json"

function Info($msg)    { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ──────────────────────────────────────────────
# Node.js prerequisite check
Section "Checking prerequisites"

try {
  $nodeVer = node --version 2>&1
  Info "Node.js found: $nodeVer"
} catch {
  Write-Host "[X] Node.js is required but not found. Install from https://nodejs.org/ and re-run." -ForegroundColor Red
  exit 1
}

# ──────────────────────────────────────────────
# Backup repo is required
Section "Backup Repository"

Write-Host "Claude Memory Engine stores your memory in a private GitHub repository."
Write-Host "Please create a private repo on GitHub (can be empty) and paste its URL below."
Write-Host ""
$BACKUP_REPO_URL = Read-Host "Backup repo URL (e.g. https://github.com/you/claude-memory)"

if ([string]::IsNullOrWhiteSpace($BACKUP_REPO_URL)) {
  Write-Host "[X] Backup repo URL is required. Installer aborted." -ForegroundColor Red
  exit 1
}

if ($BACKUP_REPO_URL -notmatch "^https://github\.com/") {
  Warn "URL doesn't look like a GitHub HTTPS URL. Continuing anyway..."
}

# ──────────────────────────────────────────────
# Create directories
Section "Creating directories"

$EXPERIENCES_DIR = "$CLAUDE_DIR\experiences"
New-Item -ItemType Directory -Force -Path $SCRIPTS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $HOOKS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $COMMANDS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $EXPERIENCES_DIR | Out-Null
Info "Directories created"

# ──────────────────────────────────────────────
# Download hook scripts
Section "Installing hook scripts"

$HookScripts = @("session-start.js","session-end.js","memory-sync.js","mid-session-checkpoint.js","pre-push-check.js","write-guard.js","post-tool-logger.js")
foreach ($script in $HookScripts) {
  Invoke-WebRequest "$REPO_URL/scripts/hooks/$script" -OutFile "$SCRIPTS_DIR\$script" -UseBasicParsing
  Info "Installed: scripts/hooks/$script"
}

$UtilHooks = @("log-skill-ai.js","log-skill-user.js")
foreach ($script in $UtilHooks) {
  Invoke-WebRequest "$REPO_URL/hooks/$script" -OutFile "$HOOKS_DIR\$script" -UseBasicParsing
  Info "Installed: hooks/$script"
}

# ──────────────────────────────────────────────
# Download slash commands
Section "Installing slash commands"

$Commands = @("save","reload","backup","sync","recover","reflect","diary","learn","check","full-check","compact-guide","health","search","tasks","experience")
foreach ($cmd in $Commands) {
  Invoke-WebRequest "$REPO_URL/commands/memory/$cmd.md" -OutFile "$COMMANDS_DIR\$cmd.md" -UseBasicParsing
  Info "Installed: commands/memory/$cmd.md"
}

# Install experience template
try {
  Invoke-WebRequest "$REPO_URL/template/experience.md" -OutFile "$EXPERIENCES_DIR\_template.md" -UseBasicParsing
  Info "Installed: experiences/_template.md"
} catch { Warn "Could not fetch experience template (non-fatal)" }

# Create INDEX.md if not exists
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
# Merge settings.json (settings.json 採 merge 而非覆蓋, idempotent — dedup by command string)
Section "Configuring hooks in settings.json"

$mergeScript = @"
const fs = require('fs');
const settingsPath = String.raw`$SETTINGS_FILE`.replace(/\\/g, '/');
const configuredHooks = {
  SessionStart: [{ matcher:'*', hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/session-start.js' }] }],
  SessionEnd:   [{ matcher:'*', hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/session-end.js' }] }],
  UserPromptSubmit: [{ matcher:'*', hooks:[
    { type:'command', command:'node ~/.claude/scripts/hooks/memory-sync.js' },
    { type:'command', command:'node ~/.claude/scripts/hooks/mid-session-checkpoint.js' },
    { type:'command', command:'node ~/.claude/hooks/log-skill-user.js' }
  ]}],
  PreToolUse: [
    { matcher:'Bash',  hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/pre-push-check.js' }] },
    { matcher:'Write', hooks:[{ type:'command', command:'node ~/.claude/scripts/hooks/write-guard.js' }] },
    { matcher:'Skill', hooks:[{ type:'command', command:'node ~/.claude/hooks/log-skill-ai.js' }] }
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
console.log('settings.json updated');
"@

node -e $mergeScript
Info "Hooks merged into settings.json"

# ──────────────────────────────────────────────
# Save config
Section "Saving configuration"

@{ backupRepo = $BACKUP_REPO_URL } | ConvertTo-Json | Set-Content $CONFIG_FILE -Encoding UTF8
Info "Saved: ~/.claude/memory-config.json"

# ──────────────────────────────────────────────
# Handle backup repo
Section "Setting up backup repository"

$BACKUP_LOCAL = "$CLAUDE_DIR\memory-backup"

if (Test-Path "$BACKUP_LOCAL\.git") {
  Warn "Backup repo already cloned — pulling latest..."
  git -C $BACKUP_LOCAL pull --quiet
} else {
  git clone $BACKUP_REPO_URL $BACKUP_LOCAL --quiet
  Info "Cloned backup repo to $BACKUP_LOCAL"
}

$backupFiles = (git -C $BACKUP_LOCAL ls-files | Measure-Object -Line).Lines

if ($backupFiles -eq 0) {
  # Empty repo → push template
  Info "Backup repo is empty — initializing with template..."
  New-Item -ItemType Directory -Force -Path "$BACKUP_LOCAL\projects" | Out-Null

  $memTemplate = @"
# Memory Index

<!-- Add memory file pointers here -->
<!-- Format: - [Title](file.md) — one-line description -->
"@
  $memTemplate | Set-Content "$BACKUP_LOCAL\MEMORY.md" -Encoding UTF8
  '{}' | Set-Content "$BACKUP_LOCAL\project-map.json" -Encoding UTF8

  git -C $BACKUP_LOCAL add -A
  git -C $BACKUP_LOCAL commit -m "chore: initialize memory template" --quiet
  git -C $BACKUP_LOCAL push --quiet
  Info "Template pushed to backup repo"

} else {
  # Existing repo → interactive restore
  Info "Backup repo has existing memory. Starting restore..."

  $projectMapPath = "$BACKUP_LOCAL\project-map.json"
  if (Test-Path $projectMapPath) {
    $projectNames = node -e "const d=require(String.raw``$projectMapPath``.replace(/\\/g,'/')); Object.keys(d).forEach(k=>console.log(k));" 2>$null

    if ($projectNames) {
      Write-Host ""
      Write-Host "Found these projects in backup:"
      $projectNames | ForEach-Object { Write-Host "  - $_" }
      Write-Host ""
      Write-Host "For each project, enter its current local path (or press Enter to skip)."
      Write-Host ""

      foreach ($project in $projectNames) {
        $projectPath = Read-Host "  Path for '$project' (e.g. D:\Code\MyProject, or Enter to skip)"

        if ([string]::IsNullOrWhiteSpace($projectPath)) {
          Warn "Skipped '$project' — run /memory:recover later to restore it"
          continue
        }

        # Compute hash: drive + -- + rest joined by -
        $hash = node -e "
          const p = '$($projectPath -replace '\\', '/')';
          const parts = p.split('/').filter(Boolean);
          const drive = parts[0].replace(':','');
          const rest = parts.slice(1).join('-');
          console.log(drive + '--' + rest);
        "

        $memDir = "$CLAUDE_DIR\projects\$hash\memory"
        $srcDir = "$BACKUP_LOCAL\projects\$project"

        if (Test-Path $srcDir) {
          New-Item -ItemType Directory -Force -Path $memDir | Out-Null
          Copy-Item "$srcDir\*" $memDir -Recurse -Force
          Info "Restored '$project' → $memDir"
        } else {
          Warn "No memory found for '$project' in backup repo"
        }
      }
    }
  }
}

# ──────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Claude Memory Engine installed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Available commands (use in Claude Code):"
Write-Host "  /memory:save       Save information to memory"
Write-Host "  /memory:reload     Load memory into context"
Write-Host "  /memory:backup     Push memory to GitHub"
Write-Host "  /memory:reflect    Review and refine memories"
Write-Host "  /memory:check      Quick health check"
Write-Host "  /memory:recover    Restore a project's memory"
Write-Host ""
Write-Host "Restart Claude Code to activate hooks."
Write-Host ""
