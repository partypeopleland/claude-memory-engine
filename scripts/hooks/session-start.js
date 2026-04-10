#!/usr/bin/env node
/**
 * SessionStart Hook — Claude Memory Engine
 * 1. 載入上次 session 摘要
 * 2. 載入當前專案的記憶檔案（依 CWD 自動對應）
 * 3. 載入 Experience INDEX（AI 知道自己有哪些經驗）
 * stdout 的內容會被 Claude / Gemini 看到（注入 context）
 */

const fs = require('fs');
const path = require('path');

const HOME           = process.env.HOME || process.env.USERPROFILE;
const AGENT_DIR      = process.env.MEMORY_ENGINE_HOME || path.join(HOME, '.claude');
const SESSIONS_DIR   = path.join(AGENT_DIR, 'sessions');
const EXPERIENCES_DIR = path.join(AGENT_DIR, 'experiences');
const MAX_AGE_DAYS   = 7;

// === 根據 CWD 計算 project memory dir ===
function getProjectMemoryDir() {
  const cwd = process.cwd();
  const parts = cwd.replace(/\\/g, '/').split('/').filter(Boolean);
  if (parts.length === 0) return null;

  const drive = parts[0].replace(':', '');
  const rest = parts.slice(1).join('-');
  const projectId = `${drive}--${rest}`;

  const memDir = path.join(AGENT_DIR, 'projects', projectId, 'memory');
  if (fs.existsSync(memDir)) return { dir: memDir, projectId };

  return null;
}

// === 找最近的 session 摘要（7 天內）===
function findLatestSession() {
  if (!fs.existsSync(SESSIONS_DIR)) return null;

  const now = Date.now();
  const maxAge = MAX_AGE_DAYS * 24 * 60 * 60 * 1000;

  const files = fs.readdirSync(SESSIONS_DIR)
    .filter(f => f.endsWith('-session.md'))
    .map(f => ({
      name: f,
      path: path.join(SESSIONS_DIR, f),
      mtime: fs.statSync(path.join(SESSIONS_DIR, f)).mtimeMs
    }))
    .filter(f => (now - f.mtime) < maxAge)
    .sort((a, b) => b.mtime - a.mtime);

  return files.length > 0 ? files[0] : null;
}

// === 載入專案記憶（MEMORY.md 索引，前 60 行）===
function loadProjectMemory(memDir) {
  const memoryFile = path.join(memDir, 'MEMORY.md');
  if (!fs.existsSync(memoryFile)) return null;

  const content = fs.readFileSync(memoryFile, 'utf-8').trim();
  return content.split('\n').slice(0, 60).join('\n');
}

// === 找 24 小時內改過的 memory 檔案 ===
function findRecentMemoryChanges(memDir) {
  if (!fs.existsSync(memDir)) return [];

  const now = Date.now();
  const maxAge = 24 * 60 * 60 * 1000;

  return fs.readdirSync(memDir)
    .filter(f => f.endsWith('.md'))
    .map(f => ({
      name: f,
      mtime: fs.statSync(path.join(memDir, f)).mtimeMs
    }))
    .filter(f => (now - f.mtime) < maxAge)
    .sort((a, b) => b.mtime - a.mtime)
    .map(f => f.name);
}

// === 載入 Experience INDEX（前 80 行）===
// AI 藉此知道「我曾經有過哪些經驗」，需要時再以 /memory:experience show <file> 漸進揭露
function loadExperienceIndex() {
  const indexFile = path.join(EXPERIENCES_DIR, 'INDEX.md');
  if (!fs.existsSync(indexFile)) return null;

  const content = fs.readFileSync(indexFile, 'utf-8').trim();
  if (!content || content.length < 10) return null;

  return content.split('\n').slice(0, 80).join('\n');
}

// === 檢查上次 session 是否有存新的 experience ===
// 若沒有，提醒 AI 回顧上次 session log 並考慮是否值得儲存
function checkExperienceReminder(latestSession) {
  if (!latestSession) return null;

  try {
    // 找 session 結束後是否有新增 experience 檔案
    const sessionMtime = fs.statSync(latestSession.path).mtimeMs;
    if (!fs.existsSync(EXPERIENCES_DIR)) {
      // 完全沒有 experiences 目錄 → 提醒
      return '[Experience] No experience directory yet. Use `/memory:experience save` to save valuable lessons from sessions.';
    }

    const newExps = fs.readdirSync(EXPERIENCES_DIR)
      .filter(f => f.endsWith('.md') && f !== 'INDEX.md' && f !== '_template.md')
      .map(f => ({ name: f, mtime: fs.statSync(path.join(EXPERIENCES_DIR, f)).mtimeMs }))
      .filter(f => f.mtime > sessionMtime);

    if (newExps.length > 0) {
      return null; // 上次 session 後有存 experience，不用提醒
    }

    // 上次 session 沒有存新 experience → 輕微提醒
    const sessionDate = latestSession.name.split('-session.md')[0];
    return `[Experience] Last session (${sessionDate}) had no experience saved. If anything worth remembering happened, run \`/memory:experience save\`.`;

  } catch (e) {
    return null;
  }
}

// === 主程式 ===
function main() {
  const output = [];

  try {
    // 1. 載入上次 session 摘要
    const latest = findLatestSession();
    if (latest) {
      const content = fs.readFileSync(latest.path, 'utf-8').trim();
      if (content && content.length >= 20) {
        const dateSlug = latest.name.split('-session.md')[0];
        const agentMatch = content.match(/\*\*Agent:\*\*\s*(.+)/);
        const agentHint = agentMatch ? ` [by ${agentMatch[1].trim()}]` : '';
        output.push(`[Session Hook] 上次工作摘要（${dateSlug}${agentHint})：\n${content}`);
      }
    } else {
      output.push('[Session Hook] No recent session found — fresh start!');
    }

    // 2. 載入當前專案記憶
    const projectMem = getProjectMemoryDir();
    if (projectMem) {
      const memContent = loadProjectMemory(projectMem.dir);
      if (memContent) {
        output.push(`\n[Memory] Project memory loaded (${projectMem.projectId}):\n${memContent}`);
      }

      const recentChanges = findRecentMemoryChanges(projectMem.dir);
      if (recentChanges.length > 0) {
        output.push(`[Memory] Updated in last 24h: ${recentChanges.join(', ')}`);
      }
    }

    // 3. 載入 Experience INDEX
    const expIndex = loadExperienceIndex();
    if (expIndex) {
      output.push(`\n[Experience] Your experience index (use \`/memory:experience show <file>\` to load full details):\n${expIndex}`);
    }

    // 4. 提醒是否需要存 experience
    const expReminder = checkExperienceReminder(latest);
    if (expReminder) output.push(expReminder);

  } catch (err) {
    output.push('[Memory Engine] Failed to load memory context, but session continues normally');
  }

  process.stdout.write(output.join('\n') + '\n');
}

main();
