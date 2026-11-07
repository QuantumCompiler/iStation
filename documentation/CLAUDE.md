# Documentation router

One directory per application. Decide which application your change touches, then read that directory's own docs — each is a self-contained docs-as-source-of-truth system with its own contributor guide, spec, roadmap, backlog and ADRs.

| Working on | Code | Docs | Start at |
|---|---|---|---|
| **iStation** — two Apple apps (macOS: PS1 and PS2; iOS: PS1) with PlayStation emulators in Swift, ported from ProjectPSX and Play!, eligible for the App Stores | `src/istation/` | [`istation/`](istation/README.md) | [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md) |

Facts that cross the boundary:

- **One application today; a second gets its own row and home here.** The cores are modules of iStation's one package, not applications of their own; the macOS and iOS apps are its two app targets. The permissive references (ProjectPSX, Play!) are built and traced locally under `tools/`, never vendored; the GPL oracles (SwanStation, PCSX2) are only built unmodified and run, their source never read ([ADR 0013](istation/adrs/shipped-code-derives-only-from-permissive-references.md)).
- **Repo-wide process lives in [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md).** Versioning, the release pipeline, CI and the working process are recorded there once; a later home states only its own deltas.
- **Every application follows the same architecture law**: four layers — Infrastructure, Data, Business, Presentation — dependencies pointing down, regardless of language and framework (each home's ADR 0001).
- **The docs validator** is `scripts/validate_docs.py` at the repository root: `python3 scripts/validate_docs.py documentation` checks every backlog index and every relative link.
