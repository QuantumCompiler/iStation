// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// Moves the design between the repository and the canvas’s file layout.
//   node tools/mirror.mjs --to <dir>     stage the repository’s files as <dir>/project/… for a publish
//   node tools/mirror.mjs --from <dir>   take <dir>/project/… (a canvas read down) back into html/ and json/
// The path map is README.md’s. html/support.js is repo-only: it is never staged, and a canvas
// support.js is never taken back.

import { copyFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { HTML, JSON_DIR, boards } from './dc.mjs';

const [flag, dir] = process.argv.slice(2);
if (!['--to', '--from'].includes(flag) || !dir) {
  console.error('usage: node tools/mirror.mjs --to <dir> | --from <dir>');
  process.exit(2);
}
const project = join(dir, 'project');

function pairs(names) {
  return [
    [join(HTML, 'main.html'), join(project, 'Main.dc.html')],
    [join(JSON_DIR, 'canvas.json'), join(project, 'canvas.json')],
    [join(JSON_DIR, 'tokens.json'), join(project, 'tokens.json')],
    ...names.map((f) => [join(HTML, f), join(project, f)])
  ];
}

if (flag === '--to') {
  mkdirSync(project, { recursive: true });
  for (const [repo, canvas] of pairs(boards())) copyFileSync(repo, canvas);
  console.log(`staged ${boards().length + 3} files in ${project}`);
} else {
  if (!existsSync(project)) { console.error(`no ${project}`); process.exit(2); }
  const names = readdirSync(project).filter((f) => f.endsWith('.dc.html') && f !== 'Main.dc.html');
  for (const [repo, canvas] of pairs(names)) if (existsSync(canvas)) copyFileSync(canvas, repo);
  console.log(`took ${names.length + 3} files back from ${project}; run node tools/check.mjs`);
}
