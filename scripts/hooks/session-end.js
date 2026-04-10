#!/usr/bin/env node
/**
 * SessionEnd Hook — Claude Memory Engine
 * 1. 儲存本次 session 工作摘要（供下次 session-start 載入）
 * 2. Auto-commit memory + experience 檔案到備份 repo（本地 commit，不 push）
 *
 * 注意：experience 的萃取是 AI 在 session 中主動做的事（/memory:experience save）
 * session-end 不嘗試自動萃取，因為這需要 LLM 理解，不是 script 能做的事
 */

const fs = require('fs');
const path = require('path');

const HOME      = process.env.HOME || process.env.USERPROFILE;
const AGENT_DIR = process.env.MEMORY_ENGINE_HOME || path.join(HOME, '.claude');
const SESSIONS_DIR = path.join(AGENT_DIR, 'sessions');
const DEBUG_LOG    = path.join(SESSIONS_DIR, 'debug.log');
const MAX_SESSIONS = 30;

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function debugLog(msg) {
  ensureDir(SESSIONS_DIR);
  fs.appendFileSync(DEBUG_LOG, `[${new Date().toISOString()}] ${msg}\n`, 'utf-8');
}

// === 從 CWD 推斷專案名稱 ===
function detectProjectTag(cwd) {
  const normalized = (cwd || process.cwd()).replace(/\\/g, '/');
  const parts = normalized.split('/').filter(Boolean);
  const lastDir = parts[parts.length - 1] || 'general';
  if (['Users', 'home', 'root'].some(p => lastDir.toLowerCase() === p.toLowerCase())) return 'general';
  return lastDir.toLowerCase();
}

// === 找 fallback transcript（Claude 專用）===
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

// === 解析 Claude JSONL transcript ===
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

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      const msg = entry.message;
      if (!msg) continue;

      if (entry.type === 'user' && msg.content) {
        const text = typeof msg.content === 'string'
          ? msg.content
          : Array.isArray(msg.content)
            ? msg.content.filter(c => c.type === 'text').map(c => c.text).join(' ')
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

      if (entry.type === 'assistant' && Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block.type === 'tool_use') {
            toolsUsed.add(block.name);
            if (['Edit', 'Write'].includes(block.name) && block.input?.file_path) {
              filesModified.add(path.basename(block.input.file_path));
            }
          }
        }
      }
    } catch (e) {}
  }

  return { userMessages, toolsUsed: [...toolsUsed], filesModified: [...filesModified] };
}

// === Gemini fallback: 從 checkpoint state 撈 messages ===
function loadFromCheckpointState(sessionId) {
  const stateFile = path.join(SESSIONS_DIR, '.checkpoint-state.json');
  try {
    if (!fs.existsSync(stateFile)) return null;
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));

    if (sessionId && state[sessionId]?.messages?.length > 0) return state[sessionId].messages;

    const sessions = Object.values(state)
      .filter(s => s.messages?.length > 0 && s.lastActivity)
      .sort((a, b) => new Date(b.lastActivity) - new Date(a.lastActivity));
    return sessions.length > 0 ? sessions[0].messages : null;
  } catch (e) { return null; }
}

// === Gemini fallback: 從 post-tool-logger state 撈 tool 資料 ===
function loadFromToolState(sessionId) {
  const stateFile = path.join(SESSIONS_DIR, '.gemini-tool-state.json');
  try {
    if (!fs.existsSync(stateFile)) return null;
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf-8'));

    if (sessionId && state[sessionId]) return state[sessionId];

    const sessions = Object.values(state)
      .filter(s => s.lastActivity)
      .sort((a, b) => new Date(b.lastActivity) - new Date(a.lastActivity));
    return sessions.length > 0 ? sessions[0] : null;
  } catch (e) { return null; }
}

// === 偵測呼叫來源 ===
function detectAgent(data) {
  if (data.transcript_path) return 'Claude Code';
  if (data.agent === 'gemini' || data.agent_name === 'gemini') return 'Gemini CLI';
  return 'Gemini CLI';
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

    const agentLabel = detectAgent(data);
    let parsed = parseTranscript(data.transcript_path);

    // Gemini fallback
    if (!parsed || parsed.userMessages.length === 0) {
      debugLog(`Transcript unavailable (${agentLabel}), trying checkpoint + tool state...`);

      const messages  = loadFromCheckpointState(data.session_id);
      const toolState = loadFromToolState(data.session_id);

      if (!messages || messages.length === 0) {
        debugLog('No messages found, skipping');
        return;
      }

      parsed = {
        userMessages:  messages,
        toolsUsed:     toolState?.tools  || [],
        filesModified: toolState?.files  || []
      };
      debugLog(`Gemini fallback: ${messages.length} msgs, ${parsed.toolsUsed.length} tools`);
    }

    ensureDir(SESSIONS_DIR);
    cleanOldSessions();

    const now = new Date();
    const dateStr  = now.toISOString().split('T')[0];
    const timeStr  = now.toTimeString().split(' ')[0].substring(0, 5);
    const shortId  = Math.random().toString(36).substring(2, 6);
    const filename = `${dateStr}-${shortId}-session.md`;

    const projectTag    = detectProjectTag(data.cwd);
    const recentMsgs    = parsed.userMessages.slice(-8);
    const titleHint     = parsed.userMessages.filter(m => m.length > 3).slice(0, 5).join(' ').substring(0, 60).replace(/\n/g, ' ');

    const summary = `# Session: ${dateStr}
**Project:** ${projectTag}
**Agent:** ${agentLabel}
**Title:** ${titleHint}
**Time:** ${timeStr}
**Messages:** ${parsed.userMessages.length}

## User Requests
${recentMsgs.map(m => `- ${m}`).join('\n')}

## Tools Used
${parsed.toolsUsed.join(', ') || 'none'}

## Files Modified
${parsed.filesModified.length > 0 ? parsed.filesModified.map(f => `- ${f}`).join('\n') : 'none'}
`;

    fs.writeFileSync(path.join(SESSIONS_DIR, filename), summary, 'utf-8');
    debugLog(`Session summary saved: ${filename} (${agentLabel})`);

    // 標記「待經驗回顧」— session-start 下次開始時注入給 AI 自動處理
    // 只有 substantial session 才標記（訊息數 >= 5 或有檔案異動）
    const hasFileMods = parsed.filesModified.length > 0;
    const msgCount    = parsed.userMessages.length;
    if (msgCount >= 5 || hasFileMods) {
      const pendingFile = path.join(SESSIONS_DIR, '.pending-experience-review.json');
      fs.writeFileSync(pendingFile, JSON.stringify({
        sessionFile:  filename,
        date:         dateStr,
        project:      projectTag,
        agent:        agentLabel,
        messageCount: msgCount,
        hasFileMods
      }, null, 2), 'utf-8');
      debugLog(`Pending experience review flagged: ${filename}`);
    }

    // Auto-commit memory + experiences（本地 commit，不 push）
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
