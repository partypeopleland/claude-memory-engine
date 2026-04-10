#!/usr/bin/env node
/**
 * UserPromptSubmit Hook — Claude Memory Engine
 * 偵測 MEMORY.md 被其他 session 更新時，注入變更內容給 Claude
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || process.env.USERPROFILE;

function resolveAgentDir() {
  if (process.env.MEMORY_ENGINE_HOME) return process.env.MEMORY_ENGINE_HOME;
  try {
    const configFile = path.join(__dirname, '.memory-home');
    if (fs.existsSync(configFile)) {
      return fs.readFileSync(configFile, 'utf-8').trim().replace(/^~/, HOME);
    }
  } catch (e) {}
  return path.join(HOME, '.claude');
}
const AGENT_DIR = resolveAgentDir();
const PROJECTS_DIR = path.join(AGENT_DIR, 'projects');
const STATE_FILE = path.join(AGENT_DIR, 'scripts', 'hooks', '.memory-sync-state.json');

function getProjectMemoryDir() {
  const parts = process.cwd().replace(/\\/g, '/').split('/').filter(Boolean);
  if (parts.length === 0) return null;

  const drive = parts[0].replace(':', '');
  const rest = parts.slice(1).join('-');
  const projectId = `${drive}--${rest}`;

  const memDir = path.join(PROJECTS_DIR, projectId, 'memory');
  if (fs.existsSync(memDir)) return memDir;
  return null;
}

function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) return JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'));
  } catch (e) {}
  return {};
}

function saveState(state) {
  try { fs.writeFileSync(STATE_FILE, JSON.stringify(state), 'utf-8'); } catch (e) {}
}

function getChangedLines(oldContent, newContent) {
  const oldLines = new Set(oldContent.split('\n').map(l => l.trim()).filter(Boolean));
  return newContent.split('\n').map(l => l.trim()).filter(l => l && !oldLines.has(l));
}

function main() {
  try {
    const memDir = getProjectMemoryDir();
    if (!memDir) return;

    const memoryFile = path.join(memDir, 'MEMORY.md');
    if (!fs.existsSync(memoryFile)) return;

    const stat = fs.statSync(memoryFile);
    const currentContent = fs.readFileSync(memoryFile, 'utf-8');
    const currentHash = Buffer.from(currentContent).toString('base64').substring(0, 32);

    const state = loadState();
    const lastHash = state[memoryFile + ':hash'] || '';

    if (!lastHash) {
      state[memoryFile + ':hash'] = currentHash;
      state[memoryFile + ':content'] = currentContent;
      saveState(state);
      return;
    }

    if (currentHash !== lastHash) {
      const oldContent = state[memoryFile + ':content'] || '';
      const changedLines = getChangedLines(oldContent, currentContent);

      const changedFiles = [];
      for (const f of fs.readdirSync(memDir).filter(f => f.endsWith('.md'))) {
        const fp = path.join(memDir, f);
        const fLastMtime = state[fp + ':mtime'] || 0;
        const fstat = fs.statSync(fp);
        if (fstat.mtimeMs > fLastMtime) {
          changedFiles.push(f);
          state[fp + ':mtime'] = fstat.mtimeMs;
        }
      }

      state[memoryFile + ':hash'] = currentHash;
      state[memoryFile + ':content'] = currentContent;
      saveState(state);

      const output = [];
      if (changedFiles.length > 0) output.push(`[Memory Sync] Memory files updated: ${changedFiles.join(', ')}`);
      if (changedLines.length > 0) {
        const preview = changedLines.slice(0, 5).join('\n  ');
        output.push(`[Memory Sync] New/modified content:\n  ${preview}`);
        if (changedLines.length > 5) output.push(`  ...and ${changedLines.length - 5} more lines`);
      }

      if (output.length > 0) process.stdout.write(output.join('\n') + '\n');
    }
  } catch (err) {
    // 靜默失敗
  }
}

main();
