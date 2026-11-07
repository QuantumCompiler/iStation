# First boot — one PS1, PS2 and PS3 game boot from iStation and return on exit

**What / why.** The v0.0.1 gate (the user's Build Roadmap, phase 1): iStation must boot a real game from each console and come back when it closes, before anything else is worth building. Construction made the scaffold compile and pass its tests (Milestone A), but everything that touches a real emulator is unverified, because no test may run one:

- The flags in [reference/emulator-launch-contract.md](../../reference/emulator-launch-contract.md) were read from the emulators' argument parsers on 2026-10-25 and have never been run.
- A session ends when the emulator process exits: DuckStation and PCSX2 quit on game shutdown because of `-batch`; whether RPCS3 with `--no-gui` exits when its game does is unverified.
- `LaunchServicesLookup` (`source/infrastructure/bundles/AppBundles.swift`), the bundle-ID fallback for finding emulators, is never exercised by tests.
- Settings' Choose… uses `.fileImporter` with `.applicationBundle` (`source/presentation/settings/Views/SettingsView.swift`); that it accepts an emulator's `.app` is unverified.
- The app itself was built, and smoke-launched only over a sandbox home (Milestone A); it has not run against a real library.

Installed on the user's Mac as of 2026-11-02 (read from each app's `Info.plist`; nothing launched): DuckStation `0.1-10193-g86bf55162` (universal), PCSX2 `v2.4.0` (x86_64 only, so it runs under Rosetta), RPCS3 (no `CFBundleShortVersionString`; arm64). All three are in /Applications, and their bundle identifiers and executable names (`DuckStation`, `PCSX2`, `rpcs3`) match the launch contract.

The run is the user's: it needs their installed emulators, their BIOS files and their games. The builder prepares it, walks the user through it, and fixes what it finds.

**Core constraint(s).** Emulators stay separate programs, driven only by their flags ([ADR 0008](../../adrs/emulators-are-separate-programs.md)): a flag that turns out wrong is corrected against the emulator's own source, never worked around. No game, BIOS or library file from the run is committed (⚠ in CLAUDE.md). The library file stays compatible ([ADR 0007](../../adrs/backwards-compatibility.md)).

**Seam + files.** No planned code. A fix lands in the module that owns its seam: flags in `source/data/emulators/LaunchContract.swift`; executable resolution in `source/infrastructure/bundles/AppBundles.swift`; session timing and the one-game rule in `source/business/launching/` and `source/business/library/Library.swift`; the chooser in `source/presentation/settings/`. Each fix brings its test in the mirrored `tests/` directory.

The run, on the user's Mac:

1. `cd src/istation && ./scripts/build-app.sh`, then open `build/iStation.app`.
2. Settings (⌘,): each emulator found, or chosen with Choose…; Detect Installed Emulators fills the rest.
3. Add the folders holding one PS1, one PS2 and one PS3 game (a PS3 disc folder or ISO, or an RPCS3-installed title).
4. For each console: check the sidebar count and the tile's title and serial; double-click; play briefly; quit from inside the game or the emulator; iStation comes back to the front, and the tile shows its play time after a minute.
5. Record each emulator's version, and each game's console, serial and file type (not its title or path), in MILESTONES ([ADR 0009](../../adrs/previews-never-carry-the-users-library.md)).

**Reference.** The Build Roadmap's phase-1 checklist (2026-10-26). The launch contract's sources: DuckStation `src/duckstation-qt/qthost.cpp`, PCSX2 `pcsx2-qt/QtHost.cpp`, RPCS3 `rpcs3/rpcs3.cpp` and `Emu/System.h`.

**Decisions made** (dated):
- 2026-10-31: the gate is run by the user on their own Mac; the agent prepares it and records the result (the construction's rule: real emulator and game runs are the user's to start).
- 2026-10-31: placed as v0.0.1's only remaining item (the user's call: one version per phase).
- 2026-11-02: nothing from the user's library becomes preview data; the previews keep the sample games (the user's call; recorded as [ADR 0009](../../adrs/previews-never-carry-the-users-library.md)).
- 2026-11-02: a problem the run finds that is bigger than a one-line fix becomes its own Maintenance item, and this gate gains it as a 🔒 gate until it ships; one-line fixes land inside 1a (the default, confirmed by the user).
- 2026-11-02: skipped in the `/istation-backlog-execute-group v0.0.1` run, which built nothing; 1a waits for the user's run (the user's call).

**Open calls:** none — both answered 2026-11-02.

**Guardrail(s).** Every flag fix updates `LaunchContractTests` and the reference document in the same change; every other finding that can be tested headlessly becomes a regression test in its module's tests — inside 1a for a one-line fix, in its own Maintenance item otherwise.

**Acceptance criteria:**
- [ ] DuckStation, PCSX2 and RPCS3 are set up in Settings — found automatically or chosen.
- [ ] A PS1 game boots fullscreen from a double-click, its emulator quits back to iStation, and its play time is added.
- [ ] The same for a PS2 game.
- [ ] The same for a PS3 game.
- [ ] Each emulator's version and each game's console, serial and file type are recorded in MILESTONES.

**Scope note.** Earmarked for v0.0.1, its last item: shipping it empties the table, and v0.0.1 is released (merged into `stable`, tagged). No gate today; a larger problem the run finds becomes a Maintenance item and this item's gate. Out of scope: cover art (v0.1.0), CHD (v0.2.0), PCSX-Redux (v1.0.0).
