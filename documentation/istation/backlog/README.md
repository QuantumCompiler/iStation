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

**Ids spent so far:** track 1 (`1a`); `M1`, `M2`. No `A` id yet.

### Architecture

The structural reshaping queue, claimable by name at any time. Empty: the project was constructed in the layered shape (2026-10-31), so there was no carve to queue.

| # | Item | Version | File | Status |
|---|---|---|---|---|

### Maintenance

The release-agnostic upkeep queue — bugs, polish, performance, developer ergonomics — claimable by name at any time. M1 and M2 were found while porting the user's Code Scaffold into the layers at construction, 2026-10-31: M1 is inherited from the scaffold, M2 is a behavior the port itself changed.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| M1 | An unreadable library file is silently replaced — keep it aside and tell the user | maint. | [`maintenance/unreadable-library-file.md`](maintenance/unreadable-library-file.md) | 🟢 |
| M2 | The emulator chooser opens in /Applications again — lost in the move to `.fileImporter` | maint. | [`maintenance/app-chooser-start-folder.md`](maintenance/app-chooser-start-folder.md) | 🟢 |

### v0.0.1

Phase 1 of the user's Build Roadmap (2026-10-26): "until the scaffold compiles and boots a game from each console, nothing else is worth building." Its first two checklist lines (compile, tests green) shipped with the construction (Milestone A, 2026-10-31). What remains is the gate, which only the user can run: it needs their emulators and their games. When 1a ships, this table is empty and v0.0.1 is released.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 1a | First boot — point iStation at the emulators; one PS1, PS2 and PS3 game boot and return on exit | v0.0.1 | [`v0.0.1/first-boot-gate.md`](v0.0.1/first-boot-gate.md) | 🟢 |
