#!/usr/bin/env node
/**
 * PostToolUse Hook — Claude Memory Engine (Gemini CLI)
 *
 * Gemini CLI does not write JSONL transcripts like Claude Code does.
 * This hook runs after every tool call and accumulates:
 *   - tools used (set)
 *   - files modified (set)
 *   - tool calls with error flags (for pitfall detection)
 *
 * State is written to ~/.claude/sessions/.gemini-tool-state.json
 * session-end.js reads this state when transcript_path is unavailable.
 */

const fs   = require('fs');
const path = require('path');

const HOME      = process.env.HOME || process.env.USERPROFILE;

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
const STATE_FILE = path.join(AGENT_DIR, 'sessions', '.gemini-tool-state.json');

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
    ensureDir(path.dirname(STATE_FILE));
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf-8');
  } catch (e) {}
}

// Gemini CLI tool names vary — normalise to canonical names
function normaliseTool(name) {
  if (!name) return 'Unknown';
  const n = String(name).toLowerCase();
  if (n.includes('edit') || n.includes('patch'))      return 'Edit';
  if (n.includes('write') || n.includes('create'))    return 'Write';
  if (n.includes('read') || n.includes('view'))       return 'Read';
  if (n.includes('bash') || n.includes('shell') || n.includes('run') || n.includes('exec')) return 'Bash';
  if (n.includes('search') || n.includes('grep'))     return 'Grep';
  if (n.includes('glob') || n.includes('find'))       return 'Glob';
  if (n.includes('web') || n.includes('fetch') || n.includes('http')) return 'WebFetch';
  // Return original name (title-cased) if unrecognised
  return name.charAt(0).toUpperCase() + name.slice(1);
}

// Extract file path from various Gemini tool input structures
function extractFilePath(toolInput) {
  if (!toolInput || typeof toolInput !== 'object') return null;
  return toolInput.file_path
    || toolInput.path
    || toolInput.filename
    || toolInput.filepath
    || null;
}

function main(inputData) {
  try {
    const data = JSON.parse(inputData);

    const sessionId  = data.session_id || data.sessionId || 'unknown';
    // Gemini PostToolUse payload fields
    const rawTool    = data.tool_name || data.tool || data.name || '';
    const toolInput  = data.tool_input || data.input || data.parameters || {};
    const toolOutput = data.tool_output || data.output || data.result || '';
    const success    = data.success !== false; // default true if not specified

    const tool     = normaliseTool(rawTool);
    const filePath = extractFilePath(toolInput);

    const outputStr = typeof toolOutput === 'string'
      ? toolOutput
      : JSON.stringify(toolOutput);
    const hasError  = !success || /error|Error|failed|Failed|not found|does not exist/i.test(outputStr);

    const state = loadState();

    if (!state[sessionId]) {
      state[sessionId] = {
        tools: [],
        files: [],
        toolCalls: [],
        lastActivity: new Date().toISOString()
      };
    }

    const session = state[sessionId];

    // Accumulate unique tools
    if (tool && !session.tools.includes(tool)) session.tools.push(tool);

    // Accumulate modified files (Write/Edit only)
    if (filePath && ['Write', 'Edit'].includes(tool)) {
      const base = path.basename(filePath);
      if (!session.files.includes(base)) session.files.push(base);
    }

    // Append tool call record (for pitfall detection in session-end.js)
    session.toolCalls.push({
      name:   tool,
      target: filePath ? path.basename(filePath) : '',
      id:     `${sessionId}-${session.toolCalls.length}`,
      hasError,
      resultSnippet: outputStr.substring(0, 150)
    });

    session.lastActivity = new Date().toISOString();

    // Keep state from growing unbounded: prune sessions older than 3 days
    const cutoff = Date.now() - 3 * 24 * 60 * 60 * 1000;
    for (const sid of Object.keys(state)) {
      if (sid === sessionId) continue;
      if (state[sid].lastActivity && new Date(state[sid].lastActivity).getTime() < cutoff) {
        delete state[sid];
      }
    }

    saveState(state);
  } catch (e) {
    // 靜默失敗 — hook failure must never break the user's workflow
  }
}

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => main(input));
