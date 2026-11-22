# iStation — Backlog

**The work queue: one document per work item.** Every feature and fix that has been discussed and specced but **not yet built** — the layer between the loose ideas in [ROADMAP.md](../../assistant/darwin/ROADMAP.md) and the shipped record in [MILESTONES.md](../../assistant/darwin/MILESTONES.md). There is no separate TODO file: an agent takes an item from the index below and **implements it straight from its document**.

## Lifecycle

1. A feature is **discussed in chat** and gets a line on [ROADMAP.md](../../assistant/darwin/ROADMAP.md) (and a [SPEC.md](../../assistant/darwin/SPEC.md) revision if it changes product shape).
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

Rows are in suggested build order. **Gates** name only pending items; an item builds on everything shipped plus its gate chain; no cycles. **Split first** items are groomed into their sub-documents before anyone builds. Moving an item between tables is a `git mv`, its row, its Version cell and its links. Same-table links are bare filenames; cross-table links `../<table-dir>/<file>`; links out of the backlog climb to `lib/documentation/` — `../../../assistant/darwin/…` from a table's directory, one `../` more from an OS folder's (this index itself: `../../assistant/darwin/…`).

**Ids spent so far:** track 1 (`1a`), track 2 (`2a`–`2e`, cancelled), track 3 (`3a`–`3g`), track 4 (`4a`–`4f`), track 5 (`5a`–`5o`), track 6 (`6a`–`6j`); `M1`, `M2` (cancelled); `A1` (cancelled), `A2`.

### Architecture

The structural reshaping queue, claimable by name at any time. A1 (licence tags for GPL modules) was cancelled the day it was written, 2026-11-07, when the App Store brief made all shipped code permissive. A2 comes from that brief: [ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md) makes iStation's own code MIT and requires every ported file to keep its reference's notice; A2 gave that its check before the first ported module (3e), and shipped 2026-11-07 ([Milestone H](../../assistant/darwin/MILESTONES.md#milestone-h--provenance-headers-and-notices)); the table is empty.

| # | Item | Version | File | Status |
|---|---|---|---|---|

### Maintenance

The release-agnostic upkeep queue — bugs, polish, performance, developer ergonomics — claimable by name at any time. Empty: M1 (an unreadable library file) and M2 (the emulator chooser's start folder) belonged to the library app and were cancelled with it, 2026-11-07.

| # | Item | Version | File | Status |
|---|---|---|---|---|

### v0.1.0

**Tracks 5 and 6: the app's design, then the interface it needs.** On 2026-11-21 the Apple apps were designed as a Claude Design canvas, [iStation App Design](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu), mirrored in [`design/darwin/`](../../design/darwin/README.md). It holds one prototype driven by a clock and 65 boards, one per screen and state, each mounting the prototype at a named start. Its Contract page maps every part to what backs it: of 54 rows, 12 are ready, 14 the app does from what exists, 25 are gaps and 3 still need verifying. It numbers 13 gaps (G1–G13), each with the additive change that closes it and what the app draws until then; the **Today** boards draw those fallbacks.

The ready rows were checked against the backend that day with content built in code, never a Sony file. A probe package linking `PS1Core` and `EmuKit` by path showed `PS1Console` powering on, running 60 frames in 0.014 s and refusing 1,000 bytes with `biosSize(1000)`; the macOS app carries six acknowledgements and the iOS app two. `istation-run` (release) recorded 136 M instructions/s on its CPU-check image, exit 3 for an EXE that never started, and "first divergence at record 0 of 56689 and 56625: word" for two different images. The disc readers' tests passed. The design's own checks (`design/darwin/tools/check.mjs`) run every start preset through 30 clock ticks, eight scripted flows and 29 shortcuts, and render all 137 pages in headless Chrome.

Split, the user's calls of 2026-11-21:
- **Track 5:** a screen or flow per document. v0.1.0 builds the design's Today parts, which moves BIOS and game import here from v0.2.0.
- **Track 6:** an interface item per gap, adding the `PS1Console` members its screens need, with core internals left as open calls. The screens are gated on them.

Three interface items are **split first** (6b here; 6d, 6g in v0.2.0; 6i in v0.3.0), because the device behind each, the GPU, the CD-ROM drive, every device's state and the SPU, is ROADMAP work with no document yet: each names its sub-documents. Each document carries the design's decisions as `[default: …]` calls and the user's open ones as `[user]`. G13, the PS2 core, waits for v2.x's spike; until then 5h refuses PS2 discs with the reason. v0.1.0's other ROADMAP lines (DMA and timers in full, VRAM and the boot's RAM recorded from SwanStation) get their documents when the table is groomed.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 5a | **The design's tokens in the styles module** — every color, type style, space, radius and duration from `tokens.json`, and the shared components | v0.1.0 | [design-tokens-in-styles.md](v0.1.0/design-tokens-in-styles.md) | 🟢 |
| 6a | **The narrow interface: boot a PS-EXE, the BIOS's shell, debug values** — gaps G5, G6 and G10, forwarding to what `PS1Machine` has | v0.1.0 | [interface-boot-shell-and-debug.md](v0.1.0/interface-boot-shell-and-debug.md) | 🟢 |
| 5b | **The console session and the player** — the runner off the main actor, and the player with its HUD, pause, reset and stop | v0.1.0 | [console-session-and-player.md](v0.1.0/console-session-and-player.md) | 🔒 5a |
| 5c | **First run and the BIOS** — welcome, the BIOS check job, the wrong-size refusal and the BIOS pane, kept by bookmark | v0.1.0 | [first-run-and-the-bios.md](v0.1.0/first-run-and-the-bios.md) | 🔒 5b, 6a |
| 5d | **The library, before discs can be read** — files, folders, search, Game info and PS-EXEs that play | v0.1.0 | [library-of-files.md](v0.1.0/library-of-files.md) | 🔒 5c, 6a |
| 5e | **Settings, Acknowledgements, About, menus and shortcuts** — the other windows and every key | v0.1.0 | [windows-settings-and-shortcuts.md](v0.1.0/windows-settings-and-shortcuts.md) | 🔒 5a |
| 5f | **The personal build's Tools and debug drawer** — console, TTY, trace recording and comparison, personal builds only | v0.1.0 | [personal-tools.md](v0.1.0/personal-tools.md) | 🔒 5b, 6a |
| 6b | **The narrow interface: the picture and VRAM** — gap G1, split first: the GPU, the frame member and its Metal presentation | v0.1.0 | [interface-picture.md](v0.1.0/interface-picture.md) | 🟢 |
| 5g | **The picture on screen** — frames in the player, Settings › Video, screenshots and the VRAM tab | v0.1.0 | [the-picture-on-screen.md](v0.1.0/the-picture-on-screen.md) | 🔒 6b, 5e, 5f |

### v0.2.0

Tracks 5 and 6 continue (the v0.1.0 preamble tells the story): the library reads discs, discs play, and pads, memory cards and save states arrive, each interface item ahead of its screen. 6d and 6g are split first: the CD-ROM drive (ROADMAP v0.2.0's first line) and every device's saved state get their own documents before building. The GTE, SPU and MDEC line has no document yet.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 6c | **The disc readers in a product, and a disc's identity** — gap G2: `DiscKit`, and console and serial from a .cue, .iso or .m3u | v0.2.0 | [interface-disc-readers.md](v0.2.0/interface-disc-readers.md) | 🟢 |
| 5h | **The library reads discs** — console and serial, PS1 and PS2 filters, the scan's results, PS2 refused with the reason | v0.2.0 | [library-reads-discs.md](v0.2.0/library-reads-discs.md) | 🔒 6c, 5d |
| 6d | **The narrow interface: discs** — gap G9, split first: the CD-ROM drive, then `insertDisc`, `ejectDisc` and the lid | v0.2.0 | [interface-discs.md](v0.2.0/interface-discs.md) | 🟢 |
| 5i | **Playing discs** — the opening job, reset with the disc, multi-disc games | v0.2.0 | [playing-discs.md](v0.2.0/playing-discs.md) | 🔒 6d, 5h |
| 6e | **The narrow interface: pads** — gap G4: the ports device, `setPad`, and GameController input | v0.2.0 | [interface-pads.md](v0.2.0/interface-pads.md) | 🟢 |
| 5j | **Controllers** — Settings › Controllers, the mapping, the keyboard, the HUD's ports | v0.2.0 | [controllers-settings.md](v0.2.0/controllers-settings.md) | 🔒 6e, 5e |
| 6f | **The narrow interface: memory cards** — gap G8: the card device, its bytes in and out, and a reader for its directory | v0.2.0 | [interface-memory-cards.md](v0.2.0/interface-memory-cards.md) | 🔒 6e |
| 5k | **Memory cards** — the pane, its empty state, Move to Trash, and the card policy in Settings | v0.2.0 | [memory-cards-pane.md](v0.2.0/memory-cards-pane.md) | 🔒 6f, 5e, 5d |
| 6g | **The narrow interface: save states** — gap G7, split first: a versioned format and every device's state | v0.2.0 | [interface-save-states.md](v0.2.0/interface-save-states.md) | 🔒 6d, 6f |
| 5l | **Save states** — eight slots, replace and load confirmed, older formats refused | v0.2.0 | [save-states-sheet.md](v0.2.0/save-states-sheet.md) | 🔒 6g, 5g |
| 6h | **The narrow interface: the video standard** — gap G12: PAL or NTSC from GPUSTAT, pacing, and the HUD's target | v0.2.0 | [interface-video-standard.md](v0.2.0/interface-video-standard.md) | 🔒 6b |

### v0.3.0

Tracks 5 and 6 continue: sound, and the choice of renderer once the Metal renderer exists. 6i is split first: the SPU's port belongs to v0.2.0's "GTE, SPU and MDEC" line. ROADMAP v0.3.0's Metal renderer has no document yet; 6j gains it as a gate when it is written.

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 6i | **The narrow interface: sound** — gap G3, split first: the SPU, `drainAudio`, and AVAudioEngine output | v0.3.0 | [interface-sound.md](v0.3.0/interface-sound.md) | 🟢 |
| 5m | **Sound settings** — Settings › Audio: volume, muting, output | v0.3.0 | [audio-settings.md](v0.3.0/audio-settings.md) | 🔒 6i, 5e |
| 6j | **Choosing the renderer** — gap G11: the renderer setting and its picker, after the Metal renderer | v0.3.0 | [interface-renderer-choice.md](v0.3.0/interface-renderer-choice.md) | 🔒 5g |

### v0.4.0

Track 5 continues on the iPhone: the same view-models, the iPhone's views. Both items sit in [`ios/`](ios/README.md).

| # | Item | Version | File | Status |
|---|---|---|---|---|
| 5n | **The iPhone app: first run, library and settings** — portrait, the Files picker, a large-title list | v0.4.0 | [iphone-library-and-settings.md](ios/v0.4.0/iphone-library-and-settings.md) | 🔒 5c, 5e, 5h |
| 5o | **The iPhone player** — landscape, the on-screen pad, the pause sheet and save states | v0.4.0 | [iphone-player.md](ios/v0.4.0/iphone-player.md) | 🔒 5n, 5g, 6e, 5l |
