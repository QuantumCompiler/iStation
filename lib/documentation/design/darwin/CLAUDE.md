# The app design: working on it

Context for agents changing the design of the Apple apps. [README.md](README.md) has the layout, how to open it, and the path map; the product's rules are in [the darwin CLAUDE.md](../../assistant/darwin/CLAUDE.md), which still governs: the GPL rule, no Sony files or artwork, and committing only when the user asks, then in its one-line form.

## The sync rule

**The canvas and this folder hold the same files.** The canvas is [iStation App Design](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu); the path map is README.md's.

- **Every change lands in both places, identical.** Edit here, run the checks, then stage with `node tools/mirror.mjs --to <scratch dir>` and publish the changed files to the canvas's `url` with `root` at that dir. Send `project/canvas.json` only when boards, pages, notes or the title change.
- **If the canvas was edited directly, read it down first.** Read each changed file with the Artifact tool's `read` (its `path`, e.g. `project/Main.dc.html`) into `<dir>/project/`, then `node tools/mirror.mjs --from <dir>`, then the checks, before changing anything. A publish refused because someone saved meanwhile names the file to re-read.
- **Never publish `html/support.js`**, and never take the canvas's `support.js` back: each side has its own runtime.

## What each kind of change touches

| Change | Touches |
|---|---|
| A screen's look or behavior | `html/main.html` only (markup, `view()`, `reduce()`, `advance()`); every board follows, since each mounts it |
| A new state worth seeing | a preset in `PRESETS` and `PRESET_NAMES` in `html/main.html`; a board `html/Mac-<Name>.dc.html` or `html/iOS-<Name>.dc.html` copied from a sibling with its `start=`, `<title>` and `$preview` size; its entry in `json/canvas.json` (page, frame clear of others, title) and `order`; the state table in `Layout.dc.html` if it's a new kind of state |
| A color, size, font, space, radius or duration | `json/tokens.json`, then `node tools/sync.mjs`; add a `contrastPairs` entry for any new text pair; the Foundations boards follow |
| The prototype's shared CSS, icons or shortcuts | `html/main.html`, then `node tools/sync.mjs` (copies them into `Foundations-Components.dc.html` and `Layout.dc.html`); a new shortcut also needs its case in `keyAction()` |
| What backs a part | `ROWS` and `GAPS` in `html/Contract.dc.html`, and the part's `data-contract` ids in `html/main.html` |
| A gap closed by the backend | its rows' tag (gap → ready or app) and note in `Contract.dc.html`, with how it was checked in `EVIDENCE`; the `has` flags or `level === 'today'` branches in `main.html` that drew its fallback; the Today boards if what today means has moved |

## The format's gotchas

- A hole is a dotted lookup only: `{{ a.b }}`, `{{ $index }}`, `{{ true }}`. Never an expression; compute it in `view()` (or `renderVals()`) and name it.
- A whole-value hole passes the raw value (a function, boolean, number or null); a hole inside other text becomes a string. `null` omits an attribute: use it for `aria-pressed` on a button that isn't a toggle.
- Close every element that isn't void, and quote every attribute. `check.mjs` parses the markup and fails on an unclosed tag.
- `<sc-if value>` and `<sc-for list as>` render no wrapper element. Keep their `hint-placeholder-*` attributes.
- Events are camelCase on the element (`onClick`, `onKeyDown`, `onChange`, `onDoubleClick`). There are no global key handlers: the root `div` has `tabIndex="0"` and `onKeyDown`, so keys work once it has focus.
- `onChange` on a text field fires on every keystroke, as React does.
- `data-props` is single-quoted JSON: write `&#39;` for an apostrophe inside it, or use a typographic one (’).
- No hex color outside the `TOKENS` literal, and no emoji, anywhere: `check.mjs` fails on both. Every color is `var(--role)`.
- Every board mounts the prototype with `still="{{ true }}"`, so its clock never runs and it can't drift.
- The logic is pure: `initialState(props)`, `advance(state)` (one 100 ms clock tick), `reduce(state, action)` and `view(state, dispatch, refs)`. Keep it so, and the Node checks can drive it without a browser.
- Canned values must be shaped like the backend's reports: never invent a size, time, count or estimate it doesn't report; show "Unknown" or the fallback instead. Recordings of the real system beat made-up values.
- The canvas's runtime is React; `html/support.js` is a small stand-in. Anything that works only in one of them is a bug: keep to the subset above.

## How to check a change

1. `node tools/check.mjs` must pass, and `node tools/check.mjs --render` after any markup change.
2. Open it over the local server (README.md) and click through the flows you touched, with the keyboard as well as the mouse.
3. Look at screenshots of what you changed in each theme (the App board's Tweaks, or Settings › Appearance) and at the minimum window size (the `library-min` and `player-min` presets).
4. Verify any row you tag ready against the real backend with a harmless call (a probe package linking `PS1Core` and `EmuKit` by path, `istation-run`'s usage, or the module's tests), and record how in `EVIDENCE`. Anything you couldn't verify is tagged verify.
5. `python3 lib/scripts/validate_docs.py lib/documentation` from the repository root, since this folder's Markdown is part of the docs.
