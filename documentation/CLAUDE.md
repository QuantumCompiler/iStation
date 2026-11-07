# Documentation router

One directory per application. Decide which application your change touches, then read that directory's own docs — each is a self-contained docs-as-source-of-truth system with its own contributor guide, spec, roadmap, backlog and ADRs.

| Working on | Code | Docs | Start at |
|---|---|---|---|
| **iStation** — the Apple-platform app that plays PS1 and PS2 games in its own Swift emulators (ports of SwanStation and PCSX2), behind one game library | `src/istation/` | [`istation/`](istation/README.md) | [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md) |

Facts that cross the boundary:

- **One application today; a second gets its own row and home here.** The cores are modules of iStation, not applications of their own; their references (SwanStation, PCSX2) are built and traced locally under `tools/`, never vendored. Installed emulators, for consoles without a native core, are driven only through their command lines ([ADR 0010](istation/adrs/cores-are-ports-of-open-references.md)).
- **Repo-wide process lives in [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md).** Versioning, the release pipeline, CI and the working process are recorded there once; a later home states only its own deltas.
- **Every application follows the same architecture law**: four layers — Infrastructure, Data, Business, Presentation — dependencies pointing down, regardless of language and framework (each home's ADR 0001).
- **The docs validator** is `scripts/validate_docs.py` at the repository root: `python3 scripts/validate_docs.py documentation` checks every backlog index and every relative link.
