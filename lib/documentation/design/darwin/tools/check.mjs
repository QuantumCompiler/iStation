// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// The design's check. From the repository root:
//   node lib/documentation/design/darwin/tools/check.mjs            the logic and file checks
//   node lib/documentation/design/darwin/tools/check.mjs --render   also every board in headless Chrome
//
// It fails on: tokens that differ from json/tokens.json, a text pair under its contrast minimum, a
// hex color or emoji outside the tokens, any start preset that throws or renders undefined or NaN in
// its first 30 clock ticks, a scripted flow that doesn't end where it should, a shortcut that no key
// reaches, a contract id the prototype names but the Contract page lacks, a board that mounts an
// unknown preset or a preset with no board, and canvas.json out of step with the files.

import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtempSync, existsSync, statSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname, normalize } from 'node:path';
import { ROOT, HTML, JSON_DIR, read, boards, parts, evaluate, parseMarkup, renderLogic, scanValues, contrast } from './dc.mjs';

const failures = [];
const notes = [];
const fail = (m) => failures.push(m);
const deepEqual = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/* ---- tokens and contrast ---- */
const tokens = JSON.parse(read(join(JSON_DIR, 'tokens.json')));
const mainText = read(join(HTML, 'main.html'));
const main = parts(mainText);
const M = evaluate(main.script, ['TOKENS', 'PRESETS', 'PRESET_NAMES', 'initialState', 'advance', 'reduce', 'view', 'keyAction', 'SHORTCUTS', 'Component', 'canPlay', 'gameById']);
if (!deepEqual(M.TOKENS, tokens)) fail('html/main.html: TOKENS differs from json/tokens.json (run node tools/sync.mjs)');
let pairs = 0;
for (const theme of tokens.themes) {
  for (const p of tokens.contrastPairs) {
    const r = contrast(tokens.color[theme][p.fg], tokens.color[theme][p.bg]);
    pairs++;
    if (r < p.min) fail(`contrast: ${theme} ${p.fg} on ${p.bg} is ${r.toFixed(2)}:1, under ${p.min}:1`);
  }
}
notes.push(`${pairs} color pairs meet their contrast minimum`);

/* ---- copies kept by tools/sync.mjs ---- */
const sharedOf = (t) => ({
  helmet: (/<helmet>\n([\s\S]*?)\n<\/helmet>/.exec(t) || [])[1],
  icon: (/(var ICON = \{[\s\S]*?\n\};)/.exec(t) || [])[1],
  shortcuts: (/(var SHORTCUTS = \[[\s\S]*?\n\];)/.exec(t) || [])[1]
});
const mainShared = sharedOf(mainText);
for (const [f, keys] of [['Foundations-Components.dc.html', ['helmet', 'icon']], ['Layout.dc.html', ['shortcuts']]]) {
  if (!existsSync(join(HTML, f))) { fail(`html/${f} is missing`); continue; }
  const other = sharedOf(read(join(HTML, f)));
  for (const k of keys) if (other[k] !== mainShared[k]) fail(`html/${f}: its ${k} differs from html/main.html’s (run node tools/sync.mjs)`);
}
for (const f of boards()) {
  const lit = /\/\*TOKENS:BEGIN\*\/var TOKENS = ([\s\S]*?);\/\*TOKENS:END\*\//.exec(read(join(HTML, f)));
  if (lit && !deepEqual(JSON.parse(lit[1]), tokens)) fail(`html/${f}: TOKENS differs from json/tokens.json (run node tools/sync.mjs)`);
}

/* ---- every html file: format basics, no hex colors outside the tokens, no emoji ---- */
const files = ['main.html', ...boards()];
for (const f of files) {
  const text = read(join(HTML, f));
  if (!text.includes('<script src="./support.js"></script>')) fail(`html/${f}: the support.js head line is missing or changed`);
  if (!/<script type="text\/x-dc" data-dc-script/.test(text)) fail(`html/${f}: no data-dc-script block`);
  if (!/class Component extends DCLogic/.test(text)) fail(`html/${f}: no class Component extends DCLogic`);
  const withoutTokens = text.replace(/\/\*TOKENS:BEGIN\*\/[\s\S]*?\/\*TOKENS:END\*\//g, '');
  const hex = withoutTokens.match(/#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\b|#[0-9a-fA-F]{3}\b/g);
  if (hex) fail(`html/${f}: hex colors outside the tokens: ${[...new Set(hex)].slice(0, 5).join(', ')}`);
  const emoji = withoutTokens.match(/\p{Emoji_Presentation}/gu);
  if (emoji) fail(`html/${f}: emoji: ${[...new Set(emoji)].join(' ')}`);
  try { parseMarkup(parts(text).markup); } catch (e) { fail(`html/${f}: ${e.message}`); }
}

/* ---- the prototype at every start preset, through 30 clock ticks ---- */
const tree = parseMarkup(main.markup);
const refs = { root() {}, search() {}, noop() {}, onKey() {} };
const vw = (s) => M.view(s, () => {}, refs);
const presetNames = Object.keys(M.PRESETS);
if (!deepEqual([...presetNames].sort(), [...M.PRESET_NAMES].sort())) fail('PRESET_NAMES and PRESETS list different presets');
const contractRefs = new Set();
let renders = 0, holes = 0;
function renderCheck(s, label) {
  let vals;
  try { vals = vw(s); } catch (e) { fail(`${label}: view() threw ${e.message}`); return null; }
  for (const p of scanValues(vals).slice(0, 3)) fail(`${label}: ${p}`);
  const r = renderLogic(tree, vals);
  r.problems.slice(0, 5).forEach((p) => fail(`${label}: ${p}`));
  r.contracts.forEach((c) => contractRefs.add(c));
  renders++; holes += r.holes;
  return { vals, text: r.text };
}
for (const name of presetNames) {
  let s;
  try { s = M.initialState({ start: name, still: true }); } catch (e) { fail(`preset ${name}: initialState threw ${e.message}`); continue; }
  for (let t = 0; t <= 30; t++) {
    renderCheck(s, `preset ${name} tick ${t}`);
    try { s = M.advance(s); } catch (e) { fail(`preset ${name} tick ${t}: advance threw ${e.message}`); break; }
  }
  try { const c = new M.Component({ start: name, still: true }); c.renderVals(); } catch (e) { fail(`preset ${name}: the component threw ${e.message}`); }
}
notes.push(`${presetNames.length} presets × 31 ticks: ${renders} renders, ${holes} holes evaluated`);

/* ---- scripted flows ---- */
const R = (s, a, label) => { const n = M.reduce(s, a); renderCheck(n, label + ' after ' + a.type); return n; };
function until(s, pred, label, max = 300) {
  for (let i = 0; i < max && !pred(s); i++) { s = M.advance(s); if (i % 5 === 0) renderCheck(s, label + ' while waiting'); }
  if (!pred(s)) throw new Error(`${label}: never reached its end state`);
  return s;
}
const flows = [];
function flow(name, body) { try { body(); flows.push(name); } catch (e) { fail(`flow "${name}": ${e.message}`); } }
function expect(cond, what) { if (!cond) throw new Error(what); }

flow('first run: a wrong-size file and one that never reaches its shell are refused, then the BIOS checks out', () => {
  let s = M.initialState({ start: 'welcome', still: true });
  s = R(s, { type: 'pick', purpose: 'bios' }, 'first run');
  s = R(s, { type: 'pickToggle', name: 'bios-backup.zip' }, 'first run');
  s = R(s, { type: 'pickOpen' }, 'first run');
  s = until(s, (x) => x.job && x.job.status !== 'running', 'wrong BIOS');
  expect(s.job.status === 'failed', 'the wrong-size file was not refused');
  expect(vw(s).job.summary.includes('271,384'), 'the refusal does not give the file’s size');
  expect(vw(s).job.raw.includes('biosSize(271384)'), 'the refusal does not show the backend’s error');
  s = R(s, { type: 'pick', purpose: 'bios' }, 'first run');
  s = R(s, { type: 'pickToggle', name: 'bios-copy.bin' }, 'first run');
  s = R(s, { type: 'pickOpen' }, 'first run');
  s = until(s, (x) => x.job && x.job.status !== 'running', 'no-shell BIOS');
  expect(s.job.status === 'failed' && s.job.step === 4, 'a BIOS that never reaches its shell was not refused at its last step');
  expect(s.job.n === 600, `the no-shell BIOS was refused at frame ${s.job.n}, not 600`);
  expect(!s.bios, 'a BIOS that never reached its shell was kept');
  expect(vw(s).job.summary === 'Your BIOS powered on but didn’t reach its shell in 600 frames. Choose another file.', 'the no-shell refusal does not say the decided words');
  expect(vw(s).job.raw.includes('reachedShell') && vw(s).job.raw.includes('0x80030000') && vw(s).job.raw.includes('frame 600'), 'the no-shell refusal does not show the shell unreached by frame 600');
  s = R(s, { type: 'pick', purpose: 'bios' }, 'first run');
  s = R(s, { type: 'pickOpenFile', name: 'my-console-bios.bin' }, 'first run');
  s = until(s, (x) => x.job && x.job.status === 'done', 'right BIOS');
  expect(!!s.bios && s.bios.file === 'my-console-bios.bin', 'the BIOS that checked out was not the one kept');
  s = R(s, { type: 'closeSheet' }, 'first run');
  expect(vw(s).lib.empty && vw(s).screen.games, 'the empty library did not follow');
});

flow('add a folder: the scan job runs, stops, resumes and finishes without duplicates', () => {
  let s = M.initialState({ start: 'library-empty', still: true });
  s = R(s, { type: 'pick', purpose: 'folder' }, 'scan');
  s = R(s, { type: 'pickOpenFile', name: 'Games' }, 'scan');
  s = until(s, (x) => x.job.n >= 3, 'scan partway');
  s = R(s, { type: 'stopJob' }, 'scan');
  expect(s.job.status === 'stopped', 'Stop did not stop the scan');
  expect(vw(s).job.summary.startsWith('Stopped after'), 'the stopped job does not say so');
  s = R(s, { type: 'rescan' }, 'scan');
  s = until(s, (x) => x.job.status === 'done', 'scan again');
  expect(s.games.length === 4, `expected 4 games after the scan, found ${s.games.length}`);
  expect(new Set(s.games.map((g) => g.id)).size === s.games.length, 'the rescan added a game twice');
  expect(vw(s).job.results.length === 9, 'not every file has a result');
  s = R(s, { type: 'closeSheet' }, 'scan');
  expect(vw(s).lib.list, 'the list did not appear');
});

flow('play: open, run, pause, save, replace, refuse an old save, reset and stop', () => {
  let s = M.initialState({ start: 'library', still: true });
  s = R(s, { type: 'play', id: 'g1' }, 'play');
  expect(s.job && s.job.kind === 'open', 'Play did not start the opening job');
  s = until(s, (x) => x.screen === 'player', 'opening');
  const f0 = s.player.frame; s = M.advance(M.advance(s));
  expect(s.player.frame > f0, 'frames did not advance while running');
  s = R(s, { type: 'togglePause' }, 'play');
  const f1 = s.player.frame; s = M.advance(s);
  expect(s.player.frame === f1, 'frames advanced while paused');
  s = R(s, { type: 'states', mode: 'save' }, 'play');
  expect(s.states.sel === 3, 'Save State did not pick the first empty slot');
  s = R(s, { type: 'slotCommit' }, 'play');
  expect(s.slots[2].saved === 'Just now' && !s.sheet, 'saving to an empty slot failed');
  s = R(s, { type: 'states', mode: 'save' }, 'play');
  s = R(s, { type: 'slotCommitAt', n: 1 }, 'play');
  expect(s.dialog && s.dialog.kind === 'overwrite', 'replacing a save did not ask first');
  expect(vw(s).dialog.details.includes('saveState()'), 'the replace dialog does not show the call');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'play');
  expect(s.slots[0].saved === 'Just now', 'the replace did not save');
  s = R(s, { type: 'states', mode: 'load' }, 'play');
  s = R(s, { type: 'slotCommitAt', n: 5 }, 'play');
  expect(s.dialog.kind === 'version', 'an old-format save was not refused');
  s = R(s, { type: 'confirm', choice: 'cancel' }, 'play');
  s = R(s, { type: 'closeSheet' }, 'play');
  s = R(s, { type: 'ask', kind: 'reset' }, 'play');
  expect(vw(s).dialog.details.includes('powerOn(bios:)'), 'the reset dialog does not show the call');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'play');
  expect(s.player.frame === 0 && s.player.status === 'running', 'reset did not restart at frame 0');
  s = R(s, { type: 'ask', kind: 'stop' }, 'play');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'play');
  expect(s.screen === 'library' && !s.player, 'stop did not return to the library');
});

flow('refusals: a PS2 disc, a missing file located, a removal', () => {
  let s = M.initialState({ start: 'library', still: true });
  s = R(s, { type: 'play', id: 'g6' }, 'refuse');
  expect(s.dialog.kind === 'ps2' && !s.job, 'a PS2 disc was not refused');
  s = R(s, { type: 'cancelDialog' }, 'refuse');
  s = R(s, { type: 'play', id: 'g7' }, 'refuse');
  expect(s.dialog.kind === 'missing', 'a missing file was not caught');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'refuse');
  expect(s.picker && s.picker.purpose === 'locate', 'Locate did not open the picker');
  s = R(s, { type: 'pickOpen' }, 'refuse');
  expect(M.gameById(s, 'g7').access === 'ok', 'locating did not restore access');
  s = R(s, { type: 'ask', kind: 'remove', id: 'g4' }, 'refuse');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'refuse');
  expect(!M.gameById(s, 'g4'), 'remove did not remove');
});

flow('memory cards: move one to the Trash after confirming', () => {
  let s = M.initialState({ start: 'cards', still: true });
  s = R(s, { type: 'ask', kind: 'card-delete', id: 'c3' }, 'cards');
  expect(vw(s).dialog.details.includes('trashItem'), 'the delete dialog does not show the call');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'cards');
  expect(!s.cards.some((c) => c.id === 'c3') && s.toast, 'the card was not moved to the Trash');
});

flow('personal tools: record a trace, stop one, compare two', () => {
  let s = M.initialState({ start: 'tools-console', still: true });
  s = R(s, { type: 'toolsTab', tab: 'trace' }, 'trace');
  s = R(s, { type: 'traceStart' }, 'trace');
  s = until(s, (x) => x.job.status === 'done', 'trace');
  expect(vw(s).job.raw.startsWith('[istation-run] 60 frames'), 'the trace result is not the recorded output');
  s = R(s, { type: 'closeSheet' }, 'trace');
  s = R(s, { type: 'traceStart' }, 'trace');
  s = until(s, (x) => x.job.n > 6, 'trace partway');
  s = R(s, { type: 'stopJob' }, 'trace');
  expect(vw(s).job.summary.includes('can’t be resumed'), 'a stopped trace does not say it can’t resume');
  s = R(s, { type: 'closeSheet' }, 'trace');
  s = R(s, { type: 'toolsTab', tab: 'compare' }, 'trace');
  s = R(s, { type: 'compare' }, 'trace');
  expect(vw(s).tools.diff.text.startsWith('first divergence at record 0'), 'the comparison is not the recorded output');
});

flow('today: discs can’t play, a PS-EXE plays and resets, the BIOS runs without a picture', () => {
  let s = M.initialState({ start: 'today-library', still: true });
  expect(!M.canPlay(s, M.gameById(s, 'g1')).ok, 'a disc can play in today’s build');
  expect(vw(s).insp.reason.includes('v0.2.0'), 'the reason Play is off is missing');
  const exe = M.gameById(s, 'g5');
  expect(exe && exe.format === 'exe' && M.canPlay(s, exe).ok, 'a PS-EXE can’t play in today’s build');
  let p = R(s, { type: 'play', id: 'g5' }, 'today exe');
  expect(p.job && p.job.kind === 'open', 'Play did not start the PS-EXE’s opening job');
  expect(vw(p).job.steps.length === 3, `the PS-EXE’s opening job has ${vw(p).job.steps.length} steps, not 3`);
  expect(vw(p).job.contract === 'C11 C18 C01 C19', `the PS-EXE’s opening job names ${vw(p).job.contract}`);
  p = until(p, (x) => x.screen === 'player', 'today exe opening');
  p = R(p, { type: 'ask', kind: 'reset' }, 'today exe');
  expect(vw(p).dialog.details.includes('powerOn(bios:)') && vw(p).dialog.details.includes('boot(exe:) with ' + exe.file), 'the PS-EXE’s reset dialog does not power on and boot it again');
  expect(vw(p).dialog.contract === 'C06 C19', `the PS-EXE’s reset dialog names ${vw(p).dialog.contract}`);
  p = R(p, { type: 'confirm', choice: 'ok' }, 'today exe');
  expect(p.player.frame === 0 && p.player.status === 'running', 'reset did not restart the PS-EXE at frame 0');
  s = R(s, { type: 'nav', id: 'bios' }, 'today');
  s = R(s, { type: 'runBios' }, 'today');
  expect(vw(s).player.noPicture && !vw(s).player.picture, 'today’s player draws a picture');
  s = M.advance(s);
  expect(s.player.frame === 6, 'the BIOS frame counter did not advance');
});

flow('iOS: play turns the phone to landscape, and pause offers the menu', () => {
  let s = M.initialState({ start: 'ios-library', still: true });
  s = R(s, { type: 'play', id: 'g1' }, 'ios');
  s = until(s, (x) => x.screen === 'player', 'ios opening');
  expect(s.w === 844 && s.h === 390, 'the player did not turn to landscape');
  s = R(s, { type: 'iosPause' }, 'ios');
  expect(vw(s).pause.items.length === 5, 'the pause menu is incomplete');
  s = R(s, { type: 'ask', kind: 'stop' }, 'ios');
  s = R(s, { type: 'confirm', choice: 'ok' }, 'ios');
  expect(s.w === 390 && s.screen === 'library', 'quitting did not return to the portrait library');
});
notes.push(`${flows.length} scripted flows passed`);

/* ---- every shortcut reaches an action where it applies ---- */
const contextFor = (group, label) => {
  if (label.startsWith('Close')) return 'shortcuts';
  if (label.startsWith('Stop the running job')) return 'scan-running';
  if (label.includes('personal build')) return group === 'Playing' ? 'player-debug' : 'tools-console';
  if (label === 'Memory Cards' || label === 'BIOS') return 'library';
  return { Library: 'library', Playing: 'player-running', Windows: 'library', 'Jobs and tools': 'tools-console' }[group];
};
function eventsFor(key) {
  const mods = { metaKey: key.includes('⌘'), shiftKey: key.includes('⇧'), altKey: key.includes('⌥'), ctrlKey: key.includes('⌃') };
  const base = key.replace(/[⌘⇧⌥⌃]/g, '');
  const names = { '↩': ['Enter'], '↑ ↓': ['ArrowUp', 'ArrowDown'], '⌫': ['Backspace'], 'Esc': ['Escape'], ',': [','], '.': ['.'], '/': ['/'] };
  return (names[base] || [base.toLowerCase()]).map((k) => ({ ...mods, key: k }));
}
let keys = 0;
for (const g of M.SHORTCUTS) for (const [label, key] of g.items) {
  keys++;
  const ctx = M.initialState({ start: contextFor(g.title, label), still: true });
  for (const e of eventsFor(key)) {
    const a = M.keyAction(ctx, e);
    if (!a) { fail(`shortcut "${label}" (${key}) does nothing in ${contextFor(g.title, label)}`); continue; }
    try { renderCheck(M.reduce(ctx, a), `shortcut "${label}"`); } catch (err) { fail(`shortcut "${label}": ${err.message}`); }
  }
}
notes.push(`${keys} keyboard shortcuts each act where they apply`);

/* ---- the contract ---- */
const contractPath = join(HTML, 'Contract.dc.html');
if (existsSync(contractPath)) {
  const C = evaluate(parts(read(contractPath)).script, ['ROWS', 'GAPS', 'DECISIONS', 'CALLS']);
  const ids = new Set(C.ROWS.map((r) => r.id));
  const gapIds = new Set(C.GAPS.map((g) => g.id));
  const tags = { ready: 0, app: 0, gap: 0, verify: 0 };
  for (const r of C.ROWS) {
    if (!(r.tag in tags)) fail(`contract ${r.id}: unknown tag ${r.tag}`); else tags[r.tag]++;
    if (r.gap && !gapIds.has(r.gap)) fail(`contract ${r.id}: names ${r.gap}, which isn't a gap`);
    if (r.tag === 'gap' && !r.gap) fail(`contract ${r.id}: tagged gap without a gap number`);
  }
  for (const g of C.GAPS) if (!C.ROWS.some((r) => r.gap === g.id)) fail(`contract: ${g.id} is closed by no row`);
  for (const id of contractRefs) if (!ids.has(id)) fail(`html/main.html names contract row ${id}, which the Contract page lacks`);
  const unused = [...ids].filter((id) => !contractRefs.has(id));
  notes.push(`contract: ${C.ROWS.length} rows (${tags.ready} ready, ${tags.app} app, ${tags.gap} gap, ${tags.verify} verify), ${C.GAPS.length} gaps; the prototype marks ${contractRefs.size} of them${unused.length ? `, not ${unused.join(' ')}` : ''}`);
} else fail('html/Contract.dc.html is missing');

/* ---- boards and canvas.json ---- */
const used = new Set();
for (const f of boards()) {
  const p = parts(read(join(HTML, f)));
  for (const m of p.markup.matchAll(/<dc-import name="Main"([^>]*)>/g)) {
    const start = /start="([^"]+)"/.exec(m[1]);
    if (!start) { fail(`html/${f}: mounts Main without a start preset`); continue; }
    if (!M.PRESETS[start[1]]) fail(`html/${f}: start="${start[1]}" is no preset`);
    if (!/still="\{\{ true \}\}"/.test(m[1])) fail(`html/${f}: mounts Main with the clock running`);
    used.add(start[1]);
  }
  try {
    const B = evaluate(p.script, ['Component']);
    const inst = new B.Component({});
    const vals = inst.renderVals ? inst.renderVals() : {};
    for (const q of scanValues(vals).slice(0, 3)) fail(`html/${f}: ${q}`);
    renderLogic(parseMarkup(p.markup), vals).problems.slice(0, 5).forEach((q) => fail(`html/${f}: ${q}`));
  } catch (e) { fail(`html/${f}: its logic threw ${e.message}`); }
}
for (const n of presetNames) if (!used.has(n)) fail(`preset ${n} has no board`);
const canvas = JSON.parse(read(join(JSON_DIR, 'canvas.json')));
const expected = new Set(['Main.dc.html', ...boards()]);
const listed = new Set(Object.keys(canvas.boards));
for (const f of expected) if (!listed.has(f)) fail(`canvas.json: no board entry for ${f}`);
for (const f of listed) if (!expected.has(f)) fail(`canvas.json: lists ${f}, which has no file`);
if (!deepEqual([...canvas.order].sort(), [...listed].sort())) fail('canvas.json: order and boards list different files');
const pageIds = new Set((canvas.pages || []).map((p) => p.id));
for (const [f, b] of Object.entries(canvas.boards)) if (b.page && !pageIds.has(b.page)) fail(`canvas.json: ${f} is on an unknown page ${b.page}`);
notes.push(`${boards().length} boards, every preset mounted by one`);

/* ---- headless Chrome: every board and every preset, rendered for real ---- */
if (process.argv.includes('--render')) await renderInChrome();

console.log(notes.map((n) => '  ok  ' + n).join('\n'));
if (failures.length) {
  console.log(`\n${failures.length} failure(s):`);
  for (const f of failures.slice(0, 80)) console.log('  FAIL ' + f);
  process.exit(1);
}
console.log('\nThe design checks pass.');

async function renderInChrome() {
  const chrome = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  if (!existsSync(chrome)) { fail(`--render: no Chrome at ${chrome} (set CHROME)`); return; }
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.mjs': 'text/javascript' };
  const server = createServer((req, res) => {
    const path = normalize(join(ROOT, decodeURIComponent(req.url.split('?')[0])));
    if (!path.startsWith(ROOT) || !existsSync(path) || statSync(path).isDirectory()) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'content-type': types[extname(path)] || 'application/octet-stream' });
    res.end(readFileSync(path));
  });
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  const base = `http://127.0.0.1:${server.address().port}/html/`;
  const urls = [...boards().map((f) => f), ...presetNames.map((n) => `main.html?start=${n}&still=true`)];
  let done = 0;
  async function one(u, profile) {
    const out = await new Promise((ok) => {
      const p = spawn(chrome, ['--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', `--user-data-dir=${profile}`, '--virtual-time-budget=5000', '--dump-dom', base + u]);
      let s = ''; p.stdout.on('data', (d) => { s += d; }); p.on('close', () => ok(s));
      setTimeout(() => p.kill('SIGKILL'), 45000);
    });
    const body = out.replace(/<style[\s\S]*?<\/style>/g, '').replace(/<script[\s\S]*?<\/script>/g, '');
    const text = body.replace(/<[^>]+>/g, ' ');
    if (!out) fail(`render ${u}: Chrome returned nothing`);
    else if (/dc-error/.test(body)) fail(`render ${u}: ${(/dc-error:[^<]{0,160}/.exec(body) || ['dc-error'])[0]}`);
    else if (!/id="dc-root"[^>]*>\s*<\S/.test(body)) fail(`render ${u}: nothing rendered`);
    else if (/\bundefined\b|\bNaN\b|\{\{/.test(text)) fail(`render ${u}: shows ${(/.{0,40}(\bundefined\b|\bNaN\b|\{\{).{0,40}/.exec(text) || [''])[0].trim()}`);
    done++;
  }
  const queue = [...urls];
  await Promise.all(Array.from({ length: 4 }, async () => {
    const profile = mkdtempSync(join(tmpdir(), 'istation-design-chrome-'));
    while (queue.length) await one(queue.shift(), profile);
    rmSync(profile, { recursive: true, force: true });
  }));
  server.close();
  notes.push(`headless Chrome rendered ${done} pages (${boards().length} boards, ${presetNames.length} presets)`);
}
