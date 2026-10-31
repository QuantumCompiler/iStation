# Documentation router

One directory per application. Decide which application your change touches, then read that directory's own docs — each is a self-contained docs-as-source-of-truth system with its own contributor guide, spec, roadmap, backlog and ADRs.

| Working on | Code | Docs | Start at |
|---|---|---|---|
| **iStation** — the macOS game library and launcher for DuckStation, PCSX2 and RPCS3 | `src/istation/` | [`istation/`](istation/README.md) | [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md) |

Facts that cross the boundary:

- **One application today; a second gets its own row and home here.** The emulators are not applications of this repository: iStation drives the user's installed copies (and, from v2.0.0, pinned helper builds) only through their command lines ([ADR 0008](istation/adrs/emulators-are-separate-programs.md)).
- **Repo-wide process lives in [`istation/assistant/CLAUDE.md`](istation/assistant/CLAUDE.md).** Versioning, the release pipeline, CI and the working process are recorded there once; a later home states only its own deltas.
- **Every application follows the same architecture law**: four layers — Infrastructure, Data, Business, Presentation — dependencies pointing down, regardless of language and framework (each home's ADR 0001).
- **The docs validator** is `scripts/validate_docs.py` at the repository root: `python3 scripts/validate_docs.py documentation` checks every backlog index and every relative link.
