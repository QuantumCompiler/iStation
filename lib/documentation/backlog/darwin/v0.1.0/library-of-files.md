# The library, before discs can be read

**What / why.** The design's library is the Mac app's home once a BIOS is kept:
- **The window:** a sidebar (All Games ⌘1, Recently Played ⌘4, BIOS ⌘6, and Tools ⌘7 in personal builds), a table and a grid of games, and a Game info inspector (⌘I).
- **Adding games:** Add Games… (⌘O) and Add Folder… (⇧⌘O), the latter a job with steps, Stop, and a Scan Again that skips what was already added.
- **Managing them:** search, rename, Remove from Library… (confirmed, with what it deletes under Details), and a moved file that offers Locate….

v0.1.0 builds it to the design's **Today** level. Disc images (.cue, .iso, .m3u) are listed by name, format and size, with Console and Serial "Unknown" and Play off ("Discs play from v0.2.0."), because the disc readers aren't in a product the app links (G2, 6c) and the console has no CD-ROM drive (G9, 6d). A PS-EXE is recognized today (`PSEXE(bytes:)`, contract row C18) and plays through 6a's `boot(exe:)`. That is the path v0.1.0's gate takes: a homebrew PS-EXE drawing in the macOS app. Measured, not guessed, 2026-11-21 (probe): `PSEXE(bytes:)` threw `tooShort` for 10 bytes and `notAnEXE` for 4,096 zero bytes. The names and sizes the design shows are placeholders; nothing is fetched, and there is no artwork.

**Core constraint(s).**
- No Sony files or games anywhere in the repository: fixtures are built in code, never a disc image.
- Tests and previews never touch the real home folder; the store writes only inside a `Sandbox` in tests.
- The user's data stays readable: `library.json` decodes every field with a default and keeps a recorded fixture per released shape ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- View-models import no UI toolkit; every visual comes from `styles` (5a).
- A new place is a module with its row, test directory, `EmuKit` membership, card line, ADR 0002 row and shared scheme ([ADR 0017](../../../adrs/darwin/every-presentation-module-has-its-scheme.md)).

**Seam + files.**
- Data `library` (5c's): games join the store, each with its bookmark, file name, folder, format, size, added date, last played and a library-only name. A stale bookmark is reported, not dropped.
- Presentation, new place `library`: `LibraryViewModel` (navigation, selection, search, view mode, inspector), `ScanViewModel` driving `JobSheet` (5a), `LibraryView` (`Table`, `LazyVGrid`, `.inspector`, `.searchable`), with previews per state.
- The macOS app target: imported type declarations for .cue, .bin, .m3u and PS-EXE; the File menu's and sidebar's keys; the opening job for a PS-EXE (open the file, then power on 5b's session with the BIOS and the EXE — the session gives it to `boot(exe:)` right after `powerOn(bios:)`, before the first frame runs, as the shell is entered once per power-on — then the player of 5b).
- Tests: `tests/data/library/` (games round trip, stale bookmarks, fixture), `tests/presentation/library/` (filters, search, rename, remove, scan steps, Stop and Scan Again without duplicates, Play enabled only for a PS-EXE today).

**Reference.** The design:
- **Boards:** `Mac-LibraryEmpty`, `Mac-TodayLibrary`, `Mac-LibraryGrid`, `Mac-LibraryInspector`, `Mac-LibrarySearchEmpty`, `Mac-LibraryMissing`, `Mac-RemoveConfirm`, `Mac-Rename`, `Mac-LibraryMin`, `Mac-LibraryLight`, `Mac-LibraryContrast`, `Mac-ScanPicker`, `Mac-ScanRunning`, `Mac-ScanStopped` and `Mac-ScanDone`. The scan boards' read step and results are 5h's.
- **Contract rows:** C11–C13, C18–C20, C47, C51–C53.
- **Layout page:** the breakpoints. Under 880 points of content the Format column goes, under 700 Last played, and under 1100 points of window Game info hides the sidebar.
- **Scripted flows:** "add a folder" and "refusals" in `tools/check.mjs`, and "today", whose PS-EXE takes the 3-step opening job to the player and whose Reset boots it again.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, moving game import from v0.2.0 into v0.1.0 (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: the library is `library.json` in the app's container through the Data `library` store, every field defaulted: one file, versioned, as save states and cards will be (the default, confirmed by the user).
- 2026-11-22: Add Folder looks for .cue, .iso, .m3u and .exe files, groups an .m3u's discs under it, and skips the .bin tracks a .cue names (the default, confirmed by the user).
- 2026-11-22: no artwork and no titles from a database: a game is named by its file and can be renamed, and nothing leaves the Mac (contract row C47, verify), as the design has it (the default, confirmed by the user).
- 2026-11-22: discs are listed today, with Play off and the reason, rather than hidden, so the user sees what they added; 5h fills in console and serial (the default, confirmed by the user).
- 2026-11-22: each screen is checked against its board by rendering its previews to images and comparing them with the board in the built-in browser; no app is launched for the check (the user's call, before the group run).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** Store tests: round trip, defaults from a recorded fixture, and a stale bookmark kept and flagged. View-model tests: the scan's steps over a `Sandbox` folder built in the test (finding .cue, .iso, .m3u and .exe files, one entry for an .m3u and its discs, no entry for a .cue's .bin tracks), Stop, Scan Again skipping added games with no duplicates, search with no results, remove confirming first, Play enabled only for a recognized PS-EXE. A preview per board's state.

**Acceptance criteria:**
- [ ] Adding files and folders, search, rename, remove, the grid, Game info and Locate… work as the boards above show, with their keys.
- [ ] A PS-EXE plays: the opening job runs, then the player shows its frames counting (its picture once 5g lands).
- [ ] Discs show Console and Serial "Unknown" and Play off with "Discs play from v0.2.0.", as `Mac-TodayLibrary` shows.
- [ ] The breakpoints hold at 800 × 560 (`Mac-LibraryMin`) and with Game info open at 1280 wide.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5c and 6a. Reading discs (console, serial, PS1 and PS2 filters, scan results) is 5h's; playing them is 5i's; memory cards in the sidebar are 5k's.
