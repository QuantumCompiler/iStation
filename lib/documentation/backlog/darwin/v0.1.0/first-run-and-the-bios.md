# First run and the BIOS

**What / why.** The first thing the Mac app needs is the user's own BIOS. Today it opens on a player that says "Nothing to play yet." and offers no way to choose one. This item builds the design's first run:
- **Welcome:** a screen that says what's needed and why, with Choose BIOS File… (⌘O).
- **The BIOS check job:** read the file, check its size, work out its SHA-1 fingerprint, power on and run 60 frames, then confirm it reached its shell (6a). The job has a Stop.
- **Wrong size:** the refusal gives the file's size in words, with the backend's own error under Details.
- **The BIOS pane** (⌘6): the file, its size and fingerprint, its folder, when it was checked, and Run the BIOS, Choose Another BIOS… and Show in Finder.

The BIOS is kept by a bookmark, never copied. Measured, not guessed, 2026-11-21 (probe over `PS1Core`): `powerOn(bios:)` with 1,000 bytes threw `biosSize(1000)`, with 524,288 bytes it powered on. The repository names a BIOS only by its size and hash, and the design does the same. Found, 2026-11-21: the macOS App Store entitlements hold `com.apple.security.files.user-selected.read-only` (`apps/macos/AppStore.entitlements:6`) but not `com.apple.security.files.bookmarks.app-scope`, the entitlement Apple documents for app-scoped bookmarks, which keep access across launches. Whether the App Store build needs it is unproven (contract row C11, tagged verify), so this item probes it.

**Core constraint(s).**
- iStation never ships, downloads or commits Sony's files. The welcome copy explains the BIOS but never links to one, and tests build their images in code.
- Tests and previews never touch the real home folder; the store's tests write only inside a `Sandbox`.
- The user's data stays readable: the stored BIOS record decodes with defaults ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5), with a recorded fixture.
- View-models import no UI toolkit: the file chooser is a `Bool` the view binds `.fileImporter` to.
- An entitlement change follows DEVELOPER.md's "Changing an entitlement" recipe, and the App Store entitlements stay clean (`appStoreEntitlementsAreClean`).

**Seam + files.**
- Data, new module `library` (`Module(.data, "Library")`): `LibraryStore`, a versioned `library.json` in the app's container holding the BIOS record (file name, folder, size, SHA-1, checked date, bookmark data). The fingerprint is worked out with CryptoKit when the BIOS is recorded. 5d adds the games to the same store.
- Presentation, new place `bios`: `WelcomeView`, `BIOSCheckViewModel` driving `JobSheet` (5a) over `ConsoleSession` (5b) and `reachedShell` (6a), `BIOSPaneView`; previews per state.
- The macOS app target: the first window shows Welcome until a BIOS is kept; `AppStore.entitlements` gains `com.apple.security.files.bookmarks.app-scope` if the probe below needs it.
- Tests: `tests/data/library/` (round trip, defaults, fixture), `tests/presentation/bios/` (each step, stop, wrong size, done).

**Reference.** The design: boards `Mac-Welcome`, `Mac-BiosPicker`, `Mac-BiosChecking`, `Mac-BiosWrongSize`, `Mac-BiosDone`, `Mac-TodayBiosDone` (the wording before 6a), `Mac-BiosPane`, `Mac-LibraryEmpty` (where Continue lands); contract rows C01, C02, C05, C09–C11, C47; the scripted flow "first run" in `tools/check.mjs`. In-house: `istation-run` reads a BIOS by path and never copies it.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, moving BIOS import from v0.2.0 into v0.1.0 (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [user] Audience: is the welcome copy for App Store strangers, who need to learn what a BIOS is, or for you first? The design assumes strangers, briefly.
- [user] BIOS guidance: how much to say about copying a BIOS from your own console, given iStation can't link to or host one?
- [default: probe a bookmark across relaunches under the App Store routine first, and add `files.bookmarks.app-scope` to the macOS App Store entitlements only if the probe needs it] This closes contract row C11's verify for macOS.
- [default: the fingerprint is SHA-1, shown in groups of four, as the design shows] It matches how the repository names BIOS files.
- [default: if the shell isn't reached within 600 frames, the check says "Your BIOS powered on but didn't reach its shell in 600 frames. Choose another file." and keeps nothing] The design doesn't draw this state yet: add its preset and board in the design in the same change (the design's CLAUDE.md).

**Guardrail(s).** Store tests round-trip the BIOS record and decode an older shape with defaults from a recorded fixture. View-model tests cover each job state over a fake session, a wrong-size refusal that quotes the byte count, and Stop keeping nothing. A preview per state matches its board.

**Acceptance criteria:**
- [ ] A first launch shows Welcome; choosing a 524,288-byte file runs the check to "Your BIOS works: it reached its shell." and lands on the empty library.
- [ ] A file of another size is refused with its size and `PS1Error.biosSize(<n>)` under Details, as `Mac-BiosWrongSize` shows.
- [ ] The BIOS pane matches `Mac-BiosPane`; Run the BIOS opens the player (5b) at frame 0.
- [ ] After a relaunch of the App Store build, the BIOS is still readable through its bookmark (the user's run, or the agent's with a BIOS image built in code).
- [ ] The new modules have their rows, card lines, ADR 0002 rows, tests and schemes; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5b and 6a. Disc and game import are 5d's; the iPhone's first run is 5n's.
