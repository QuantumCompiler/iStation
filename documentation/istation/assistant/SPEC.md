# iStation — Spec

The product spec: what iStation is, what it is for, and the principles that shape it. The plan is in [ROADMAP.md](ROADMAP.md); the work queue is [`backlog/`](../backlog/README.md); shipped work is in [MILESTONES.md](MILESTONES.md).

*Source: the user's design documents of 2026-10-26 (a launcher for DuckStation, PCSX2 and RPCS3), carried into this home at construction, 2026-10-31. **Re-envisioned 2026-11-07 (the user's call)** by the brief "PS1 and PS2 emulators in Swift (App Store-eligible)", which replaces the same day's earlier plan to port GPL emulators. Today's library app is retired (the user's call). The evidence and decisions are in [Milestone D](MILESTONES.md#milestone-d--the-app-store-re-vision).*

---

## One-liner

**iStation** is two native Apple apps with PlayStation emulators written in Swift — macOS (PS1 and PS2) and iOS (PS1) — ported from permissively licensed references and eligible for Apple's App Stores.

## Background

Playing PS1 and PS2 games on Apple devices means installing emulators whose licences keep them out of the App Stores. iStation began (2026-10-26) as a library and launcher in front of the user's installed DuckStation, PCSX2 and RPCS3. On 2026-11-07 the user re-envisioned it twice: first as Swift ports of GPL emulators, then — the plan that stands — as Swift ports of **permissively licensed** emulators, so the apps can ship on the App Stores. The more accurate GPL emulators are used only from the outside, as black-box oracles whose guest-visible behaviour is recorded and compared.

Foundational choices (the user's brief, 2026-11-07, unless marked):

1. **Swift ports of permissive references.** Shipped code derives only from permissively licensed sources: PS1 from [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (MIT, C#), PS2 from [Play!](https://github.com/jpd002/Play-) (BSD, C++) and its own libraries. Putting GPL code on the App Store is legally contested, and the project doesn't own the copyright needed to grant an exception ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md)).
2. **GPL emulators are black-box oracles.** SwanStation (PS1) and PCSX2 (PS2) are run unmodified and their guest-visible behaviour — guest CPU registers, guest memory, VRAM, audio — is recorded and compared. Their source is never opened, read or copied.
3. **App Store-eligible, with two build routines per app**: an App Store release build (sandboxed, no debug tooling) and a personal build with debugging and tracing tools that is never distributed ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md)).
4. **iStation's own code is MIT** (the user's call); the code derived from ProjectPSX and Play! keeps their MIT and BSD notices, in the source and in each app's acknowledgements screen ([ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)).
5. **Apple Silicon and iOS.** The macOS app plays PS1 and PS2 on Apple Silicon; the iOS app plays PS1. Code generators emit AArch64 only; Intel Macs aren't supported.
6. **Interpreter first, accuracy first.** Each CPU gets an interpreter before any code generator, and each GPU its software rasterizer before a Metal renderer.
7. **The PS2's I/O processor is the PS1's CPU**, so the Swift R3000A serves both ([ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md)).

And at construction (2026-10-31), still standing: the four-layer architecture with mechanical checks; one version per roadmap phase.

## Surfaces

1. **The macOS app** — PS1 and PS2: choose a game and play it, with save states.
2. **The iOS app** — PS1 only, interpreter only.
3. **File import** — the user's own BIOS dump and games, through the system file picker; the sandboxed app keeps access to what was chosen.
4. **The acknowledgements screen** — ProjectPSX's MIT notice, Play!'s BSD notices and every other licence the app carries.
5. **The personal build's tools** — CPU and VRAM viewers and trace recording (TraceKit); compiled out of every App Store build.

## Scope

### Goals

- PS1 on macOS and iOS, ported from ProjectPSX, then corrected where ProjectPSX is known to be weak (CD-ROM, DMA and MDEC timing) against public documentation, test suites and SwanStation's recorded behaviour.
- PS2 on macOS, ported from Play!, keeping its high-level-emulated BIOS so App Store users need no PS2 BIOS dump, and reusing the Swift R3000A for the IOP.
- Both apps eligible for the App Stores, and both with a personal build for the user's own debugging.

### Consoles and references

| Console | Port of | Its licence | Black-box oracle | Platforms |
|---|---|---|---|---|
| PS1 | [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) — C#, no external dependencies, interpreter, software GPU rasterizer; needs a real BIOS; its README lists CD-ROM timing and resumable DMA as missing | MIT | SwanStation | macOS, iOS |
| PS2 | [Play!](https://github.com/jpd002/Play-) — C++, built-in high-level-emulated BIOS, a code generator (Play--CodeGen) with an AArch64 backend, already builds for macOS; with Play--Framework and Nuanceur | BSD (two-clause wording) | PCSX2 | macOS |
| PS3 | — | — | — | out of scope |

### Porting

- **Order:** the CPU interpreter, the memory map and the BIOS boot first; then the devices a picture needs; the software rasterizer before Metal; the interpreter before any code generator.
- **Two kinds of trace.** The permissive reference may be changed: ProjectPSX gains trace logging in its own source (MIT allows it) for instruction-by-instruction comparison. The GPL oracle may only be run: SwanStation and PCSX2 run unmodified, preferring their built-in debugger, trace and logging features, else recorded from outside (LLDB, Frida via Revula) — guest state only. TraceKit diffs the Swift port's trace against either and reports the first divergence.
- **Revula** maps, profiles and traces the permissive references freely (Play!'s symbols, hot paths and AArch64 code-generator output), and only records guest state from the GPL oracles — never disassembling or decompiling them.
- **Documentation** that is public, such as psx-spx (PS1) and ps2tek (PS2), may be read freely.
- **Hot paths** use concrete types, never protocol-typed values, ARC traffic or redundant bounds checks ([ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md)).

### Test content

- **Hermetic tests** (`swift test`, CI) use only content built in code or committed beside an open licence.
- **Personal builds** also run the user's own BIOS dump, homebrew, and open suites such as [ps1-tests](https://github.com/JaCzekanski/ps1-tests) (MIT) and [ps2autotests](https://github.com/unknownbrackets/ps2autotests) (ISC). A run with the user's BIOS is the user's to start.

### Build routines

*(2026-11-07, the user's brief; [ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md).)*

| | App Store release | Personal / developer |
|---|---|---|
| Signing | App Store distribution | development, `get-task-allow` (LLDB and Frida can attach) |
| Sandbox | App Sandbox on, user-selected file access | as needed for the tools |
| JIT (macOS) | `com.apple.security.cs.allow-jit`; never `allow-unsigned-executable-memory` | on |
| Tools | TraceKit and debug UI compiled out | TraceKit, CPU and VRAM viewers, trace recording |
| Distributed | to the App Stores | never |

One Swift compilation condition (`PERSONAL_BUILD`), separate xcconfig and entitlements files per routine, and one scheme or script per routine (`xcodebuild archive` with export options).

### Apple constraints

- iOS App Store apps can't generate code at run time; the PS1 runs well interpreted, the PS2 doesn't — so PS2 is macOS-only.
- JIT on macOS: the `allow-jit` entitlement, `MAP_JIT` memory and `pthread_jit_write_protect_np` toggling on Apple Silicon. Under the hardened runtime an app may create only one `MAP_JIT` region, so each code cache is one region. Developers report `allow-jit` accepted on the Mac App Store, and one report says JIT failed under the App Sandbox on macOS 26 — verified first (v0.0.1, item 3a); if it fails, PS2 on the Mac App Store is rethought before PS2 work starts. *Measured 2026-11-07 (3a, [Milestone E](MILESTONES.md#milestone-e--jit-under-the-app-store-routine)): on macOS 27.0.1 an ad-hoc-signed, sandboxed, hardened-runtime app with `allow-jit` maps a `MAP_JIT` region and runs its code; a second region was granted too, so the one-region rule is unconfirmed until signed runs.*
- Audio through Core Audio / AVAudioEngine; input through the GameController framework; presentation through Metal.

## Distribution

On the Mac App Store and the iOS App Store, eligible under App Review Guidelines section 4.7 (retro game console emulators, added April 2024) — checked before each submission; reports about it cover iPhone and iPad, and the Mac App Store's specifics aren't confirmed.

- **Licensing.** iStation's own code is MIT. Code ported from ProjectPSX keeps its MIT notice; code from Play! and its libraries keeps their BSD notices; every app shows them in its acknowledgements screen ([ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)). Every third-party dependency is audited before it is ported or linked: from Play-Dependencies, unrarsrc (a non-standard UnRAR licence) and the Windows-only libraries stay out; AltKit (an iOS JIT helper with no licence file) isn't needed; Apple frameworks and Swift packages are preferred.
- **BIOS and games.** Never bundled, mirrored or downloaded: users import their own through a file picker. A PS1 high-level-emulated BIOS written from documentation is a possible later feature, so App Store users wouldn't need a dump; it must not be based on OpenBIOS. The PS2 uses Play!'s high-level-emulated BIOS.
- **Branding.** No Sony logos or artwork; describe compatibility only ("plays PS2 games"). Run a trademark check on "iStation" before a public launch.

## Non-goals

*(Revised 2026-11-07, the user's brief.)*

- **Reading, opening or copying the source of any GPL emulator** — SwanStation, PCSX2, DuckStation, PCSX-Redux (including its OpenBIOS), Beetle PSX/Mednafen, PCSX-ReARMed, Avocado, RPCS3 — or transcribing their disassembled or decompiled code. Running them and recording guest-visible behaviour is fine.
- **Bundling, mirroring or downloading Sony BIOS files or game images.**
- **A PS3 core, for now.** Its open references are GPL, so it couldn't ship on the App Stores unless written from documentation alone; the narrow core interface keeps the door open.
- **The PS2 on iOS**, which needs a code generator.
- **Intel Macs.**
- **Launching other emulators.** The library app and its launcher are retired (the user's call, 2026-11-07).
- **Platforms other than Apple's.**

## Principles

- **Layered, and the law is mechanical.** Four layers, dependencies pointing down, enforced by a check — see [ADR 0001](../adrs/layer-enforcement.md).
- **The oracle decides.** A ported subsystem is right when its guest-visible behaviour matches the oracle's; the first divergence is the bug.
- **Provenance stays clean and visible.** Every ported file names the permissive file it comes from and keeps its notice; nothing is learned from a GPL emulator's code, and a session that has read one writes no core code ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md)).
- **Release builds carry no tools.** Anything for debugging or tracing compiles only into personal builds.
- **The user's data is theirs.** Settings and memory cards written by an older version keep loading ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md), carrying ADR 0007's rule).
- **The first milestone matters most.** Until the Swift R3000A boots the BIOS and passes ps1-tests' CPU tests with a trace that matches SwanStation's, nothing else in a core is worth building.

## Success criteria

- **v0.0.1:** JIT runs in an App Store-routine macOS app; both build routines produce the macOS and iOS apps; the R3000A interpreter, the memory map and the BIOS boot pass ps1-tests' CPU tests with a guest-state trace that matches SwanStation's.
- PS1 games boot and play in both apps.
- Each app passes App Review under section 4.7.
- PS2: the EE and IOP interpreters run a homebrew ELF through the HLE BIOS, with output and post-boot guest trace matching PCSX2.

---

*Revisions are dated notes inline where the text changed ("Revised YYYY-MM-DD (the user's call): …").*
