#!/usr/bin/env node
/**
 * SessionStart Hook — Claude Memory Engine
 * 1. 載入上次 session 摘要
 * 2. 載入當前專案的記憶檔案（依 CWD 自動對應）
 * 3. 載入最近的踩坑紀錄
 * stdout 的內容會被 Claude 看到（注入 context）
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || process.env.USERPROFILE;
const AGENT_DIR = process.env.MEMORY_ENGINE_HOME || path.join(HOME, '.claude');
const SESSIONS_DIR = path.join(AGENT_DIR, 'sessions');
const LEARNED_DIR = path.join(AGENT_DIR, 'skills', 'learned');
const MAX_AGE_DAYS = 7;

// === 根據 CWD 計算 project memory dir（與 Claude Code 的路徑規則一致）===
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

// === 找最近的 session 摘要 ===
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

// === 載入專案記憶（MEMORY.md 索引） ===
function loadProjectMemory(memDir) {
  const memoryFile = path.join(memDir, 'MEMORY.md');
  if (!fs.existsSync(memoryFile)) return null;

  const content = fs.readFileSync(memoryFile, 'utf-8').trim();
  const lines = content.split('\n').slice(0, 60);
  return lines.join('\n');
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

// === 找最近的踩坑紀錄 ===
function findRecentPitfalls() {
  if (!fs.existsSync(LEARNED_DIR)) return null;

  const now = Date.now();
  const maxAge = 3 * 24 * 60 * 60 * 1000;

  const files = fs.readdirSync(LEARNED_DIR)
    .filter(f => f.startsWith('auto-pitfall-') && f.endsWith('.md'))
    .map(f => ({
      name: f,
      path: path.join(LEARNED_DIR, f),
      mtime: fs.statSync(path.join(LEARNED_DIR, f)).mtimeMs
    }))
    .filter(f => (now - f.mtime) < maxAge)
    .sort((a, b) => b.mtime - a.mtime);

  return files.length > 0 ? files[0] : null;
}

// === /reflect 提醒：檢查上次跑 reflect 是什麼時候 ===
function checkReflectReminder() {
  if (!fs.existsSync(SESSIONS_DIR)) return null;

  try {
    const reflectFiles = fs.readdirSync(SESSIONS_DIR)
      .filter(f => f.startsWith('reflect-') && f.endsWith('.md'))
      .map(f => ({
        name: f,
        mtime: fs.statSync(path.join(SESSIONS_DIR, f)).mtimeMs
      }))
      .sort((a, b) => b.mtime - a.mtime);

    if (reflectFiles.length === 0) {
      return '[Memory Engine] /memory:reflect not run yet — try it after a few sessions!';
    }

    const daysSince = Math.floor((Date.now() - reflectFiles[0].mtime) / (24 * 60 * 60 * 1000));
    if (daysSince >= 7) {
      return `[Memory Engine] Last /memory:reflect was ${daysSince} days ago — consider running it!`;
    }
  } catch (e) {}

  return null;
}

// === 踩坑內化檢查：同類踩坑出現 3+ 次就提醒 ===
function checkRecurringPitfalls() {
  if (!fs.existsSync(LEARNED_DIR)) return [];

  const files = fs.readdirSync(LEARNED_DIR)
    .filter(f => f.startsWith('auto-pitfall-') && f.endsWith('.md'));

  if (files.length === 0) return [];

  const typeMap = new Map();

  for (const filename of files) {
    const filepath = path.join(LEARNED_DIR, filename);
    let content;
    try { content = fs.readFileSync(filepath, 'utf-8'); } catch (e) { continue; }

    const dateMatch = filename.match(/auto-pitfall-(\d{8})/);
    const dateTag = dateMatch ? dateMatch[1] : filename;

    const typeBlocks = content.match(/### (\S+)\n- (.+)/g);
    if (!typeBlocks) continue;

    for (const block of typeBlocks) {
      const match = block.match(/### (\S+)\n- (.+)/);
      if (!match) continue;
      const type = match[1];
      const description = match[2];

      if (!typeMap.has(type)) typeMap.set(type, { count: 0, description, dates: new Set() });
      const entry = typeMap.get(type);
      if (!entry.dates.has(dateTag)) {
        entry.dates.add(dateTag);
        entry.count++;
        entry.description = description;
      }
    }
  }

  return [...typeMap.entries()]
    .filter(([, v]) => v.count >= 3)
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, 2)
    .map(([, v]) => ({ count: v.count, description: v.description }));
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
        // 從 summary 裡抽 Agent 欄位（若有）
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

    // 3. 最近踩坑
    const pitfall = findRecentPitfalls();
    if (pitfall) {
      const content = fs.readFileSync(pitfall.path, 'utf-8').trim();
      const brief = content.split('\n').slice(0, 20).join('\n');
      output.push(`\n[Auto Learn] Recent pitfall log:\n${brief}`);
    }

    // 4. 踩坑內化提醒
    const recurring = checkRecurringPitfalls();
    for (const item of recurring) {
      output.push(`[Memory Engine] Pitfall repeated ${item.count} times: ${item.description} — consider adding to CLAUDE.md`);
    }

    // 5. /reflect 提醒
    const reflectReminder = checkReflectReminder();
    if (reflectReminder) output.push(reflectReminder);

  } catch (err) {
    output.push('[Memory Engine] Failed to load memory context, but session continues normally');
  }

  process.stdout.write(output.join('\n') + '\n');
}

main();
