# iStation documentation

The docs home for iStation (`src/istation/`) — the Apple-platform app that plays PS1 and PS2 games in its own Swift emulators, ported from SwanStation and PCSX2, behind one game library (re-envisioned 2026-11-07).

- [`assistant/`](assistant/CLAUDE.md) — the contributor docs: [CLAUDE.md](assistant/CLAUDE.md) (the entry point: how to work, the invariants, the codebase map), [SPEC.md](assistant/SPEC.md), [ROADMAP.md](assistant/ROADMAP.md), [MILESTONES.md](assistant/MILESTONES.md), [DEVELOPER.md](assistant/DEVELOPER.md).
- [`backlog/`](backlog/README.md) — the work queue, one document per pending item, with its priority-ordered index.
- [`adrs/`](adrs/README.md) — the architecture decision records: dated, append-only, each with its rationale and its enforcement named.
- [`reference/`](reference/README.md) — the contracts iStation builds against and writes: [the emulators' command lines](reference/emulator-launch-contract.md) and [the library file](reference/library-file.md).

Part of the [documentation router](../CLAUDE.md).
