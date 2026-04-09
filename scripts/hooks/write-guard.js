#!/usr/bin/env node
/**
 * PreToolUse Hook — Claude Memory Engine
 * Warns before writing to sensitive files
 */

const path = require('path');

const PROTECTED_PATTERNS = [
  { pattern: /\.env$/, reason: 'May contain API keys or passwords' },
  { pattern: /credentials/i, reason: 'Filename contains credentials' },
  { pattern: /\.secret/i, reason: 'Filename contains secret' },
  { pattern: /password/i, reason: 'Filename contains password' },
];

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const filePath = data.tool_input?.file_path || '';
    const filename = path.basename(filePath);
    const normalizedPath = filePath.replace(/\\/g, '/');

    const ALLOWED_PATHS = [/\.cloudflare\//i];
    const isAllowed = ALLOWED_PATHS.some(p => p.test(normalizedPath));

    for (const { pattern, reason } of PROTECTED_PATTERNS) {
      if (pattern.test(filename) && !isAllowed) {
        process.stdout.write(`[Memory Engine] Writing ${filename} — ${reason}\n`);
      }
    }

    process.exit(0);
  } catch (e) {
    process.exit(0);
  }
});
