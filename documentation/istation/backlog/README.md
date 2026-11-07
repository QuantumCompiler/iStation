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

**Ids spent so far:** track 1 (`1a`), track 2 (`2a`–`2e`, cancelled), track 3 (`3a`–`3g`); `M1`, `M2` (cancelled); `A1` (cancelled), `A2`.

### Architecture

The structural reshaping queue, claimable by name at any time. A1 (licence tags for GPL modules) was cancelled the day it was written, 2026-11-07, when the App Store brief made all shipped code permissive. A2 comes from that brief: [ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md) makes iStation's own code MIT and requires every ported file to keep its reference's notice; A2 gives that its check before the first ported module (3e), which it gates.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| A2 | Provenance headers and notices — SPDX headers, provenance lines, the acknowledgements list, the root licence, with a check | arch. | [`architecture/provenance-headers-and-notices.md`](architecture/provenance-headers-and-notices.md) | 🟢 |

### Maintenance

The release-agnostic upkeep queue — bugs, polish, performance, developer ergonomics — claimable by name at any time. Empty: M1 (an unreadable library file) and M2 (the emulator chooser's start folder) belonged to the library app and were cancelled with it, 2026-11-07.

| # | Item | Version | File | Status |
|---|---|---|---|---|

### v0.0.1

**JIT verified, both build routines, the R3000A boots the BIOS** — re-scoped 2026-11-07 by the user's brief "PS1 and PS2 emulators in Swift (App Store-eligible)" ([SPEC.md](../assistant/SPEC.md), [ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md)). Construction's first two lines shipped with Milestone A. Two earlier plans for this table were retired the same day: 1a (one game per console through the installed emulators; its first run is in [Milestone C](../assistant/MILESTONES.md#milestone-c--the-re-vision)) and track 2 (GPL ports of SwanStation; cancelled when the brief made GPL emulators' source off limits).

Track 3 follows the brief's first tasks, in order: the JIT spike (3a, shipped 2026-11-07: [Milestone E](../assistant/MILESTONES.md#milestone-e--jit-under-the-app-store-routine)), the package skeleton with both build routines and the library app's retirement (3b, shipped 2026-11-07: [Milestone F](../assistant/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)), then the PS1 milestone — TraceKit (3c), the reference's and the oracle's traces (3d), the R3000A (3e, gated by A2's provenance check), the console (3f) and the gate (3g). The evidence behind it — ProjectPSX's and Play!'s licences and layout, the missing .NET SDK, ps1-tests' four CPU programs and their real-hardware logs, iStation's own Swift hot-path benchmark — is in [Milestone D](../assistant/MILESTONES.md#milestone-d--the-app-store-re-vision). The user's calls of 2026-11-07 (MIT, a fresh start, the brief's milestone) are dated decisions in each document; the rest are `[default: …]`; the last `[user]` call (3d: the .NET SDK) and every `[default: …]` were answered on 2026-11-07, before the group's run. **Every core item is built by a session that has never read a GPL emulator's source** ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md) §3). When 3g ships, this table is empty and v0.0.1 is released.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 3c | TraceKit — the trace format and the first divergence between two traces | v0.0.1 | [`v0.0.1/tracekit.md`](v0.0.1/tracekit.md) | 🟢 |
| 3d | The reference and the oracle — ProjectPSX with trace logging; SwanStation unmodified, recorded from outside | v0.0.1 | [`v0.0.1/reference-and-oracle-traces.md`](v0.0.1/reference-and-oracle-traces.md) | 🔒 3c |
| 3e | The R3000A interpreter — ported from ProjectPSX, generic over its bus | v0.0.1 | [`v0.0.1/r3000a-interpreter.md`](v0.0.1/r3000a-interpreter.md) | 🔒 A2, 3c |
| 3f | The PS1 console — memory map, interrupt controller, timers, DMA and the devices the BIOS needs | v0.0.1 | [`v0.0.1/ps1-console.md`](v0.0.1/ps1-console.md) | 🔒 3e |
| 3g | Gate: the BIOS boots — ps1-tests' CPU tests pass and the guest-state trace matches SwanStation's (the user's run) | v0.0.1 | [`v0.0.1/bios-boots.md`](v0.0.1/bios-boots.md) | 🔒 3d, 3f |
