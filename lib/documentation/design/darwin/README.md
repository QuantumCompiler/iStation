# iStation app design: the Apple apps

The design of the macOS app (SwiftUI, first) and the iOS app (SwiftUI, from v0.4.0), kept as a Claude Design canvas and mirrored here so the repository holds the source of truth. Engineers build it screen by screen; each part names the core interface or framework behind it on the Contract page.

**The canvas:** [iStation App Design](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) (private to its owner until shared).

## What's in it

| Page | Holds |
|---|---|
| **Build** | **App**: one interactive prototype of both apps, driven by a clock so jobs progress and frames count. **One board per screen and state** (66), each mounting the prototype at a named start preset with the clock stopped. **Contract**: every part mapped to what backs it, tagged ready, app, gap or verify; the 13 gaps with their change, fallback and version; the decisions and the calls left open. **Layout**: regions and sizes, minimums and breakpoints, navigation, every keyboard shortcut and menu, the states each screen draws, each piece in SwiftUI. **Processes**: the app, its console thread, the frameworks and the files it reads and writes. |
| **Foundations** | Color tokens in dark, light and high-contrast themes with each pair's contrast computed; type, spacing, radii and motion; every component in its states. |
| **Exploration** | The three early directions and three accents, kept for reference. |

The **Today** row of boards draws the backend's **today** level: the library without disc reading, the BIOS running without a picture, the personal tools as `istation-run` commands to copy. Since 6a a PS-EXE plays at the today level (G5); discs still play from v0.2.0. Two Today boards keep the state from before 6a, as items 5c and 5f cite them: `Mac-TodayBiosDone`, where the BIOS check says it powered on and ran 60 frames (G10), and `Mac-TodayTools`, the `istation-run` commands (G6). The Contract page says which gaps the backend has closed.

**The backlog builds it**: track 5 is a document per screen or flow, track 6 one per gap, across the v0.1.0 to v0.4.0 tables of the [backlog index](../../backlog/darwin/README.md); each cites its boards and contract rows, and each gap on the Contract page names the item that closes it.

## Layout

```
lib/documentation/design/darwin/
├── README.md, CLAUDE.md
├── html/
│   ├── main.html            the prototype: every screen, sheet, alert and flow, one file
│   ├── <Board>.dc.html      one board per screen and state (Mac-*, iOS-*), plus Contract, Layout,
│   │                        Processes, Foundations-Color, -Type, -Components and Exploration
│   └── support.js           a small standalone runtime: repo-only, never published
├── json/
│   ├── canvas.json          the canvas's index: every board's page, frame and title
│   └── tokens.json          every color, font, size, space, radius and duration
└── tools/                   Node, no dependencies
    ├── check.mjs            the checks (below)
    ├── sync.mjs             copies tokens.json, and main.html's styles, icons and shortcuts, into the files that embed them
    ├── mirror.mjs           stages the files in the canvas's layout, or takes a canvas read-down back
    └── dc.mjs               shared helpers
```

## Opening it

From the repository root:

```bash
python3 -m http.server 8791 --bind 127.0.0.1 --directory lib/documentation/design/darwin
```

Then open `http://127.0.0.1:8791/html/main.html` for the running prototype, `http://127.0.0.1:8791/html/main.html?start=scan-running&still=true` for any start preset with the clock stopped, or any board, such as `http://127.0.0.1:8791/html/Contract.dc.html`. The prototype's keyboard works once it has focus: click inside it, then try ⌘1 to ⌘7, ⌘O, ⌘I, ↑ ↓ and ↩, or ⌘/ for the list. In the Claude desktop app, the `design` entry in `.claude/launch.json` starts the same server.

The canvas has Tweaks on the App board for the start preset, the theme, the build routine (App Store or personal) and the backend level (target, or today's).

## The canvas ↔ repository path map

| Canvas (`project/…`) | Repository (`lib/documentation/design/darwin/…`) |
|---|---|
| `Main.dc.html` | `html/main.html` |
| `<Board>.dc.html` | `html/<Board>.dc.html` |
| `canvas.json` | `json/canvas.json` |
| `tokens.json` | `json/tokens.json` |
| `support.js` (the canvas's own runtime) | none: `html/support.js` is this folder's own runtime and is never published |

`node tools/mirror.mjs --to <dir>` stages the repository's files as `<dir>/project/…` for a publish; `--from <dir>` takes a canvas read down into `<dir>/project/` back into `html/` and `json/`.

## Checking it

```bash
node lib/documentation/design/darwin/tools/check.mjs
```

```bash
node lib/documentation/design/darwin/tools/check.mjs --render
```

The first checks the logic and the files: tokens match `tokens.json`, every color pair meets its contrast minimum, no hex color or emoji sits outside the tokens, every start preset runs 30 clock ticks without throwing or rendering `undefined` or `NaN`, eight scripted flows end where they should, every listed shortcut reaches an action, every contract row the prototype names exists, every preset has a board, and `canvas.json` lists every file. `--render` also loads every board and every preset in headless Chrome (set `CHROME` if it isn't in `/Applications`).

## Data

Canned data is shaped like what the backend and the system report. The ready rows' values are recordings from 2026-11-21: `PS1Console`'s states and errors from a probe built against the package, `istation-run`'s output and exit codes, and a full-state record from its CPU-check trace, all over content built in code. Game names, serials, file sizes and times are placeholders: no real game, BIOS or artwork appears anywhere in the design.
