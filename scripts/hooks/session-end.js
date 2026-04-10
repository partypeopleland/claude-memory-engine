#!/usr/bin/env node
/**
 * SessionEnd Hook — Claude Memory Engine
 * 1. 每次 session 結束自動儲存工作摘要
 * 2. 偵測踩坑模式，自動存到 learned/
 * 從 stdin 讀取 JSON（含 transcript_path）
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || process.env.USERPROFILE;
const AGENT_DIR = process.env.MEMORY_ENGINE_HOME || path.join(HOME, '.claude');
const SESSIONS_DIR = path.join(AGENT_DIR, 'sessions');
const LEARNED_DIR = path.join(AGENT_DIR, 'skills', 'learned');
const DEBUG_LOG = path.join(SESSIONS_DIR, 'debug.log');
const MAX_SESSIONS = 30;

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function debugLog(msg) {
  ensureDir(SESSIONS_DIR);
  fs.appendFileSync(DEBUG_LOG, `[${new Date().toISOString()}] ${msg}\n`, 'utf-8');
}

// === 從 CWD 推斷專案名稱（取最後一層目錄） ===
function detectProjectTag(userMessages, inputCwd, filesModified) {
  const cwd = (inputCwd || process.cwd()).replace(/\\/g, '/');
  const parts = cwd.split('/').filter(Boolean);
  const lastDir = parts[parts.length - 1] || 'general';

  // 過濾掉使用者目錄名稱
  if (['Users', 'home', 'root'].some(p => lastDir.toLowerCase() === p.toLowerCase())) {
    return 'general';
  }

  return lastDir.toLowerCase();
}

// === 找 fallback transcript ===
function findFallbackTranscript(originalPath) {
  const projectsDir = path.join(AGENT_DIR, 'projects');
  const searchDirs = [];

  if (originalPath) {
    const dir = path.dirname(originalPath);
    if (fs.existsSync(dir)) searchDirs.push(dir);
  }

  if (fs.existsSync(projectsDir)) {
    try {
      fs.readdirSync(projectsDir, { withFileTypes: true })
        .filter(e => e.isDirectory())
        .forEach(e => searchDirs.push(path.join(projectsDir, e.name)));
    } catch (e) {}
  }

  let bestFile = null;
  let bestMtime = 0;

  for (const dir of searchDirs) {
    try {
      for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.jsonl'))) {
        const fp = path.join(dir, f);
        const stat = fs.statSync(fp);
        if (stat.mtimeMs > bestMtime) { bestMtime = stat.mtimeMs; bestFile = fp; }
      }
    } catch (e) {}
  }

  if (bestFile && (Date.now() - bestMtime) < 10 * 60 * 1000) return bestFile;
  return null;
}

// === 解析 transcript ===
function parseTranscript(transcriptPath) {
  if (!transcriptPath) { debugLog('transcript_path is empty'); return null; }

  let actualPath = transcriptPath;
  if (!fs.existsSync(transcriptPath)) {
    debugLog(`transcript not found: ${transcriptPath}, trying fallback...`);
    actualPath = findFallbackTranscript(transcriptPath);
    if (!actualPath) { debugLog('fallback not found'); return null; }
    debugLog(`fallback found: ${actualPath}`);
  }

  const lines = fs.readFileSync(actualPath, 'utf-8').trim().split('\n');
  const userMessages = [];
  const toolsUsed = new Set();
  const filesModified = new Set();
  const toolCalls = [];

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      const entryType = entry.type;
      const msg = entry.message;
      if (!msg) continue;

      if (entryType === 'user' && msg.content) {
        const content = msg.content;
        const text = typeof content === 'string'
          ? content
          : Array.isArray(content)
            ? content.filter(c => c.type === 'text').map(c => c.text).join(' ')
            : '';
        const cleaned = text
          .replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, '')
          .replace(/<ide_[\s\S]*?>/g, '')
          .replace(/^The user opened the file[\s\S]*?$/gm, '')
          .trim();
        if (cleaned && cleaned.length > 0 && !cleaned.startsWith('<')) {
          userMessages.push(cleaned.substring(0, 200));
        }
      }

      if (entryType === 'assistant' && Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block.type === 'tool_use') {
            toolsUsed.add(block.name);
            const fp = block.input?.file_path || block.input?.path || block.input?.command || '';
            toolCalls.push({ name: block.name, target: typeof fp === 'string' ? path.basename(fp) : '', id: block.id });
            if (['Edit', 'Write'].includes(block.name) && block.input?.file_path) {
              filesModified.add(path.basename(block.input.file_path));
            }
          }
          if (block.type === 'tool_result' && block.content) {
            const resultText = typeof block.content === 'string'
              ? block.content
              : Array.isArray(block.content)
                ? block.content.filter(c => c.type === 'text').map(c => c.text).join(' ')
                : '';
            const lastCall = toolCalls[toolCalls.length - 1];
            if (lastCall) {
              lastCall.hasError = /error|Error|failed|Failed|not found|does not exist|TypeError|SyntaxError/.test(resultText);
              lastCall.resultSnippet = resultText.substring(0, 150);
            }
          }
        }
      }
    } catch (e) {}
  }

  return { userMessages, toolsUsed: [...toolsUsed], filesModified: [...filesModified], toolCalls };
}

// === 踩坑偵測 ===
function detectPitfalls(parsed) {
  if (!parsed?.toolCalls) return [];
  const pitfalls = [];
  const normalRepeatTools = new Set(['TodoWrite', 'Agent', 'Read', 'Grep', 'Glob', 'WebSearch', 'WebFetch']);

  const retryMap = new Map();
  for (const call of parsed.toolCalls) {
    if (normalRepeatTools.has(call.name)) continue;
    const key = `${call.name}:${call.target}`;
    retryMap.set(key, (retryMap.get(key) || 0) + 1);
  }
  for (const [key, count] of retryMap) {
    if (count >= 5) {
      const [tool, target] = key.split(':');
      pitfalls.push({ type: 'retry', description: `${tool} retried ${count} times on ${target || 'same target'}` });
    }
  }

  for (let i = 0; i < parsed.toolCalls.length; i++) {
    const call = parsed.toolCalls[i];
    if (!call.hasError) continue;
    for (let j = i + 1; j < parsed.toolCalls.length; j++) {
      const later = parsed.toolCalls[j];
      if (later.name === call.name && later.target === call.target && !later.hasError) {
        pitfalls.push({ type: 'error-then-fix', description: `${call.name} failed then succeeded on ${call.target}`, errorSnippet: call.resultSnippet });
        break;
      }
    }
  }

  const correctionKeywords = ['wrong', 'incorrect', 'not that', 'revert', 'undo', 'that\'s not'];
  for (const msg of parsed.userMessages) {
    if (correctionKeywords.some(kw => msg.toLowerCase().includes(kw))) {
      pitfalls.push({ type: 'user-correction', description: `User correction: ${msg.substring(0, 80)}` });
    }
  }

  return pitfalls;
}

// === 存踩坑紀錄 ===
function savePitfalls(pitfalls) {
  if (pitfalls.length === 0) return;
  ensureDir(LEARNED_DIR);

  const dateStr = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const slug = `auto-pitfall-${dateStr}`;
  let filename = `${slug}.md`;
  if (fs.existsSync(path.join(LEARNED_DIR, filename))) {
    filename = `${slug}-${Math.random().toString(36).substring(2, 5)}.md`;
  }

  const content = `# Pitfall Log ${new Date().toISOString().split('T')[0]}

## Detected Issues

${pitfalls.map(p => `### ${p.type}
- ${p.description}
${p.errorSnippet ? `- Error snippet: \`${p.errorSnippet}\`` : ''}`).join('\n\n')}

## Lesson

(Claude will read this at next session start as a reminder)
`;

  fs.writeFileSync(path.join(LEARNED_DIR, filename), content, 'utf-8');
  debugLog(`Pitfall log saved: ${filename} (${pitfalls.length} items)`);
}

// === 清理舊 session ===
function cleanOldSessions() {
  ensureDir(SESSIONS_DIR);
  const files = fs.readdirSync(SESSIONS_DIR)
    .filter(f => f.endsWith('-session.md'))
    .map(f => ({ name: f, path: path.join(SESSIONS_DIR, f), mtime: fs.statSync(path.join(SESSIONS_DIR, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);

  for (const old of files.slice(MAX_SESSIONS)) {
    try { fs.unlinkSync(old.path); } catch (e) {}
  }
}

// === 主程式 ===
function main(inputData) {
  debugLog('=== session-end start ===');

  try {
    let data;
    try { data = JSON.parse(inputData); } catch (e) { debugLog(`JSON parse error: ${e.message}`); return; }

    const transcriptPath = data.transcript_path;
    const parsed = parseTranscript(transcriptPath);
    if (!parsed || parsed.userMessages.length === 0) { debugLog('No user messages, skipping'); return; }

    ensureDir(SESSIONS_DIR);
    cleanOldSessions();

    const now = new Date();
    const dateStr = now.toISOString().split('T')[0];
    const timeStr = now.toTimeString().split(' ')[0].substring(0, 5);
    const shortId = Math.random().toString(36).substring(2, 6);
    const filename = `${dateStr}-${shortId}-session.md`;

    const projectTag = detectProjectTag(parsed.userMessages, data.cwd, parsed.filesModified);
    const recentMessages = parsed.userMessages.slice(-8);
    const titleHint = parsed.userMessages.filter(m => m.length > 3).slice(0, 5).join(' ').substring(0, 60).replace(/\n/g, ' ');

    const summary = `# Session: ${dateStr}
**Project:** ${projectTag}
**Title:** ${titleHint}
**Time:** ${timeStr}
**Messages:** ${parsed.userMessages.length}

## User Requests
${recentMessages.map(m => `- ${m}`).join('\n')}

## Tools Used
${parsed.toolsUsed.join(', ') || 'none'}

## Files Modified
${parsed.filesModified.length > 0 ? parsed.filesModified.map(f => `- ${f}`).join('\n') : 'none'}
`;

    fs.writeFileSync(path.join(SESSIONS_DIR, filename), summary, 'utf-8');
    debugLog(`Session summary saved: ${filename}`);

    // 踩坑偵測
    const pitfalls = detectPitfalls(parsed);
    if (pitfalls.length > 0) savePitfalls(pitfalls);

    // 嘗試自動備份（只 commit，不 push）
    try {
      const { execSync } = require('child_process');
      const backupScript = path.join(AGENT_DIR, 'scripts', 'hooks', 'memory-backup.sh');
      if (fs.existsSync(backupScript)) {
        execSync(`bash "${backupScript}"`, { timeout: 10000, stdio: 'ignore' });
        debugLog('Auto backup commit done');
      }
    } catch (e) { debugLog(`Auto backup failed (non-fatal): ${e.message}`); }

    debugLog('=== session-end complete ===');
  } catch (err) {
    debugLog(`Main error: ${err.message}\n${err.stack}`);
  }
}

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => main(input));
