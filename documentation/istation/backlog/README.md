# iStation — Backlog

**The work queue: one document per work item.** Every feature and fix that has been discussed and specced but **not yet built** — the layer between the loose ideas in [ROADMAP.md](../assistant/ROADMAP.md) and the shipped record in [MILESTONES.md](../assistant/MILESTONES.md). There is no separate TODO file: an agent takes an item from the index below and **implements it straight from its document**.

## Lifecycle

1. A feature is **discussed in chat** and gets a line on [ROADMAP.md](../assistant/ROADMAP.md) (and a [SPEC.md](../assistant/SPEC.md) revision if it changes product shape).
2. Once specced — seam, files, decisions, open calls — it gets **its own document in its table's subdirectory** (`architecture/`, `maintenance/`, `v<x.y.z>/`; kebab-case filename), listed in the index in build order. The subdirectory is created with a table's first item.
3. When an agent **takes** it (named, or via bare "Continue": the topmost 🟢 row of the earliest version table), the document **is** the working spec: its **Open calls** are resolved first, its row is marked 🚧, and it is built. One item at a time.
4. When it **ships**, the work is recorded in MILESTONES.md and the document is **deleted, with its index row** — a completed item never remains here. Items whose gate it satisfied are updated in the same pass.
5. When a **version's table empties**, it is retired at the pre-merge docs pass. The standing **Architecture** and **Maintenance** tables are never retired.

**The standing invariant:** every document in this directory is pending work.

## Document format

Every item follows this shape (sections in order; omit one only when it is genuinely empty):

```markdown
# <Item title>

**What / why.** <What it delivers and why — concrete enough to build from, with its evidence (file:line, measurements). Too big for one session → **split first**, listing the sub-documents.>

**Core constraint(s).** <The invariants and compatibility it must honor.>

**Seam + files.** <The layer and module(s), the interfaces it extends, the planned files and tests.>

**Reference.** <In-house precedents and prior art, and each deliberate divergence.>

**Decisions made** (dated):
- YYYY-MM-DD: <decision> (<whose call>)

**Open calls:**
- [user] <a user-owned decision — blocks the build until answered>
- [default: <recommendation>] <agent-decidable; taken, recorded, veto-able>
- (consumed decision) <owned by <item>; not reopened>

**Guardrail(s).** <What is tested so the change can't regress silently.>

**Acceptance criteria:**
- [ ] <observable outcome>

**Scope note.** <Earmarked for <version> / Maintenance / Architecture; gated on <id>; out of scope.>
```

## Index

**One table per destination, every table in one shape**: the standing **Architecture** table (`A1, A2, …`, Version `arch.`) and **Maintenance** table (`M1, M2, …`, Version `maint.`) first, then one table per version, nearest release first.

| Column | Contents |
|---|---|
| **#** | The item's identity, never reused. A release item takes a track number and letter (`1a, 1b, …`): joining a release whose pending items share a track, it takes that track's next letter ever assigned; a new theme takes the next track number ever used. Standing items take the next `M<n>`/`A<n>`. |
| **Item** | Plain title — em dash — one-line description. |
| **Version** | The release, or `arch.`/`maint.` — kept in every table so a row keeps its meaning when it moves. |
| **File** | The document, linked into its table's subdirectory. |
| **Status** | 🟢 workable now · 🔒 blocked on the ids named · 🚧 in progress · ❌ cancelled. |

Rows are in suggested build order. **Gates** name only pending items; an item builds on everything shipped plus its gate chain; no cycles. **Split first** items are groomed into their sub-documents before anyone builds. Moving an item between tables is a `git mv`, its row, its Version cell and its links. Same-table links are bare filenames; cross-table links `../<table-dir>/<file>`; links out of the backlog `../../assistant/…`.

**Ids spent so far:** track 1 (`1a`), track 2 (`2a`–`2e`); `M1`, `M2`; `A1`.

### Architecture

The structural reshaping queue, claimable by name at any time. The project was constructed in the layered shape (2026-10-31), so there was no carve to queue. A1 came from the re-vision (2026-11-07): [ADR 0011](../adrs/each-module-carries-its-licence.md) puts a licence on every module and forbids an edge to a stricter one, and A1 gives that rule its check before the first GPL-3.0 module (2c) — which it gates.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| A1 | Each module carries its licence — licence tags on every row, the boundary check, SPDX headers, licence files | arch. | [`architecture/each-module-carries-its-licence.md`](architecture/each-module-carries-its-licence.md) | 🟢 |

### Maintenance

The release-agnostic upkeep queue — bugs, polish, performance, developer ergonomics — claimable by name at any time. M1 and M2 were found while porting the user's Code Scaffold into the layers at construction, 2026-10-31: M1 is inherited from the scaffold, M2 is a behavior the port itself changed.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| M1 | An unreadable library file is silently replaced — keep it aside and tell the user | maint. | [`maintenance/unreadable-library-file.md`](maintenance/unreadable-library-file.md) | 🟢 |
| M2 | The emulator chooser opens in /Applications again — lost in the move to `.fileImporter` | maint. | [`maintenance/app-chooser-start-folder.md`](maintenance/app-chooser-start-folder.md) | 🟢 |

### v0.0.1

**The R3000A boots OpenBIOS** — re-scoped 2026-11-07, when the user re-envisioned iStation as native Swift emulators ported from SwanStation (PS1) and PCSX2 (PS2) ([SPEC.md](../assistant/SPEC.md), [ADR 0010](../adrs/cores-are-ports-of-open-references.md)). Construction's first two lines (compile, tests green) shipped with Milestone A. The old gate, 1a — one game per console booting through the installed emulators — was retired the same day (the user's call); its first run is recorded in [Milestone C](../assistant/MILESTONES.md#milestone-c--the-re-vision).

Track 2 is the re-vision spike's split (2026-11-07, recorded in Milestone C). It measured, over a scratch clone and build of SwanStation commit `631f0fb3`: a clean provenance (DuckStation's history to 2022-01-11, then libretro's own) and GPLv3-compatible dependencies; a clean arm64 build; OpenBIOS embedded and booted when no BIOS is found; no trace logging in its interpreter; its 13 subsystems in one include cycle; ~6,600 lines of C++ in this milestone's slice; and the Swift hot-path costs behind [ADR 0012](../adrs/cores-shape-and-hot-paths.md). It split into a shared trace format (2a), the reference's trace (2b), the CPU (2c, gated by A1's licence check), the console around it (2d) and the gate (2e). The user's calls of 2026-11-07 — shared infrastructure GPL-2.0-or-later, the gate's bar, `access-time` and `io-access-bitwidth` moved to v0.1.0 — are recorded as decisions in each document; the rest are `[default: …]`. When 2e ships, this table is empty and v0.0.1 is released.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 2a | The trace format — one record per guest instruction, and the first divergence between two traces | v0.0.1 | [`v0.0.1/trace-format.md`](v0.0.1/trace-format.md) | 🟢 |
| 2b | The reference trace — SwanStation from a pinned commit, tracing every instruction of an OpenBIOS boot | v0.0.1 | [`v0.0.1/reference-trace.md`](v0.0.1/reference-trace.md) | 🔒 2a |
| 2c | The R3000A interpreter — ported from SwanStation, generic over its bus | v0.0.1 | [`v0.0.1/r3000a-interpreter.md`](v0.0.1/r3000a-interpreter.md) | 🔒 A1, 2a |
| 2d | The PS1 console — memory map, interrupts, timing, minimal DMA and timers, device stubs | v0.0.1 | [`v0.0.1/ps1-console.md`](v0.0.1/ps1-console.md) | 🔒 2c |
| 2e | Gate: OpenBIOS boots — BIOS and PS-EXE loading, TTY, open fixtures; the trace identical to SwanStation's | v0.0.1 | [`v0.0.1/openbios-boots.md`](v0.0.1/openbios-boots.md) | 🔒 2b, 2d |
