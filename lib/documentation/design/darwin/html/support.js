// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
//
// A small standalone runtime for the design's .dc.html files, so the repository's copy opens in a
// browser without the canvas: python3 -m http.server, then html/main.html?start=<preset>&still=true
// or any html/<Board>.dc.html. Repo-only: the canvas serves its own support.js, and this file is
// never published to it.
//
// It implements the subset of the Design Component format these files use: <x-dc> markup, <helmet>,
// {{ dotted.path }} holes in text and attributes (a whole-value hole passes the raw value), onX
// events, ref and autoFocus, <sc-if value>, <sc-for list as> with $index, <dc-import name> (Main
// resolves to main.html), and a DCLogic base class with props, state, setState, forceUpdate,
// componentDidMount, componentDidUpdate and componentWillUnmount. Nothing here is the canvas's code.
(function () {
  'use strict';

  var hideStyle = document.createElement('style');
  hideStyle.textContent = 'x-dc{display:none}';
  document.head.appendChild(hideStyle);

  function DCLogic(props) { this.props = props || {}; this.state = {}; }
  DCLogic.prototype.setState = function (patch, done) {
    var next = typeof patch === 'function' ? patch(this.state, this.props) : patch;
    var prev = this.state;
    this.state = Object.assign({}, this.state, next);
    schedule(this, prev);
    if (done) done();
  };
  DCLogic.prototype.forceUpdate = function () { schedule(this, this.state); };
  window.DCLogic = DCLogic;

  function schedule(inst, prevState) {
    if (!inst.__host) return;
    if (inst.__pending) return;
    inst.__pending = { prevState: prevState, prevProps: inst.props };
    Promise.resolve().then(function () {
      var p = inst.__pending; inst.__pending = null;
      inst.__host.render();
      if (inst.componentDidUpdate) inst.componentDidUpdate(p.prevProps, p.prevState);
    });
  }

  var HOLE = /\{\{\s*([^}]+?)\s*\}\}/g;
  var WHOLE = /^\s*\{\{\s*([^}]+?)\s*\}\}\s*$/;

  function lookup(path, scope) {
    var p = path.trim();
    if (p === 'true') return true;
    if (p === 'false') return false;
    if (p === 'null') return null;
    if (/^-?\d+(\.\d+)?$/.test(p)) return Number(p);
    if (/^(['"]).*\1$/.test(p)) return p.slice(1, -1);
    var parts = p.split('.'), v = scope;
    for (var i = 0; i < parts.length; i++) {
      if (v === null || v === undefined) return undefined;
      v = v[parts[i]];
    }
    return v;
  }
  function interp(text, scope) {
    if (text === null || text === undefined) return text;
    var whole = WHOLE.exec(text);
    if (whole) return lookup(whole[1], scope);
    if (text.indexOf('{{') < 0) return text;
    return text.replace(HOLE, function (_, path) { var v = lookup(path, scope); return v === null ? '' : String(v); });
  }
  function camel(name) { return name.replace(/-([a-z])/g, function (_, c) { return c.toUpperCase(); }); }

  // Template → virtual nodes.
  function build(nodes, scope, out) {
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n.nodeType === 3) {
        var t = n.nodeValue;
        if (/^\s*$/.test(t) && t.indexOf('\n') >= 0) continue;
        out.push({ text: t.indexOf('{{') < 0 ? t : String(interpText(t, scope)) });
        continue;
      }
      if (n.nodeType !== 1) continue;
      var tag = n.localName;
      if (tag === 'helmet') continue;
      if (tag === 'sc-if') { if (interp(n.getAttribute('value'), scope)) build(n.childNodes, scope, out); continue; }
      if (tag === 'sc-for') {
        var list = interp(n.getAttribute('list'), scope) || [];
        var as = n.getAttribute('as') || 'item';
        for (var k = 0; k < list.length; k++) {
          var inner = Object.create(scope); inner[as] = list[k]; inner.$index = k;
          build(n.childNodes, inner, out);
        }
        continue;
      }
      if (tag === 'dc-import') {
        var props = {};
        for (var a = 0; a < n.attributes.length; a++) {
          var at = n.attributes[a];
          if (at.name === 'name' || at.name.indexOf('hint-') === 0) continue;
          props[camel(at.name)] = interp(at.value, scope);
        }
        out.push({ importName: n.getAttribute('name'), props: props });
        continue;
      }
      var v = { tag: n.tagName, ns: n.namespaceURI, attrs: {}, events: {}, ref: null, autofocus: false, children: [] };
      for (var b = 0; b < n.attributes.length; b++) {
        var attr = n.attributes[b], name = attr.name, val = interp(attr.value, scope);
        if (name.indexOf('on') === 0 && name.length > 2) { if (typeof val === 'function') v.events[name.slice(2).toLowerCase()] = val; continue; }
        if (name === 'ref') { v.ref = typeof val === 'function' ? val : null; continue; }
        if (name === 'autofocus') { v.autofocus = !!val; continue; }
        v.attrs[name] = val;
      }
      build(n.childNodes, scope, v.children);
      out.push(v);
    }
  }
  function interpText(t, scope) {
    return t.replace(HOLE, function (_, path) { var v = lookup(path, scope); return v === null ? '' : String(v); });
  }

  // Virtual nodes → the DOM, reusing what is already there.
  var focusQueue = [];
  function patch(parent, vnodes) {
    var existing = Array.prototype.slice.call(parent.childNodes);
    for (var i = 0; i < vnodes.length; i++) {
      var vn = vnodes[i], cur = existing[i];
      if (cur && same(cur, vn)) update(cur, vn);
      else {
        var el = create(vn);
        if (cur) parent.replaceChild(el, cur); else parent.appendChild(el);
        if (vn.importName) mountImport(el, vn); else if (!('text' in vn)) update(el, vn);
      }
    }
    for (var j = vnodes.length; j < existing.length; j++) { unmountTree(existing[j]); parent.removeChild(existing[j]); }
  }
  function same(node, vn) {
    if ('text' in vn) return node.nodeType === 3;
    if (vn.importName) return node.__dcImport === vn.importName;
    return node.nodeType === 1 && !node.__dcImport && node.tagName === vn.tag && node.namespaceURI === vn.ns;
  }
  function create(vn) {
    if ('text' in vn) return document.createTextNode(vn.text);
    if (vn.importName) { var h = document.createElement('dc-host'); h.style.display = 'contents'; h.__dcImport = vn.importName; return h; }
    var el = vn.ns && vn.ns !== 'http://www.w3.org/1999/xhtml' ? document.createElementNS(vn.ns, vn.tag) : document.createElement(vn.tag);
    if (vn.autofocus) focusQueue.push(el);
    return el;
  }
  var BOOL = { disabled: 1, checked: 1, hidden: 1, readonly: 1, required: 1, multiple: 1, selected: 1, open: 1 };
  function update(el, vn) {
    if ('text' in vn) { if (el.nodeValue !== vn.text) el.nodeValue = vn.text; return; }
    if (vn.importName) { updateImport(el, vn); return; }
    var attrs = vn.attrs, name;
    for (var i = el.attributes.length - 1; i >= 0; i--) {
      name = el.attributes[i].name;
      if (!(name in attrs)) el.removeAttribute(name);
    }
    for (name in attrs) {
      var v = attrs[name];
      if (name === 'value' && 'value' in el && el.tagName !== 'PROGRESS') { var sv = v === null || v === undefined ? '' : String(v); if (el.value !== sv) el.value = sv; continue; }
      if (name === 'checked' && el.tagName === 'INPUT') { el.checked = !!v; continue; }
      if (typeof v === 'function') continue;
      if (v === null || v === undefined) { el.removeAttribute(name); continue; }
      if (v === false && name.indexOf('aria-') !== 0) { el.removeAttribute(name); continue; }
      if (v === true) { if (el.getAttribute(name) !== (BOOL[name] ? '' : 'true')) el.setAttribute(name, BOOL[name] ? '' : 'true'); continue; }
      var s = String(v);
      if (el.getAttribute(name) !== s) el.setAttribute(name, s);
    }
    el.__h = vn.events;
    el.__types = el.__types || {};
    for (var type in vn.events) {
      var domType = type === 'doubleclick' ? 'dblclick' : type === 'change' && isTextual(el) ? 'input' : type;
      if (!el.__types[domType]) {
        el.__types[domType] = type;
        el.addEventListener(domType, (function (t) { return function (e) { var h = el.__h && el.__h[t]; if (h) h(e); }; })(type));
      }
    }
    if (vn.ref && el.__ref !== vn.ref) { el.__ref = vn.ref; vn.ref(el); }
    patch(el, vn.children);
  }
  function isTextual(el) {
    if (el.tagName === 'TEXTAREA') return true;
    if (el.tagName !== 'INPUT') return false;
    var t = (el.getAttribute('type') || 'text').toLowerCase();
    return t !== 'checkbox' && t !== 'radio';
  }
  function unmountTree(node) {
    if (node.__dcHost && node.__dcHost.inst.componentWillUnmount) node.__dcHost.inst.componentWillUnmount();
    if (node.childNodes) for (var i = 0; i < node.childNodes.length; i++) unmountTree(node.childNodes[i]);
  }

  // Files and components.
  var defs = {};
  function fileFor(name) { return name === 'Main' ? 'main.html' : name + '.dc.html'; }
  function parseDef(text, url) {
    var x = /<x-dc>([\s\S]*)<\/x-dc>/.exec(text);
    var sc = /<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/.exec(text);
    if (!x) throw new Error('No <x-dc> in ' + url);
    var markup = x[1], helmet = '';
    markup = markup.replace(/<helmet>([\s\S]*?)<\/helmet>/, function (_, inner) { helmet = inner; return ''; });
    var tpl = document.createElement('template');
    tpl.innerHTML = markup;
    var Component = sc ? new Function('DCLogic', sc[1] + '\n;return typeof Component === "undefined" ? null : Component;')(DCLogic) : null;
    return { url: url, template: tpl, helmet: helmet, Component: Component || function (p) { DCLogic.call(this, p); } };
  }
  function load(name) {
    if (!defs[name]) defs[name] = fetch(fileFor(name), { cache: 'no-store' }).then(function (r) { return r.text(); }).then(function (t) { return parseDef(t, fileFor(name)); });
    return defs[name];
  }
  var helmets = {};
  function injectHelmet(def) {
    if (!def.helmet || helmets[def.url]) return;
    helmets[def.url] = true;
    var holder = document.createElement('div');
    holder.innerHTML = def.helmet;
    Array.prototype.slice.call(holder.childNodes).forEach(function (n) { if (n.nodeType === 1) document.head.appendChild(n); });
  }

  function Host(def, props, container) {
    this.def = def; this.container = container;
    injectHelmet(def);
    var C = def.Component;
    if (C.prototype && !(C.prototype instanceof DCLogic) && C !== DCLogic) Object.setPrototypeOf(C.prototype, DCLogic.prototype);
    try { this.inst = new C(props); } catch (e) { return this.fail(e); }
    this.inst.props = props;
    if (!this.inst.state) this.inst.state = {};
    this.inst.__host = this;
    container.__dcHost = this;
    this.render();
    if (this.inst.componentDidMount) this.inst.componentDidMount();
  }
  Host.prototype.render = function () {
    var vnodes = [];
    try {
      var vals = this.inst.renderVals ? this.inst.renderVals() : {};
      var scope = Object.assign(Object.create(null), vals || {});
      build(this.def.template.content.childNodes, scope, vnodes);
    } catch (e) { return this.fail(e); }
    patch(this.container, vnodes);
    var q = focusQueue; focusQueue = [];
    q.forEach(function (el) { if (el.isConnected) el.focus({ preventScroll: true }); });
  };
  Host.prototype.fail = function (e) {
    var pre = document.createElement('pre');
    pre.className = 'dc-error';
    pre.textContent = 'dc-error: ' + (e && e.stack || e);
    this.container.textContent = '';
    this.container.appendChild(pre);
    if (window.console) console.error(e);
  };
  function mountImport(el, vn) {
    load(vn.importName).then(function (def) { new Host(def, vn.props, el); el.__props = vn.props; })
      .catch(function (e) { el.textContent = 'dc-error: ' + e; });
  }
  function updateImport(el, vn) {
    var host = el.__dcHost;
    if (!host) return;
    var prev = el.__props || {}, changed = false, k;
    for (k in vn.props) if (prev[k] !== vn.props[k]) changed = true;
    for (k in prev) if (!(k in vn.props)) changed = true;
    if (!changed) return;
    el.__props = vn.props; host.inst.props = vn.props; host.render();
  }

  function boot() {
    var xdc = document.querySelector('x-dc');
    if (!xdc) return;
    var here = location.pathname.split('/').pop() || 'index.html';
    var props = {};
    new URLSearchParams(location.search).forEach(function (v, k) { props[k] = v; });
    var root = document.createElement('div');
    root.id = 'dc-root';
    document.body.appendChild(root);
    fetch(location.pathname, { cache: 'no-store' })
      .then(function (r) { return r.text(); })
      .then(function (t) { return parseDef(t, here); })
      .then(function (def) { xdc.remove(); window.__dcRoot = new Host(def, props, root); })
      .catch(function (e) { root.textContent = 'dc-error: ' + e + ' (open this over http, e.g. python3 -m http.server)'; });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
