# iStation — Roadmap

How we work: features are discussed in chat, written up here (and in [SPEC.md](SPEC.md)), given their own document in [`backlog/`](../backlog/README.md) when specced, built straight from that document, and recorded in [MILESTONES.md](MILESTONES.md).

**Version scheme:** one version per phase (the user's call, 2026-10-31), re-planned 2026-11-07 with the App Store brief — v0.0.1 JIT verified, both build routines, the R3000A boots the BIOS; v0.1.0 the first picture; v0.2.0 PS1 games boot; v0.3.0 Metal, audio and input; v0.4.0 the iOS app; v1.0.0 the PS1 release on the App Stores; v2.x PS2; patches `v0.x.y` between. Each release is built on its own branch and merged into `stable`, tagged, when its backlog table empties. No dates: this is a personal project.

**Re-planned 2026-11-07.** The user re-envisioned iStation twice that day: first as Swift ports of GPL emulators (track 2, cancelled), then — the plan that stands — as two App Store-eligible apps ported from permissively licensed references, with GPL emulators as black-box oracles ([SPEC.md](SPEC.md), [ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md), [Milestone D](MILESTONES.md#milestone-d--the-app-store-re-vision)). The library app and its launcher are retired (the user's call), and with them the launcher roadmap, the first-boot gate (1a), A1 and the Maintenance items M1 and M2.

---

## In progress

### v0.0.1 — JIT verified, both build routines, the R3000A boots the BIOS

The brief's first three tasks: prove JIT works under the App Store routine, lay down the packages and both apps with both build routines, then the PS1 milestone — the R3000A interpreter, the memory map and the BIOS boot, passing ps1-tests' CPU tests with a guest-state trace that matches SwanStation's.

- [x] **The scaffold compiles** and **the tests are green** ([Milestone A](MILESTONES.md#milestone-a--the-construction))
- [x] **Provenance headers and notices** — SPDX headers, provenance lines, the acknowledgements list and the root licence, with a check ([Milestone H](MILESTONES.md#milestone-h--provenance-headers-and-notices))
- [x] **JIT under the App Store routine** — a sandboxed `allow-jit` macOS app that maps one `MAP_JIT` region and runs code it wrote ([Milestone E](MILESTONES.md#milestone-e--jit-under-the-app-store-routine))
- [x] **The skeleton and both build routines** — the packages, the macOS and iOS apps, App Store and personal routines; the library app removed ([Milestone F](MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines))
- [x] **TraceKit** — the trace format and the first divergence between two traces ([Milestone G](MILESTONES.md#milestone-g--tracekit))
- [ ] **The reference and the oracle** — ProjectPSX with trace logging; SwanStation unmodified, recorded from outside ([3d](../backlog/v0.0.1/reference-and-oracle-traces.md))
- [ ] **The R3000A interpreter** — ported from ProjectPSX, generic over its bus ([3e](../backlog/v0.0.1/r3000a-interpreter.md))
- [ ] **The PS1 console** — memory map, interrupt controller, timers, DMA and the devices the BIOS needs ([3f](../backlog/v0.0.1/ps1-console.md))
- [ ] **Gate: the BIOS boots** — ps1-tests' CPU tests pass and the guest-state trace matches SwanStation's (the user's run, with their BIOS) ([3g](../backlog/v0.0.1/bios-boots.md))

## Planned

### v0.1.0 — The first picture

- [ ] The GPU and its software rasterizer, ported from ProjectPSX
- [ ] DMA and timers in full
- [ ] The narrow core interface ([ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md) §5) and EmuKit's Metal presentation of frames
- [ ] Per-frame VRAM recorded from SwanStation and compared
- [ ] Gate: the BIOS's shell and a homebrew PS-EXE draw in the macOS app, VRAM matching SwanStation's frame by frame

### v0.2.0 — PS1 games boot

- [ ] The CD-ROM drive and disc images, its timing fixed against psx-spx, test suites and SwanStation's recorded behaviour (ProjectPSX's known weak spot)
- [ ] The GTE, SPU and MDEC (MDEC timing fixed the same way)
- [ ] Pads and memory cards, through the GameController framework
- [ ] BIOS and game import through the file picker, access kept across launches under the App Sandbox
- [ ] Save states, versioned ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md) §5)
- [ ] Gate: a PS1 game the user owns boots and plays in the macOS app (the user's run)

### v0.3.0 — Metal, audio and input

- [ ] A Metal renderer, checked against the software rasterizer
- [ ] Audio through Core Audio / AVAudioEngine
- [ ] Gate: PS1 games run at full speed on Apple Silicon with Metal, sound and a controller

### v0.4.0 — The iOS app

- [ ] The iOS app target playing PS1, interpreter only
- [ ] Gate: a PS1 game plays on an iPhone or iPad

### v1.0.0 — Release: PS1 on the App Stores

- [ ] The acknowledgements screen in both apps, from the acknowledgements list (`src/istation/apps/Acknowledgements.json`, Milestone H)
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

- **If JIT fails under the App Sandbox (3a), how does the PS2 reach the Mac App Store** — interpreter only, or outside the store? Blocks v2.x. (2026-11-07) *Not raised yet: 3a's run (1) passed on macOS 27.0.1, ad-hoc signed ([Milestone E](MILESTONES.md#milestone-e--jit-under-the-app-store-routine)); it stays open until your runs (2) and (3) in `tools/jit-probe/README.md`.*
- **A PS1 high-level-emulated BIOS**, written from documentation (never from OpenBIOS), so App Store users need no BIOS dump? Unscheduled. (2026-11-07)

## Ideas

- Pick a Swift formatter/linter (`swift format` ships with the toolchain) and add it to the checklist and CI.

## Non-goals

See [SPEC.md → Non-goals](SPEC.md#non-goals).
