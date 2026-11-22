// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// Copies what several html files must share from its one source, so nothing drifts:
//   json/tokens.json            → every /*TOKENS:BEGIN*/…/*TOKENS:END*/ literal
//   html/main.html’s <helmet>   → html/Foundations-Components.dc.html’s <helmet>
//   html/main.html’s var ICON   → html/Foundations-Components.dc.html
//   html/main.html’s SHORTCUTS  → html/Layout.dc.html
// Run it after changing any source: node tools/sync.mjs. tools/check.mjs fails while a copy differs.

import { readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { HTML, JSON_DIR, read } from './dc.mjs';

export function shared(mainText) {
  return {
    helmet: /<helmet>\n([\s\S]*?)\n<\/helmet>/.exec(mainText)[1],
    icon: /(var ICON = \{[\s\S]*?\n\};)/.exec(mainText)[1],
    shortcuts: /(var SHORTCUTS = \[[\s\S]*?\n\];)/.exec(mainText)[1]
  };
}

const tokens = JSON.parse(read(join(JSON_DIR, 'tokens.json')));
const literal = `/*TOKENS:BEGIN*/var TOKENS = ${JSON.stringify(tokens)};/*TOKENS:END*/`;
const main = shared(read(join(HTML, 'main.html')));
const copies = {
  'Foundations-Components.dc.html': [
    [/<helmet>\n[\s\S]*?\n<\/helmet>/, `<helmet>\n${main.helmet}\n</helmet>`],
    [/ICON_FROM_MAIN|var ICON = \{[\s\S]*?\n\};/, main.icon]
  ],
  'Layout.dc.html': [[/var SHORTCUTS = \[[\s\S]*?\n\];/, main.shortcuts]]
};
let changed = 0;
for (const f of readdirSync(HTML).filter((n) => n.endsWith('.html'))) {
  const path = join(HTML, f);
  const text = read(path);
  let next = text.replace(/\/\*TOKENS:BEGIN\*\/[\s\S]*?\/\*TOKENS:END\*\//, () => literal);
  for (const [re, value] of copies[f] || []) next = next.replace(re, () => value);
  if (next !== text) { writeFileSync(path, next); changed++; console.log(`updated html/${f}`); }
}
console.log(changed ? `${changed} file(s) updated` : 'every copy already matches its source');
