# Documentation router

The documentation is split **by kind, then by platform**, so each kind of document sits in one place (the change of 2026-11-14, the user's call: iStation takes the layout of the user's Apogee repository):

| Kind | Holds |
|---|---|
| [`assistant/`](assistant/README.md) | Contributor docs: how to work on each application. Start at its `CLAUDE.md`, then SPEC, ROADMAP, MILESTONES and DEVELOPER |
| [`backlog/`](backlog/README.md) | The work queue: each application's index (its `README.md`) and one document per pending item |
| [`adrs/`](adrs/README.md) | The architecture decision records, dated and append-only |
| [`reference/`](reference/README.md) | The contracts iStation builds against and writes |

Inside each kind, one folder per platform:

| Working on | Code | Start at | Backlog | ADRs |
|---|---|---|---|---|
| **The Apple apps**: macOS (PS1 and PS2) and iOS (PS1), one Swift codebase with PlayStation emulators ported from ProjectPSX and Play!, eligible for the App Stores | `src/istation/` | [`assistant/darwin/CLAUDE.md`](assistant/darwin/CLAUDE.md) | [`backlog/darwin/`](backlog/darwin/README.md) (an item for one OS sits in `macos/` or `ios/`) | [`adrs/darwin/`](adrs/darwin/README.md) |

Facts that cross the boundary:

- **One application today, `darwin`; a second gets its own folder in each kind and a row here.** The cores are modules of the one package, not applications of their own; the macOS and iOS apps are its two app targets, and what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`.
- **Shipped code comes only from permissive sources** ([ADR 0013](adrs/darwin/shipped-code-derives-only-from-permissive-references.md)): the references (ProjectPSX, Play!) are built and traced locally under `tools/`, never vendored; the GPL oracles (SwanStation, PCSX2) are only built unmodified and run, their source never read.
- **Repo-wide process lives in [`assistant/darwin/CLAUDE.md`](assistant/darwin/CLAUDE.md)**: versioning, the release pipeline, CI and the working process — every task ends with one commit and a push — are recorded there once; a later application's docs state only their own deltas.
- **Every application follows the same architecture law**: four layers — Infrastructure, Data, Business, Presentation — dependencies pointing down ([ADR 0001](adrs/darwin/layer-enforcement.md)).
- **The docs validator** is `lib/scripts/validate_docs.py`: `python3 lib/scripts/validate_docs.py lib/documentation` checks every application's backlog index, its OS folders included, and every relative link.
