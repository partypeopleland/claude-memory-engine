#!/usr/bin/env node
/**
 * UserPromptSubmit Hook — Claude Memory Engine
 * Logs user-typed slash command invocations to ~/.claude/skill-usage.log
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const logDir   = path.join(os.homedir(), '.claude');
const logFile  = path.join(logDir, 'skill-usage.log');
const debugFile = path.join(logDir, 'skill-usage.debug');

function debugLog(msg) {
  try { fs.appendFileSync(debugFile, `${new Date().toISOString()} [user] ${msg}\n`, 'utf8'); } catch (_) {}
}

async function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    const rl = readline.createInterface({ input: process.stdin });
    rl.on('line', line => (data += line + '\n'));
    rl.on('close', () => resolve(data.trim()));
    rl.on('error', reject);
  });
}

async function main() {
  const raw = await readStdin();
  let payload;
  try { payload = JSON.parse(raw); } catch (e) { debugLog(`JSON parse error: ${e.message}`); process.exit(0); }

  const prompt = (payload?.prompt ?? '').trimStart();
  if (!prompt.startsWith('/')) process.exit(0);

  const match = prompt.match(/^\/([^\s]+)(?:\s+(.*))?$/s);
  if (!match) process.exit(0);

  const skill = match[1];
  const args  = (match[2] ?? '').trim();

  const now = new Date(Date.now() + 8 * 60 * 60 * 1000);
  const timestamp = now.toISOString().replace('T', ' ').replace(/\.\d+Z$/, '').replace(/-/g, '').slice(0, 17);

  const logRecord = { v: 2, kind: 'skill-usage', timestamp, username: os.userInfo().username, source: 'user', skill, args: String(args) };
  fs.mkdirSync(logDir, { recursive: true });
  fs.appendFileSync(logFile, `${JSON.stringify(logRecord)}\n`, 'utf8');
}

main().catch(err => { process.exit(0); });
