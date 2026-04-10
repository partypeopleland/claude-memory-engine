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
const AGENT_DIR      = resolveAgentDir();
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

// === 讀取並消費「待回顧」標記 ===
// session-end 在 substantial session 後會留下此標記
// 我們讀取、注入指令後立即刪除（避免重複觸發）
function consumePendingExperienceReview() {
  const pendingFile = path.join(SESSIONS_DIR, '.pending-experience-review.json');
  if (!fs.existsSync(pendingFile)) return null;

  try {
    const meta        = JSON.parse(fs.readFileSync(pendingFile, 'utf-8'));
    const sessionPath = path.join(SESSIONS_DIR, meta.sessionFile);

    // 立即刪除，避免重複注入
    try { fs.unlinkSync(pendingFile); } catch (e) {}

    if (!fs.existsSync(sessionPath)) return null;

    const log = fs.readFileSync(sessionPath, 'utf-8').trim();
    return { log, meta };
  } catch (e) {
    try { fs.unlinkSync(pendingFile); } catch (_) {}
    return null;
  }
}

// === 建構「自動經驗回顧」指令 ===
function buildExperienceReviewDirective(log, meta) {
  const expDir      = EXPERIENCES_DIR;
  const indexFile   = path.join(expDir, 'INDEX.md');
  const templateFile = path.join(expDir, '_template.md');

  return `[Auto Experience Review] The previous session (${meta.date}, project: ${meta.project}, ${meta.messageCount} messages) has been flagged for experience review.

**This is an automatic action — proceed without asking the user.**

Steps:
1. Read the session log below
2. Identify events worth preserving: mistakes corrected, surprising behaviour, useful patterns, things you learned
3. For each valuable experience:
   a. Write a new file: \`${expDir}/YYYY-MM-DD-short-slug.md\` using the template at \`${templateFile}\`
   b. Add one line to \`${indexFile}\` under the correct category section
4. If nothing is worth saving, skip and proceed with the user's request

--- Previous Session Log (${meta.date}) ---
${log}
--- End of Session Log ---

After review (save or skip), proceed normally with whatever the user asks next.`;
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

    // 4. 自動回顧上次 session 並萃取經驗（若有待回顧標記）
    const pending = consumePendingExperienceReview();
    if (pending) {
      output.push(`\n${buildExperienceReviewDirective(pending.log, pending.meta)}`);
    }

  } catch (err) {
    output.push('[Memory Engine] Failed to load memory context, but session continues normally');
  }

  process.stdout.write(output.join('\n') + '\n');
}

main();
