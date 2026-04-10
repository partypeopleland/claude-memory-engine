#!/usr/bin/env node
/**
 * UserPromptSubmit Hook — Claude Memory Engine
 * 每 N 次使用者訊息，自動存一份中繼摘要到 sessions/
 * 解決 SessionEnd 在 VSCode 環境下不可靠的問題
 */

const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME || process.env.USERPROFILE;
const AGENT_DIR = process.env.MEMORY_ENGINE_HOME || path.join(HOME, '.claude');
const SESSIONS_DIR = path.join(AGENT_DIR, 'sessions');
const STATE_FILE = path.join(SESSIONS_DIR, '.checkpoint-state.json');
const CHECKPOINT_INTERVAL = 20;

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) return JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'));
  } catch (e) {}
  return {};
}

function saveState(state) {
  try {
    ensureDir(SESSIONS_DIR);
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf-8');
  } catch (e) {}
}

function saveCheckpoint(sessionId, messages) {
  ensureDir(SESSIONS_DIR);

  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const timeStr = now.toTimeString().split(' ')[0].substring(0, 5);
  const shortId = sessionId ? sessionId.substring(0, 8) : Math.random().toString(36).substring(2, 6);
  const filename = `${dateStr}-${shortId}-checkpoint.md`;
  const titleHint = messages.slice(0, 3).join(' ').replace(/\n/g, ' ').substring(0, 50);
  const recentMessages = messages.slice(-10);

  const content = `# Checkpoint: ${dateStr}
**Title:** ${titleHint}
**Time:** ${timeStr}
**Total messages:** ${messages.length}
**Type:** Mid-session checkpoint (auto, every ${CHECKPOINT_INTERVAL} messages)

## Recent Requests (last ${recentMessages.length})
${recentMessages.map(m => `- ${m}`).join('\n')}
`;

  fs.writeFileSync(path.join(SESSIONS_DIR, filename), content, 'utf-8');

  try {
    const checkpoints = fs.readdirSync(SESSIONS_DIR)
      .filter(f => f.endsWith('-checkpoint.md'))
      .map(f => ({ name: f, path: path.join(SESSIONS_DIR, f), mtime: fs.statSync(path.join(SESSIONS_DIR, f)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    for (const old of checkpoints.slice(10)) {
      try { fs.unlinkSync(old.path); } catch (e) {}
    }
  } catch (e) {}
}

function main(inputData) {
  try {
    let data;
    try { data = JSON.parse(inputData); } catch (e) { return; }

    const sessionId = data.session_id || data.sessionId || 'unknown';
    // Claude Code: data.prompt / Gemini CLI: data.prompt or data.user_message
    const prompt = (data.prompt || data.user_message || data.message || '').trim().substring(0, 200);
    if (!prompt) return;

    const state = loadState();
    if (!state[sessionId]) {
      state[sessionId] = { messages: [], lastCheckpoint: 0, startTime: new Date().toISOString() };
    }

    const session = state[sessionId];
    session.messages.push(prompt);
    session.lastActivity = new Date().toISOString();

    if ((session.messages.length - session.lastCheckpoint) >= CHECKPOINT_INTERVAL) {
      saveCheckpoint(sessionId, session.messages);
      session.lastCheckpoint = session.messages.length;
    }

    const threeDaysAgo = Date.now() - 3 * 24 * 60 * 60 * 1000;
    for (const sid of Object.keys(state)) {
      if (sid === sessionId) continue;
      const s = state[sid];
      if (s.lastActivity && new Date(s.lastActivity).getTime() < threeDaysAgo) delete state[sid];
    }

    saveState(state);
  } catch (err) {
    // 靜默失敗
  }
}

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => main(input));
