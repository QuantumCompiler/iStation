# Playing discs

**What / why.** With discs crossing the interface (6d), Play works for discs.
- **The opening job:** open the file through its bookmark, read its SYSTEM.CNF, power on with the BIOS, insert the disc ("Disc 1 of 3" for a playlist), then the player. Cancel (⌘.) stops it.
- **Reset:** inserts the disc again after powering on, and its alert's Details names both calls.
- **Multi-disc games:** offer the next disc.
- **The library:** "Discs play from v0.2.0." goes away for PS1 discs; PS2 discs keep their refusal (5h).

**Core constraint(s).**
- The user's files are read only, through their bookmarks, never copied.
- View-models import no UI toolkit; the job draws through `JobSheet` (5a).
- No real game in tests: discs are in-memory fakes behind the session protocol.

**Seam + files.**
- Business `session` (5b: a Business module, decided 2026-11-22, importing only the standard library and Swift concurrency, its Core constraint): power on and insert (6d), each step reported for the job, and disc swap for a playlist. Opening the file through its bookmark and identifying it (6c's `DiscIdentity.read(url:)`) are an opener the macOS app target supplies, reported as the job's first two steps.
- Presentation `library` and `player`: Play for discs, the opening job, the Reset alert's Details, and a disc-change command in the Game menu for multi-disc games.
- Tests: `tests/business/session/` (the steps, cancel, swap); `tests/presentation/library/` (Play enabled for PS1 discs, refused for PS2 and missing files).

**Reference.** The design: boards `Mac-PlayerOpening`, `Mac-ResetConfirm`, `Mac-PlayerRunning`; contract rows C06, C12 and C30; the scripted flow "play" in `tools/check.mjs`.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: Game › Change Disc lists an .m3u's discs, the current one checked] The design shows the opening job's "Disc 1 of 3" but no swap control: add its board in the design in the same change (the design's CLAUDE.md).
- [default: Reset re-inserts the disc that was in the drive]

**Guardrail(s).** Session tests over in-memory discs: each step in order, cancel at each step leaves no console running, a swap reaches the console. View-model tests for Play's enabled state per game.

**Acceptance criteria:**
- [ ] A PS1 disc plays from the library through the opening job, matching `Mac-PlayerOpening` then `Mac-PlayerRunning`.
- [ ] Reset and disc change work for a multi-disc game; the Change Disc board is in the design.
- [ ] A PS1 game the user owns boots in the macOS app (v0.2.0's gate: the user's run).
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 5, gated on 6d and 5h.
