# iStation — Roadmap

How we work: features are discussed in chat, written up here (and in [SPEC.md](SPEC.md)), given their own document in [`backlog/`](../backlog/README.md) when specced, built straight from that document, and recorded in [MILESTONES.md](MILESTONES.md).

**Version scheme:** one version per phase (the user's call, 2026-10-31), re-planned with the re-vision on 2026-11-07 (the user's call) — v0.0.1 the R3000A boots OpenBIOS, v0.1.0 the first picture, v0.2.0 PS1 games boot, v0.3.0 Metal, audio and input, v0.4.0 iOS (PS1), v1.0.0 the PS1 release, v2.x PS2; patches `v0.x.y` between. Each release is built on its own branch and merged into `stable`, tagged, when its backlog table empties. No dates: this is a personal project.

**Re-planned 2026-11-07.** iStation was re-envisioned from a launcher into native Swift emulators ported from SwanStation (PS1) and PCSX2 (PS2) ([SPEC.md](SPEC.md), [ADR 0010](../adrs/cores-are-ports-of-open-references.md), [Milestone C](MILESTONES.md#milestone-c--the-re-vision)). Where the launcher roadmap's lines went: cover art and titles, per-game settings and couch mode → Ideas (frontend, unscheduled); CHD support → v0.2.0; the launcher release's signing and notarization → v1.0.0; bundled emulators and the PCSX-Redux swap → replaced by the native cores. The v0.0.1 gate that booted one game per console through the installed emulators (item 1a) was retired the same day (the user's call); its first run is recorded in Milestone C.

---

## In progress

### v0.0.1 — The R3000A boots OpenBIOS

The PS1 core's first milestone (the user's brief, 2026-11-07): an R3000A interpreter, the memory map and the BIOS boot path, checked instruction by instruction against SwanStation. Re-scoped from "first build" on 2026-11-07 (the user's call); construction's two lines stay done.

- [x] **The scaffold compiles** — open the package and fix the compile errors ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [x] **The tests are green** — `swift test` ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [ ] **Each module carries its licence** — licence tags on every module, a check on the boundary, SPDX headers, the licence files ([A1](../backlog/architecture/each-module-carries-its-licence.md))
- [ ] **The trace format** — one record per guest instruction, and finding the first divergence between two traces ([2a](../backlog/v0.0.1/trace-format.md))
- [ ] **The reference trace** — SwanStation built from a pinned commit, writing that format for every instruction of an OpenBIOS boot ([2b](../backlog/v0.0.1/reference-trace.md))
- [ ] **The R3000A interpreter** — ported from SwanStation, generic over its bus ([2c](../backlog/v0.0.1/r3000a-interpreter.md))
- [ ] **The PS1 console** — memory map, interrupt controller, timing events, minimal DMA and timers, device stubs ([2d](../backlog/v0.0.1/ps1-console.md))
- [ ] **Gate: OpenBIOS boots** — booting OpenBIOS and PS-EXEs, TTY output, the open fixtures; the trace identical to SwanStation's, ps1-tests' `cop` and `code-in-io` passing ([2e](../backlog/v0.0.1/openbios-boots.md))

## Planned

### v0.1.0 — The first picture

- [ ] The GPU's command processing and software renderer, ported from SwanStation
- [ ] DMA and timers in full; ps1-tests' `access-time` and `io-access-bitwidth` (moved from v0.0.1, 2026-11-07, the user's call)
- [ ] The frontend-to-core interface ([ADR 0012](../adrs/cores-shape-and-hot-paths.md) §5) and the game view showing frames
- [ ] Per-frame VRAM traces against SwanStation
- [ ] Gate: OpenBIOS's shell and a homebrew PS-EXE draw in iStation's game view, VRAM identical to SwanStation's frame by frame

### v0.2.0 — PS1 games boot

- [ ] The CD-ROM drive and disc images (`.cue`/`.bin`, `.iso`, `.m3u`; `.chd` through libchdr — a licence review onto ADR 0010's allow-list first)
- [ ] The GTE, SPU and MDEC
- [ ] Pads and memory cards
- [ ] The user's own BIOS file chosen in Settings
- [ ] Double-click plays a PS1 game in the native core; DuckStation is no longer needed
- [ ] Gate: a PS1 game the user owns boots and plays in iStation (the user's run)

### v0.3.0 — Metal, audio and input

- [ ] A Metal renderer, checked against the software renderer
- [ ] Audio through Core Audio / AVAudioEngine
- [ ] Controllers through the GameController framework
- [ ] Gate: PS1 games run at full speed on Apple Silicon with Metal, sound and a controller

### v0.4.0 — iOS (PS1)

- [ ] The frontend and the PS1 core on iOS, interpreter only
- [ ] A distribution channel outside the App Store — a decision needed, below
- [ ] Gate: a PS1 game plays on an iPhone or iPad

### v1.0.0 — Release: PS1

- [ ] The repository published, with the licence files and per-file headers (from A1)
- [ ] An Acknowledgements screen crediting SwanStation and its authors, with licences and source links
- [ ] Remove Sony logos and run a trademark check on "iStation"
- [ ] An Xcode app target with an app icon — a decision needed, below
- [ ] Join the Apple Developer Program and create a Developer ID Application certificate (the user's)
- [ ] Sign with hardened runtime, notarize with `notarytool`, staple, and package a notarized `.dmg`
- [ ] Sparkle updates with a signed appcast — a licence review onto ADR 0010's allow-list first
- [ ] Gate: the `.dmg` installs and plays PS1 games on a clean Mac with no warnings

### v2.x — PS2

- [ ] A spike first: the licence of every PCSX2 third-party folder, which parts run interpreted on arm64, and an arm64 debug build to trace
- [ ] The EE (R5900 with its 128-bit MMI instructions and FPU) and the IOP (the Swift R3000A) interpreters
- [ ] Gate: the EE and IOP boot the user's BIOS to its first screen, with traces matching PCSX2
- [ ] Later: the VUs and the GS (their own trace formats), then recompilers — macOS only, AArch64, `allow-jit`

## Architecture

- [ ] **Each module carries its licence** — licence tags, the boundary check, SPDX headers and licence files; gates the first ported module ([A1](../backlog/architecture/each-module-carries-its-licence.md))

## Maintenance

- [ ] **An unreadable library file is silently replaced** — keep it aside and say so ([M1](../backlog/maintenance/unreadable-library-file.md))
- [ ] **The emulator chooser opens in /Applications again** — lost in the move to `.fileImporter` ([M2](../backlog/maintenance/app-chooser-start-folder.md))

## Decisions needed

Each `[user]`:

- **Should the app ship OpenBIOS as a fallback** for someone without their own BIOS dump, as SwanStation does? Blocks v0.2.0's Settings line. (2026-11-07)
- **Which channel for iOS**, outside the App Store? Blocks v0.4.0. (2026-11-07)
- **Stay a Swift package, or add an Xcode app target** once an app icon, signing and notarization are wanted? Blocks v1.0.0's app-target line. (The layered package survives either way: an Xcode app target can depend on it. Since 2026-10-31 a thin `iStation.xcodeproj` at the root opens the package in Xcode; it has no targets of its own, so this question stands.)
- **Which metadata source for covers and titles?** It must be keyed by serial and allow personal use. Unscheduled (Ideas).
- **Should iStation also read RPCS3's own `games.yml`** list of disc games, so those folders needn't be added twice? Unscheduled.
- **How should a game's play history follow it when its file is moved or renamed?** Today a game's ID is its console plus its path, so a move starts its history over. Unscheduled; any answer changes the library file's format ([ADR 0007](../adrs/backwards-compatibility.md)).

## Ideas

- **Cover art and titles** (from the launcher roadmap's v0.1.0): a metadata source keyed by serial, images cached under `~/Library/Application Support/iStation/covers`, the cover on the game tile with the colored placeholder as the fallback.
- **Per-game settings** (from its v0.3.0), now for the native cores' own settings as well as installed emulators' flags.
- **Couch mode** (from its v0.4.0): a fullscreen, controller-driven library view — the expected first promotion of the game tile into `styles`.
- **Launcher fixes found on 1a's first run, not queued** ([Milestone C](MILESTONES.md#milestone-c--the-re-vision)): an installed emulator that fails to start (or stops at its own BIOS prompt) still counts as play time; 4 raw Mode 2 PS1 discs are read without a serial because their SYSTEM.CNF entry points outside the data track.
- Pick a Swift formatter/linter (`swift format` ships with the toolchain) and add it to the checklist and CI.
- Intel Macs: build and test universal, or state Apple Silicon only.

## Non-goals

See [SPEC.md → Non-goals](SPEC.md#non-goals).
