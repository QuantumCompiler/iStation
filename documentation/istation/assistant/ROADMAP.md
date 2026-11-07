# iStation — Roadmap

How we work: features are discussed in chat, written up here (and in [SPEC.md](SPEC.md)), given their own document in [`backlog/`](../backlog/README.md) when specced, built straight from that document, and recorded in [MILESTONES.md](MILESTONES.md).

**Version scheme:** one version per phase of the user's Build Roadmap (2026-10-26; the user's call, 2026-10-31) — v0.0.1 first build, v0.1.0–v0.4.0 the four feature phases, v1.0.0 the launcher release, v2.0.0 bundled emulators; patches `v0.x.y` between. Each release is built on its own branch and merged into `stable`, tagged, when its backlog table empties. No dates: this is a personal project.

Phases v0.1.0, v0.2.0 and v0.3.0 are independent and can be built in any order; v0.4.0 is the largest and easiest once per-game settings exist.

---

## In progress

### v0.0.1 — First build

Until the scaffold compiles and boots a game from each console, nothing else is worth building. Construction carved the scaffold into the four layers, fixed it until it compiled and its tests passed, and proved the architecture checks ([Milestone A](MILESTONES.md#milestone-a--the-construction)); the gate needs the user's own emulators and games.

- [x] **The scaffold compiles** — open the package and fix the compile errors ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [x] **The tests are green** — `swift test` ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [ ] **First boot** — point iStation at the emulators; one PS1, one PS2 and one PS3 game boot and return on exit ([1a](../backlog/v0.0.1/first-boot-gate.md))

## Planned

### v0.1.0 — Cover art and titles

- [ ] Pick a metadata source keyed by serial (title, cover image) — a decision needed, below
- [ ] Cache images under `~/Library/Application Support/iStation/covers`
- [ ] Show the cover on the game tile, keeping the colored placeholder as the fallback
- [ ] Gate: the whole library shows real titles and covers

### v0.2.0 — CHD support

- [ ] Add libchdr (BSD) as a C target in the package — a licence review onto ADR 0008's allow-list first
- [ ] Read the first hunks of a `.chd` and pass them to the ISO 9660 reader
- [ ] Gate: `.chd` games are classified by SYSTEM.CNF, not size or folder name

### v0.3.0 — Per-game settings

- [ ] A per-game settings sheet (fullscreen, config file)
- [ ] Pass PCSX2 `-gamecfg` and RPCS3 `--config` when set
- [ ] Gate: one game launches with its own settings without touching the emulator's UI

### v0.4.0 — Controllers and couch mode

- [ ] Read controllers with `GameController.framework`
- [ ] Write one shared mapping into each emulator's input config
- [ ] A fullscreen, controller-driven library view (the expected first promotion of the game tile into `styles`)
- [ ] Gate: pick and launch a game from the sofa without touching the keyboard

### v1.0.0 — Release: the launcher

- [ ] Move from the Swift package to an Xcode project with an app icon — a decision needed, below
- [ ] License iStation under GPLv3 and publish the repository
- [ ] Swap DuckStation for PCSX-Redux as the recommended PS1 emulator, and check PCSX-Redux's command-line flags
- [ ] Remove Sony logos and run a trademark check on "iStation"
- [ ] Join the Apple Developer Program and create a Developer ID Application certificate (the user's)
- [ ] Sign with hardened runtime, notarize with `notarytool`, staple, and package a notarized `.dmg`
- [ ] Add Sparkle updates with a signed appcast — a licence review onto ADR 0008's allow-list first
- [ ] Gate: the `.dmg` installs and runs on a clean Mac with no warnings

### v2.0.0 — Release: bundled emulators

- [ ] Add PCSX-Redux, PCSX2 and RPCS3 as pinned git submodules and build them in the release script
- [ ] Copy them into `Contents/Helpers` and their licence texts into `Resources/Licenses`
- [ ] Make emulator discovery prefer the bundled helpers
- [ ] A first-run screen for user-supplied BIOS files and PS3 system software
- [ ] Confirm each emulator's entitlements and sign every executable inside-out
- [ ] An Acknowledgements screen with licences and source links
- [ ] Gate: a notarized bundle plays one game from each console with no separate installs

## Architecture

Nothing queued.

## Maintenance

- [ ] **An unreadable library file is silently replaced** — keep it aside and say so ([M1](../backlog/maintenance/unreadable-library-file.md))
- [ ] **The emulator chooser opens in /Applications again** — lost in the move to `.fileImporter` ([M2](../backlog/maintenance/app-chooser-start-folder.md))

## Decisions needed

The user's open questions from the Build Roadmap (2026-10-26), each `[user]`:

- **Which metadata source for covers and titles?** It must be keyed by serial and allow personal use. Blocks v0.1.0's first item.
- **Stay a Swift package, or move to an Xcode project** once an app icon, signing and notarization are wanted? Blocks v1.0.0's first item. (The layered package survives either way: an Xcode app target can depend on it. Since 2026-10-31 a thin `iStation.xcodeproj` at the root opens the package in Xcode; it has no targets of its own, so this question stands.)
- **Should iStation also read RPCS3's own `games.yml`** list of disc games, so those folders needn't be added twice? Unscheduled.
- **How should a game's play history follow it when its file is moved or renamed?** Today a game's ID is its console plus its path, so a move starts its history over. Unscheduled; any answer changes the library file's format ([ADR 0007](../adrs/backwards-compatibility.md)).

## Ideas

- Pick a Swift formatter/linter (`swift format` ships with the toolchain) and add it to the checklist and CI.
- Intel Macs: build and test universal, or state Apple Silicon only.

## Non-goals

See [SPEC.md → Non-goals](SPEC.md#non-goals).
