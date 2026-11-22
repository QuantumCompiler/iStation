// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// Shared helpers for the design's tools: read a .dc.html file, run its logic in Node, and render its
// markup at the logic level (every hole evaluated, every <sc-if> and <sc-for> followed) so a check can
// catch a hole that is undefined or NaN without a browser.

import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
export const HTML = join(ROOT, 'html');
export const JSON_DIR = join(ROOT, 'json');

export function read(path) { return readFileSync(path, 'utf8'); }
export function boards() { return readdirSync(HTML).filter((f) => f.endsWith('.dc.html')).sort(); }

export function parts(text) {
  const x = /<x-dc>([\s\S]*)<\/x-dc>/.exec(text);
  const sc = /<script type="text\/x-dc"([^>]*)>([\s\S]*?)<\/script>/.exec(text);
  let markup = x ? x[1] : '';
  let helmet = '';
  markup = markup.replace(/<helmet>([\s\S]*?)<\/helmet>/, (_, inner) => { helmet = inner; return ''; });
  const propsAttr = sc ? /data-props='([^']*)'/.exec(sc[1]) : null;
  return { markup, helmet, script: sc ? sc[2] : '', props: propsAttr ? JSON.parse(propsAttr[1].replace(/&#39;/g, "'").replace(/&amp;/g, '&')) : {} };
}

export class DCLogic {
  constructor(props) { this.props = props || {}; this.state = {}; }
  setState(patch) { const next = typeof patch === 'function' ? patch(this.state, this.props) : patch; this.state = { ...this.state, ...next }; }
  forceUpdate() {}
}

/** Runs a file's script and returns the named top-level bindings it defines. */
export function evaluate(script, names) {
  const list = names.map((n) => `${n}: typeof ${n} === 'undefined' ? undefined : ${n}`).join(', ');
  // eslint-disable-next-line no-new-func
  return new Function('DCLogic', `${script}\n;return { ${list} };`)(DCLogic);
}

/* A small parser for the markup these files hold: every non-void element closed, every attribute quoted. */
const VOID = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr']);
export function parseMarkup(markup) {
  const root = { tag: '#root', attrs: [], children: [] };
  const stack = [root];
  const re = /<!--[\s\S]*?-->|<\/([a-zA-Z][\w:-]*)\s*>|<([a-zA-Z][\w:-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'))?)*)\s*(\/?)>|([^<]+)/g;
  let m;
  while ((m = re.exec(markup))) {
    const top = stack[stack.length - 1];
    if (m[0].startsWith('<!--')) continue;
    if (m[1]) {
      const name = m[1].toLowerCase();
      if (top.tag !== name) throw new Error(`markup: </${name}> closes <${top.tag}> (offset ${m.index})`);
      stack.pop();
      continue;
    }
    if (m[2]) {
      const name = m[2].toLowerCase();
      const attrs = [];
      const are = /([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'))?/g;
      let a;
      while ((a = are.exec(m[3] || ''))) attrs.push([a[1], a[2] !== undefined ? a[2] : a[3] !== undefined ? a[3] : '']);
      const el = { tag: name, attrs, children: [] };
      top.children.push(el);
      if (!VOID.has(name) && !m[4]) stack.push(el);
      continue;
    }
    if (m[5]) top.children.push({ text: m[5] });
  }
  if (stack.length !== 1) throw new Error(`markup: <${stack[stack.length - 1].tag}> is never closed`);
  return root;
}

const WHOLE = /^\s*\{\{\s*([^}]+?)\s*\}\}\s*$/;
const HOLE = /\{\{\s*([^}]+?)\s*\}\}/g;
function lookup(path, scope) {
  const p = path.trim();
  if (p === 'true') return true;
  if (p === 'false') return false;
  if (p === 'null') return null;
  if (/^-?\d+(\.\d+)?$/.test(p)) return Number(p);
  if (/[^\w.$]/.test(p)) return { __bad: `not a dotted path: {{ ${p} }}` };
  let v = scope;
  for (const part of p.split('.')) { if (v === null || v === undefined) return undefined; v = v[part]; }
  return v;
}

/**
 * Renders a parsed tree against renderVals() at the logic level: returns the text it would show and
 * every problem found (an undefined, NaN or non-path hole; a list that isn't an array; an event that
 * isn't a function; a rendered string holding "undefined" or "NaN").
 */
export function renderLogic(tree, vals) {
  const problems = [];
  const text = [];
  const contracts = [];
  let holes = 0;
  function bad(where, why) { if (problems.length < 40) problems.push(`${where}: ${why}`); }
  function value(raw, scope, where) {
    const whole = WHOLE.exec(raw);
    if (whole) {
      holes++;
      const v = lookup(whole[1], scope);
      if (v && v.__bad) bad(where, v.__bad);
      else if (v === undefined) bad(where, `{{ ${whole[1]} }} is undefined`);
      else if (typeof v === 'number' && Number.isNaN(v)) bad(where, `{{ ${whole[1]} }} is NaN`);
      else if (typeof v === 'string' && /\bundefined\b|\bNaN\b/.test(v)) bad(where, `{{ ${whole[1]} }} renders "${v.slice(0, 60)}"`);
      return v;
    }
    if (raw.indexOf('{{') < 0) return raw;
    return raw.replace(HOLE, (_, path) => {
      holes++;
      const v = lookup(path, scope);
      if (v && v.__bad) bad(where, v.__bad);
      else if (v === undefined) bad(where, `{{ ${path} }} is undefined`);
      else if (typeof v === 'number' && Number.isNaN(v)) bad(where, `{{ ${path} }} is NaN`);
      const s = v === null || v === undefined ? '' : String(v);
      if (/\bundefined\b|\bNaN\b/.test(s)) bad(where, `{{ ${path} }} renders "${s.slice(0, 60)}"`);
      return s;
    });
  }
  function walk(nodes, scope) {
    for (const n of nodes) {
      if ('text' in n) { const t = value(n.text, scope, 'text'); if (String(t).trim()) text.push(String(t).trim()); continue; }
      const attr = (k) => { const a = n.attrs.find((x) => x[0] === k); return a ? a[1] : null; };
      if (n.tag === 'sc-if') { if (value(attr('value') || '', scope, '<sc-if>')) walk(n.children, scope); continue; }
      if (n.tag === 'sc-for') {
        const list = value(attr('list') || '', scope, '<sc-for>');
        if (!Array.isArray(list)) { bad('<sc-for>', `list ${attr('list')} is not an array`); continue; }
        const as = attr('as') || 'item';
        list.forEach((item, i) => { const inner = Object.create(scope); inner[as] = item; inner.$index = i; walk(n.children, inner); });
        continue;
      }
      for (const [k, raw] of n.attrs) {
        const v = value(raw, scope, `<${n.tag} ${k}>`);
        if (/^on[A-Z]/.test(k) && typeof v !== 'function') bad(`<${n.tag} ${k}>`, 'is not a function');
        if (k === 'ref' && typeof v !== 'function') bad(`<${n.tag} ref>`, 'is not a function');
        if (k === 'data-contract' && v) contracts.push(...String(v).split(/\s+/).filter(Boolean));
      }
      walk(n.children, scope);
    }
  }
  walk(tree.children, Object.assign(Object.create(null), vals));
  return { problems, text: text.join(' '), holes, contracts };
}

/** Undefined or NaN anywhere in renderVals() (functions skipped). */
export function scanValues(v, path = 'vals', out = [], seen = new Set()) {
  if (out.length > 20) return out;
  if (v === undefined) { out.push(`${path} is undefined`); return out; }
  if (typeof v === 'number' && Number.isNaN(v)) { out.push(`${path} is NaN`); return out; }
  if (v && typeof v === 'object') {
    if (seen.has(v)) return out;
    seen.add(v);
    for (const k of Object.keys(v)) scanValues(v[k], `${path}.${k}`, out, seen);
  }
  return out;
}

export function luminance(hex) {
  const h = hex.replace('#', '').slice(0, 6);
  const c = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((x) => (x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
export function contrast(a, b) { const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); }
