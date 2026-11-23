# iStation — Roadmap

How we work: features are discussed in chat, written up here (and in [SPEC.md](SPEC.md)), given their own document in [`backlog/`](../../backlog/darwin/README.md) when specced, built straight from that document, and recorded in [MILESTONES.md](MILESTONES.md).

**Version scheme:** one version per phase (the user's call, 2026-10-31), re-planned 2026-11-07 with the App Store brief — v0.0.1 JIT verified, both build routines, the R3000A boots the BIOS; v0.1.0 the first picture; v0.2.0 PS1 games boot; v0.3.0 Metal, audio and input; v0.4.0 the iOS app; v1.0.0 the PS1 release on the App Stores; v2.x PS2; patches `v0.x.y` between. Each release is built on its own branch and merged into `stable`, tagged, when its backlog table empties. No dates: this is a personal project.

**Re-planned 2026-11-07.** The user re-envisioned iStation twice that day: first as Swift ports of GPL emulators (track 2, cancelled), then — the plan that stands — as two App Store-eligible apps ported from permissively licensed references, with GPL emulators as black-box oracles ([SPEC.md](SPEC.md), [ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md), [Milestone D](MILESTONES.md#milestone-d--the-app-store-re-vision)). The library app and its launcher are retired (the user's call), and with them the launcher roadmap, the first-boot gate (1a), A1 and the Maintenance items M1 and M2.

---

## In progress

### v0.1.0 — The first picture

- [ ] The GPU and its software rasterizer, ported from ProjectPSX (its document is [6b](../../backlog/darwin/v0.1.0/interface-picture.md)'s split)
- [ ] DMA and timers in full
- [ ] The narrow core interface ([ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §5) and EmuKit's Metal presentation of frames: booting a PS-EXE, the BIOS's shell and personal-build debug values (6a, shipped: [Milestone T](MILESTONES.md#milestone-t--the-narrow-interface-boot-the-shell-and-debug-values)), the picture and VRAM ([6b](../../backlog/darwin/v0.1.0/interface-picture.md))
- [ ] Per-frame VRAM recorded from SwanStation and compared (its own document, one of [6b](../../backlog/darwin/v0.1.0/interface-picture.md)'s split)
- [ ] The boot's guest RAM matching SwanStation's frame by frame, moved from v0.0.1's gate (the user's call, 2026-11-14): the shell waits on the GPU's VRAM transfers, and the boot's pace needs closer timing — the instruction cache, timer reads within a slice ([Milestone L](MILESTONES.md#milestone-l--the-bios-boots))
- [ ] The app's design, its Today parts ([`design/darwin/`](../../design/darwin/README.md), 2026-11-21; BIOS and game import moved here from v0.2.0, the user's call, 2026-11-21): the design's tokens in `styles` (5a, shipped: [Milestone S](MILESTONES.md#milestone-s--the-designs-tokens-in-styles)), the console session and the player (5b, shipped: [Milestone U](MILESTONES.md#milestone-u--the-console-session-and-the-player)), first run and the BIOS (5c, shipped: [Milestone V](MILESTONES.md#milestone-v--first-run-and-the-bios)), the library of files with PS-EXEs that play ([5d](../../backlog/darwin/v0.1.0/library-of-files.md)), Settings and the other windows ([5e](../../backlog/darwin/v0.1.0/windows-settings-and-shortcuts.md)), the personal build's Tools ([5f](../../backlog/darwin/v0.1.0/personal-tools.md)), the picture on screen ([5g](../../backlog/darwin/v0.1.0/the-picture-on-screen.md))
- [ ] Gate: the BIOS's shell and a homebrew PS-EXE draw in the macOS app, VRAM matching SwanStation's frame by frame

## Shipped

### v0.0.1 — JIT verified, both build routines, the R3000A boots the BIOS

The brief's first three tasks: prove JIT works under the App Store routine, lay down the packages and both apps with both build routines, then the PS1 milestone — the R3000A interpreter, the memory map and the BIOS boot, reaching the shell, passing ps1-tests' CPU tests up to known gaps and agreeing with ProjectPSX instruction by instruction. The boot's guest RAM matching SwanStation's frame by frame moved to v0.1.0 (the user's call, 2026-11-14).

- [x] **The scaffold compiles** and **the tests are green** ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [x] **Provenance headers and notices** — SPDX headers, provenance lines, the acknowledgements list and the root licence, with a check ([Milestone H](MILESTONES.md#milestone-h--provenance-headers-and-notices))
- [x] **JIT under the App Store routine** — a sandboxed `allow-jit` macOS app that maps one `MAP_JIT` region and runs code it wrote ([Milestone E](MILESTONES.md#milestone-e--jit-under-the-app-store-routine))
- [x] **The skeleton and both build routines** — the packages, the macOS and iOS apps, App Store and personal routines; the library app removed ([Milestone F](MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines))
- [x] **TraceKit** — the trace format and the first divergence between two traces ([Milestone G](MILESTONES.md#milestone-g--tracekit))
- [x] **The reference and the oracle** — ProjectPSX with trace logging; SwanStation unmodified, recorded from outside ([Milestone K](MILESTONES.md#milestone-k--the-reference-and-the-oracle))
- [x] **The R3000A interpreter** — ported from ProjectPSX, generic over its bus ([Milestone I](MILESTONES.md#milestone-i--the-r3000a-interpreter))
- [x] **The PS1 console** — memory map, interrupt controller, timers, DMA and the devices the BIOS needs ([Milestone J](MILESTONES.md#milestone-j--the-ps1-console))
- [x] **Gate: the BIOS boots** — the BIOS reaches its shell on the user's 23 BIOS images, ps1-tests' CPU tests pass up to known gaps, and ProjectPSX agrees instruction by instruction ([Milestone L](MILESTONES.md#milestone-l--the-bios-boots))

Then the repository takes the layout and procedure of the user's Apogee repository, adapted for iStation (the user's call, 2026-11-14):

- [x] **Documentation by kind, then platform** — `lib/documentation/{assistant,backlog,adrs,reference}/darwin/`, the router and the validator ([Milestone M](MILESTONES.md#milestone-m--documentation-by-kind-then-platform))
- [x] **The code under `lib/src/darwin/`** — the package, the apps, the Xcode project, the scripts and the tools ([Milestone N](MILESTONES.md#milestone-n--the-code-under-libsrcdarwin))
- [x] **The release in `lib/release/VERSION`** — one file names the release, the apps follow it, a check guards it ([Milestone O](MILESTONES.md#milestone-o--the-release-in-libreleaseversion))
- [x] **One build path and a pipeline per app** — `cicd.sh`, `changed.sh`, `pr-ci.sh` and `darwin.yml` ([Milestone P](MILESTONES.md#milestone-p--one-build-path-and-a-pipeline-per-app))
- [x] **Superpowers inside the lifecycle, and application-aware skills** — `.claude/settings.json`, the mapping in CLAUDE.md, the "Which application?" ladder ([Milestone Q](MILESTONES.md#milestone-q--superpowers-inside-the-lifecycle-and-application-aware-skills))
- [x] **Development runs on the personal channel** — personal builds get their own identity, "iStation Personal" ([Milestone R](MILESTONES.md#milestone-r--development-on-the-personal-channel))

## Planned

### v0.2.0 — PS1 games boot

- [ ] The CD-ROM drive and disc images, its timing fixed against psx-spx, test suites and SwanStation's recorded behaviour (ProjectPSX's known weak spot): its document is [6d](../../backlog/darwin/v0.2.0/interface-discs.md)'s split; playing discs ([5i](../../backlog/darwin/v0.2.0/playing-discs.md))
- [ ] The GTE, SPU and MDEC (MDEC timing fixed the same way); the SPU's document is [6i](../../backlog/darwin/v0.3.0/interface-sound.md)'s split
- [ ] Pads and memory cards, through the GameController framework: pads on both ports, Bluetooth or USB ([6e](../../backlog/darwin/v0.2.0/interface-pads.md)), Controllers ([5j](../../backlog/darwin/v0.2.0/controllers-settings.md)), memory cards ([6f](../../backlog/darwin/v0.2.0/interface-memory-cards.md), [5k](../../backlog/darwin/v0.2.0/memory-cards-pane.md))
- [ ] Discs read in the library: the readers in a product ([6c](../../backlog/darwin/v0.2.0/interface-disc-readers.md)), console, serial and PS2 refused ([5h](../../backlog/darwin/v0.2.0/library-reads-discs.md)). BIOS and game import through the file picker moved to v0.1.0 (5c, 5d; the user's call, 2026-11-21)
- [ ] Save states, versioned ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5): [6g](../../backlog/darwin/v0.2.0/interface-save-states.md), [5l](../../backlog/darwin/v0.2.0/save-states-sheet.md)
- [ ] The video standard, PAL or NTSC, paced and shown ([6h](../../backlog/darwin/v0.2.0/interface-video-standard.md))
- [ ] Gate: a PS1 game the user owns boots and plays in the macOS app (the user's run)

### v0.3.0 — Metal, audio and input

- [ ] A Metal renderer, checked against the software rasterizer; choosing it ([6j](../../backlog/darwin/v0.3.0/interface-renderer-choice.md))
- [ ] Audio through Core Audio / AVAudioEngine ([6i](../../backlog/darwin/v0.3.0/interface-sound.md)), Settings › Audio ([5m](../../backlog/darwin/v0.3.0/audio-settings.md))
- [ ] The DualShock, from the controller spike of 2026-11-22 (a DualSense over Bluetooth worked under the App Store sandbox with no new entitlement): the analog pad ([7a](../../backlog/darwin/v0.3.0/dualshock-analog-pad.md)), rumble ([7b](../../backlog/darwin/v0.3.0/dualshock-rumble.md)), and per-port settings with player 2 ([7c](../../backlog/darwin/v0.3.0/controllers-pad-type-rumble-and-player-two.md))
- [ ] Gate: PS1 games run at full speed on Apple Silicon with Metal, sound and a controller

### v0.4.0 — The iOS app

- [ ] The iOS app target playing PS1, interpreter only: first run, library and settings ([5n](../../backlog/darwin/ios/v0.4.0/iphone-library-and-settings.md)), the player ([5o](../../backlog/darwin/ios/v0.4.0/iphone-player.md))
- [ ] Gate: a PS1 game plays on an iPhone or iPad

### v1.0.0 — Release: PS1 on the App Stores

- [ ] The acknowledgements screen in both apps, from the acknowledgements list (`lib/src/darwin/apps/Acknowledgements.json`, Milestone H)
- [ ] Check App Review Guidelines section 4.7 for iOS and for the Mac App Store
- [ ] Remove Sony logos and run a trademark check on "iStation"
- [ ] App Store Connect, signing and submission (the user's)
- [ ] Gate: both apps pass App Review

### v2.x — PS2

- [ ] A spike first: Play! built natively for arm64 with debug symbols and mapped with Revula; Play-Dependencies audited (unrarsrc and Windows-only libraries out); PCSX2 built unmodified as the oracle; 3a's JIT result applied
- [ ] The EE (R5900 with its 128-bit MMI instructions and FPU) and IOP (the Swift R3000A) interpreters, through Play!'s HLE BIOS
- [ ] Gate: a homebrew ELF runs through the HLE BIOS, its output and post-boot guest trace matching PCSX2
- [ ] Later: the VUs and the GS (their own trace formats), then a code generator modelled on Play--CodeGen's AArch64 backend — macOS only, one `MAP_JIT` region

## Architecture

- [x] **Provenance headers and notices** — gates the first ported module ([Milestone H](MILESTONES.md#milestone-h--provenance-headers-and-notices))

## Maintenance

Nothing queued: M1 and M2 were the library app's, and retired with it.

## Decisions needed

Each `[user]`:

- **If JIT fails under the App Sandbox (3a), how does the PS2 reach the Mac App Store** — interpreter only, or outside the store? Blocks v2.x. (2026-11-07) *Not raised yet: 3a's run (1) passed on macOS 27.0.1, ad-hoc signed ([Milestone E](MILESTONES.md#milestone-e--jit-under-the-app-store-routine)); it stays open until your runs (2) and (3) in `lib/src/darwin/tools/jit-probe/README.md`.*
- **A PS1 high-level-emulated BIOS**, written from documentation (never from OpenBIOS), so App Store users need no BIOS dump? Unscheduled. (2026-11-07)

## Ideas

- Pick a Swift formatter/linter (`swift format` ships with the toolchain) and add it to the checklist and CI.

## Non-goals

See [SPEC.md → Non-goals](SPEC.md#non-goals).
