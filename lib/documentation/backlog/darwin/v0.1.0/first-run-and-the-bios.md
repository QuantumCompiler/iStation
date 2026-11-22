# First run and the BIOS

**What / why.** The first thing the Mac app needs is the user's own BIOS. Today it opens on a player that says "Nothing to play yet." and offers no way to choose one. This item builds the design's first run:
- **Welcome:** a screen that says what's needed and why, written for someone who has never heard of a BIOS, with Choose BIOS File… (⌘O).
- **The BIOS check job:** read the file, check its size, work out its SHA-1 fingerprint, power on and run 60 frames, then run on until it reaches its shell (6a), refusing it if that hasn't happened by frame 600. The job has a Stop.
- **Wrong size:** the refusal gives the file's size in words, with the backend's own error under Details.
- **The BIOS pane** (⌘6): the file, its size and fingerprint, its folder, when it was checked, and Run the BIOS, Choose Another BIOS… and Show in Finder.

The BIOS is kept by a bookmark, never copied. Measured, not guessed, 2026-11-21 (probe over `PS1Core`): `powerOn(bios:)` with 1,000 bytes threw `biosSize(1000)`, with 524,288 bytes it powered on. The repository names a BIOS only by its size and hash, and the design does the same. Found, 2026-11-21: the macOS App Store entitlements hold `com.apple.security.files.user-selected.read-only` (`apps/macos/AppStore.entitlements:6`) but not `com.apple.security.files.bookmarks.app-scope`, the entitlement Apple documents for app-scoped bookmarks, which keep access across launches. Whether the App Store build needs it is unproven (contract row C11, tagged verify), so this item probes it.

**Core constraint(s).**
- iStation never ships, downloads or commits Sony's files. The welcome copy explains the BIOS but never links to one: its guidance is one sentence (the file comes from your own console, iStation can't provide one, it expects 512 KB), naming no tool or method. Tests build their images in code.
- Tests and previews never touch the real home folder; the store's tests write only inside a `Sandbox`.
- The user's data stays readable: the stored BIOS record decodes with defaults ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5), with a recorded fixture.
- View-models import no UI toolkit: the file chooser is a `Bool` the view binds `.fileImporter` to.
- An entitlement change follows DEVELOPER.md's "Changing an entitlement" recipe, and the App Store entitlements stay clean (`appStoreEntitlementsAreClean`).

**Seam + files.**
- Data, new module `library` (`Module(.data, "Library")`): `LibraryStore`, a versioned `library.json` in the app's container (on the unsandboxed macOS personal build, its own Application Support folder), at a URL the app target hands in, holding the BIOS record (file name, folder, size, SHA-1, checked date, bookmark data). The fingerprint is worked out with CryptoKit when the BIOS is recorded. 5d adds the games to the same store.
- Presentation, new place `bios`: `WelcomeView`, `BIOSCheckViewModel` driving `JobSheet` (5a) over `ConsoleSession` (5b) and `reachedShell` (6a), `BIOSPaneView`; previews per state.
- The macOS app target: the first window shows Welcome until a BIOS is kept; `AppStore.entitlements` gains `com.apple.security.files.bookmarks.app-scope` only once the user's probe run needs it, and then CLAUDE.md's Stack line and SPEC.md's Build routines table name app-scoped bookmarks in the same change.
- `lib/src/darwin/tools/bookmark-probe/` (new, never shipped): a one-file sandboxed macOS app, as `tools/jit-probe/` is, that keeps a security-scoped bookmark to a file the user picks and reports, after a relaunch, whether it still opens; its `build.sh` signs it ad-hoc with the App Store build's macOS entitlements under its own identifier, and its README holds the run and its results table.
- Tests: `tests/data/library/` (round trip, defaults, fixture), `tests/presentation/bios/` (each step, stop, wrong size, no shell in 600 frames, done).
- The design, in the same change (its CLAUDE.md): Welcome's copy (`Mac-Welcome`) and the BIOS pane's note (`Mac-BiosPane`) in `html/main.html` take the decided wording — what a BIOS is, briefly, and the one sentence of guidance — in place of Welcome's "a 512 KB file you copy from a console you own" and the pane's "you copy it from a console you own"; the no-shell refusal gets its preset in `PRESETS` and `PRESET_NAMES`, a board `html/Mac-BiosNoShell.dc.html` copied from `Mac-BiosWrongSize`, its `json/canvas.json` entry and `order`, "No shell in 600 frames" in the First run row's Refused cell of `Layout.dc.html`'s state table (`STATES`), a branch in the failed job's summary, and `Processes.dc.html`'s "Check a BIOS" flow running until `reachedShell`, refused at 600 frames; the design README's board count goes up by one; contract row C11 drops its verify tag for macOS once the probe below has run, with how in `EVIDENCE`, and the board's CALLS drop Audience and BIOS guidance (answered 2026-11-22) (`html/Contract.dc.html`).
- [reference/darwin/README.md](../../../reference/darwin/README.md): its note on the retired library app's `library.json` says today's `library.json` (5c, 5d) is a new format, unrelated to it.

**Reference.** The design: boards `Mac-Welcome`, `Mac-BiosPicker`, `Mac-BiosChecking`, `Mac-BiosWrongSize`, `Mac-BiosDone`, `Mac-TodayBiosDone` (the wording before 6a), `Mac-BiosPane`, `Mac-LibraryEmpty` (where Continue lands); contract rows C01, C02, C05, C09–C11, C47; the scripted flow "first run" in `tools/check.mjs`. In-house: `istation-run` reads a BIOS by path and never copies it.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, moving BIOS import from v0.2.0 into v0.1.0 (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: the welcome copy is for App Store strangers, as the design has it: what a BIOS is and why iStation needs yours, briefly, in plain words, ready for v1.0.0 as written (the user's call).
- 2026-11-22: the BIOS guidance is one plain sentence: the file comes from your own console, iStation can't provide one, and it expects a 512 KB file — no instructions, no tools named, no links (the user's call).
- 2026-11-22: a bookmark is probed across relaunches under the App Store routine first, and `com.apple.security.files.bookmarks.app-scope` joins the macOS App Store entitlements only if the probe needs it; this closes contract row C11's verify for macOS (the default, confirmed by the user).
- 2026-11-22: the app's fingerprint is SHA-1, shown in groups of four, as the design shows; the gate's reports keep naming a BIOS by its size and SHA-256 (`tools/gate/run.sh`, under [ADR 0021](../../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md) §4's size and hash) (the default, confirmed by the user, with SHA-256 offered).
- 2026-11-22: if the shell isn't reached within 600 frames, the check says "Your BIOS powered on but didn't reach its shell in 600 frames. Choose another file." and keeps nothing; the design gains this state's preset and board in the same change (the design's CLAUDE.md) (the default, confirmed by the user).
- 2026-11-22: the design's changes land in its local mirror, pass its checks and are published to the canvas as this item lands, keeping the two identical (the user's call, before the group run).
- 2026-11-22: each screen is checked against its board by rendering its previews to images and comparing them with the board in the built-in browser; no app is launched for the check (the user's call, before the group run).
- 2026-11-22: the App Store bookmark probe is prepared, not run, by this item: a small sandboxed probe app under `lib/src/darwin/tools/bookmark-probe/` with the macOS App Store entitlements and its own identifier (never the App Store app's container), its run written up in its README. This item ships with `com.apple.security.files.bookmarks.app-scope` left off; the user's one run (choose any file that isn't Sony's, quit, relaunch) decides whether it is added, as with the JIT runs (the user's call, before the group run).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** Store tests round-trip the BIOS record and decode an older shape with defaults from a recorded fixture. View-model tests cover each job state over a fake session, a wrong-size refusal that quotes the byte count, a BIOS that doesn't reach its shell in 600 frames refused and not kept, and Stop keeping nothing. A preview per state matches its board.

**Acceptance criteria:**
- [ ] A first launch shows Welcome; choosing a 524,288-byte file runs the check to "Your BIOS works: it reached its shell." and lands on the empty library.
- [ ] Welcome says in plain words what a BIOS is and why iStation needs yours, and its guidance is the one sentence decided 2026-11-22 (the file comes from your own console, iStation can't provide one, 512 KB), naming no tool, method or link; the design's `Mac-Welcome` and `Mac-BiosPane` say the same.
- [ ] A file of another size is refused with its size and `PS1Error.biosSize(<n>)` under Details, as `Mac-BiosWrongSize` shows.
- [ ] A 524,288-byte image that never reaches its shell is refused after 600 frames with "Your BIOS powered on but didn't reach its shell in 600 frames. Choose another file.", nothing kept; the design has this state's preset and board.
- [ ] The BIOS pane shows the SHA-1 fingerprint in groups of four.
- [ ] The BIOS pane matches `Mac-BiosPane`; Run the BIOS opens the player (5b) at frame 0.
- [ ] The bookmark probe (`tools/bookmark-probe/`) builds with the App Store build's macOS entitlements, and its README prepares the user's relaunch run; `AppStore.entitlements` gains `com.apple.security.files.bookmarks.app-scope`, and contract row C11 drops its verify tag for macOS, only once that run shows the need — until then both stay as they are, and the run is listed as the user's.
- [ ] The new modules have their rows, card lines, ADR 0002 rows, tests and schemes; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5b and 6a. Disc and game import are 5d's; the iPhone's first run is 5n's.
