# iStation — Developer Reference

The module-by-module reference: the tree, each module's files and interfaces, the build/test commands, and the recipes for every extension point. The rules and their reasons are in [CLAUDE.md](CLAUDE.md) and the [ADRs](../adrs/README.md); this file says *where things are and how to work with them*.

## Directory tree

```
CLAUDE.md                      root pointer → documentation/CLAUDE.md
README.md                      public overview
LICENSE · LICENSES/            iStation's MIT licence; MIT.txt and BSD-2-Clause.txt for the SPDX headers
iStation.xcodeproj/            the two apps over the package; four shared schemes (macOS/iOS × Personal/App Store)
.github/workflows/ci.yml       strict build, swift test, both apps' personal builds, docs validator
scripts/validate_docs.py       the docs validator (backlog index ↔ documents, links)
documentation/                 the router and this docs home
tools/
  jit-probe/                   the JIT probe (3a): one sandboxed allow-jit app, build.sh, results in README.md
src/istation/
  Package.swift                the module map (ADR 0002), the products PS1Core, EmuKit and TraceKit, PERSONAL_BUILD in debug
  apps/
    Acknowledgements.json      every notice the apps carry, bundled into both
    Config/                    Version.xcconfig · AppStore.xcconfig (Release) · Personal.xcconfig (Debug)
    macos/                     Sources/iStationApp.swift · AppStore.entitlements · Personal.entitlements
    ios/                       Sources/iStationApp.swift · AppStore.entitlements · Personal.entitlements
  scripts/
    build-personal.sh          the personal routine: one app, Debug, into build/DerivedData
    archive-appstore.sh        the App Store routine: one app, Release, archived into build/<platform>/
  source/
    infrastructure/            CLAUDE.md · bytes/
    data/                      CLAUDE.md · iso9660/ systemcnf/ playlists/ tracing/
    business/                  CLAUDE.md · r3000a/ ps1/
    presentation/              CLAUDE.md · styles/ player/ acknowledgements/
  tests/
    infrastructure/ data/ business/ presentation/   CLAUDE.md each · one directory per module
    support/                   sandbox/ (infrastructure) · discfixtures/ (data) · mips/ r3000atrace/ (business)
    architecture/              the layering, layer-context and project-rule checks
```

`src/istation/build/` (archives and DerivedData) and every `.build/` are git-ignored.

## Build, test, run

From `src/istation/` unless noted.

| Task | Command |
|---|---|
| Build the package | `swift build` |
| Strict build (CI) | `swift build --explicit-target-dependency-import-check=error` |
| Test (includes the layering, layer-context and project-rule checks) | `swift test` |
| One module's tests | `swift test --filter DataISO9660Tests` |
| Only the architecture checks | `swift test --filter ArchitectureTests` |
| Build one module alone | `swift build --target PresentationPlayer` |
| Personal build of an app | `./scripts/build-personal.sh macOS` (or `iOS`, for the Simulator) |
| App Store archive of an app | `./scripts/archive-appstore.sh macOS` (or `iOS`); `ISTATION_TEAM_ID=<team> …` also signs and exports — yours |
| Xcode (repo root) | `open iStation.xcodeproj`; scheme `macOS Personal`: ⌘R runs, ⌘U runs every package test |
| All tests through Xcode (repo root) | `xcodebuild test -project iStation.xcodeproj -scheme "macOS Personal" -destination 'platform=macOS'` |
| TraceKit's throughput (2.5 GB in a temporary folder) | `ISTATION_BENCHMARK=1 swift test -c release --filter ThroughputTests` |
| The R3000A's instructions per second (the spike's loop, 300 M instructions) | `ISTATION_BENCHMARK=1 swift test -c release --filter BusinessR3000ATests.BenchmarkTests` |
| The whole console's speed (the same loop, 600 frames) | `ISTATION_BENCHMARK=1 swift test -c release --filter BusinessPS1Tests.BenchmarkTests` |
| Docs validator (repo root) | `python3 scripts/validate_docs.py documentation` |
| Lint / format | _TODO:_ none chosen |

## The two routines

| | Personal | App Store |
|---|---|---|
| Configuration | Debug | Release |
| xcconfig | `apps/Config/Personal.xcconfig` | `apps/Config/AppStore.xcconfig` |
| Compilation conditions | `DEBUG PERSONAL_BUILD` (the package: `PERSONAL_BUILD` in debug) | none |
| macOS entitlements | `get-task-allow`, `allow-jit` | App Sandbox, read-only user-selected files, `allow-jit` |
| iOS entitlements | `get-task-allow` | none |
| Signing | to run locally (macOS) / Simulator (iOS) | ad-hoc or unsigned; the user's team for distribution |
| Tools | TraceKit and debug views | compiled out |
| Schemes | `macOS Personal`, `iOS Personal` | `macOS App Store`, `iOS App Store` |

`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` in the App Store routine keeps local signing from adding `get-task-allow`. The window or navigation title of a personal build reads "iStation — Personal build".

## The test table

Every test target is Swift Testing, named `<Layer><Module>Tests`, at `tests/<layer>/<module>/`, and listed in the `macOS Personal` scheme's tests.

| Suite | Layer | What it covers |
|---|---|---|
| `InfrastructureBytesTests` | Infrastructure | little-endian reads; out-of-range reads are 0 |
| `DataISO9660Tests` | Data | find and read a file in cooked and raw images; reject non-ISO |
| `DataSystemCNFTests` | Data | PS1/PS2 boot keys, serials, PSX.EXE, no boot key |
| `DataPlaylistsTests` | Data | cue files quoted and unquoted; m3u comments; unreadable files |
| `DataTracingTests` | Data | the trace formats byte for byte; round trips across the buffer; truncated, foreign, newer and unknown input; FNV-1a vectors and the register checksum; the first divergence by field; checkpoints; throughput (off by default) |
| `BusinessR3000ATests` | Business | every instruction family against psx-spx over an in-memory bus and a small assembler (`Harness.swift`): ALU and the overflow trap, shifts, MULT/DIV and their edge cases, loads with the load-delay slot, LWL/LWR/SWL/SWR at every offset, branches and jumps with the delay slot, SYSCALL, BREAK, reserved instructions, address and bus errors, interrupts, RFE, the COP0 moves, cache isolation, COP2 routing and Coprocessor Unusable; the tracer through TraceKit's records; the benchmark (off by default) |
| `BusinessPS1Tests` | Business | over BIOS images and PS-EXEs built in code (`Harness.swift`): the memory map's mirrors, segments, read-only BIOS, empty expansions and bus errors; the I/O ports' widths against ps1-tests' io-access-bitwidth log; I_STAT and I_MASK, and the CPU taking the vertical blank; the timers' clocks, targets and flags; DMA's OTC, DPCR and DICR; the NTSC frame and GPUSTAT; PS-EXE parsing and loading; the TTY through expansion 2, the BIOS's putchar and the boot hook; every region's load time; the console powering on; the benchmark (off by default) |
| `PresentationStylesTests` | Presentation | the screen's 4:3 shape; distinct symbols |
| `PresentationPlayerTests` | Presentation | a new player has nothing loaded |
| `PresentationAcknowledgementsTests` | Presentation | the empty state; entries listed in order |
| `ArchitectureTests` | — | `LayeringTests`, `LayerContextTests`, `ProjectRulesTests` (ADRs 0001–0006, 0013, 0016) |

## Modules

### Infrastructure

- **`bytes`** (`InfrastructureBytes`) — `LittleEndian.swift`: `[UInt8].u16le(_:)`, `.u32le(_:)`; a read past either end is 0. Used by `iso9660`.

### Data

- **`iso9660`** (`DataISO9660`) — `ISO9660.swift`: `SectorReader` (internal; detects raw 2352-byte sectors by the sync pattern), `ISO9660(url:)`, `entries(in:)`, `find(_:)`, `read(_:maxBytes:)`, `close()`, `DiscError`.
- **`systemcnf`** (`DataSystemCNF`) — `SystemCNF.swift`: `SystemCNF(text:)` → `console` (`.ps1`, `.ps2`), `serial`; `BOOT2` means PS2, `BOOT` PS1.
- **`playlists`** (`DataPlaylists`) — `Playlists.swift`: `Playlists.cueTracks(_:)`, `Playlists.m3uEntries(_:)`.
- **`tracing`** (`DataTracing`, product `TraceKit`, personal builds only) — [reference/trace-formats.md](../reference/trace-formats.md). `Checksum.swift`: `FNV1a64`, `RegisterChecksum.of(gpr:hi:lo:sr:cause:epc:)`; `InstructionRecord.swift` (and `FullStateRecord`); `FrameRecord.swift`; `TraceFile.swift`: `TraceHeader`, `TraceGranularity`, `TraceRecord`, `TraceError`, `TraceWriter` (1 MB buffer; `append`, `finish()`), `TraceReader` (streaming `next()`, `readAll()`); `TraceDiff.swift`: `TraceDiff.firstDivergence(_:_:ignoringCycles:)` → `TraceDivergence` (index, both records, the differing fields); `Checkpoints.swift`: `Checkpoints.reduce(_:window:)`, `firstDivergentWindow`, `write`, `read`.

### Business

- **`r3000a`** (`BusinessR3000A`, product `PS1Core`; ported from ProjectPSX's `CPU.cs`, so every file carries its notice) — `R3000A.swift`: `R3000A<Bus, Cop2, Tracer>` (a final class; `step()` runs one instruction and returns its fetch cycles; `handleInterrupts()`, called by the console between instructions; `pc`, `nextPC`, `hi`, `lo`, `cycles`, `register(_:)`/`setRegister`, `cop0Register(_:)`/`setCOP0Register`, `jump(to:)`), its pipeline (write-back, the load-delay slot) and `raise`; `Instructions.swift`: decode and execute, ProjectPSX's two opcode tables as switches; `Bus.swift`: `R3000ABus` (fetch, 8/16/32-bit loads and stores with `throws(BusError)` — a narrow store passes the whole source register — and `interruptPending`), `Fetch`, `BusError`; `Coprocessor2.swift`: `Coprocessor2`, `NoCoprocessor2` (the IOP: COP2 is Coprocessor Unusable); `Tracer.swift`: `R3000ATracer`, `RetiredInstruction`, `NoTracer`; `Exceptions.swift`: `ExceptionCode`, `COP0Register`. Every departure from ProjectPSX is a comment beside the code naming psx-spx; the hot path is `@inlinable`, and every stored `var` `@exclusivity(unchecked)` (ADR 0015 §4).
- **`ps1`** (`BusinessPS1`, product `PS1Core`; uses `BusinessR3000A`; ported from ProjectPSX, so every file carries its notice) — `PS1Console.swift`: `PS1Console`, what the apps hold (`name`, `isPoweredOn`, `powerOn(bios:)`, `runFrame()`, `frame`); `PS1Machine.swift`: `PS1Machine<Tracer>` (the bus and the CPU; `runFrame()`, `runSlice()`, `run(cycles:)` — ProjectPSX's loop of ~100-cycle slices; `load(_:)` starts a PS-EXE now, `boot(_:)` once the BIOS reaches 0x80030000; `tty`; `capturesBIOSPutchar`), `PS1Error`; `PS1Bus.swift`: `PS1Bus`, the memory map (the inlined fast path for RAM and BIOS, everything else through `read`/`slowStore`, bus errors where nothing answers), its devices, `copyToRAM`, `zeroRAM`; `MemoryControl.swift`: the delay/size registers, COM_DELAY, RAM_SIZE, cache control, and each region's load time (psx-spx's formula; the hardware log for RAM, scratchpad, I/O and cache control); `InterruptController.swift` (`Interrupt`); `Timers.swift`; `DMA.swift`; `GPU.swift` (timing, GPUSTAT, GP1 — no drawing); `DeviceStubs.swift` (`CDROMStub`, `SPUStub`, `MDECStub`, `PortsStub`); `Expansion2.swift` (the TTY and POST); `PSEXE.swift` (`PSEXE`, `PSEXEError`).

### Presentation

```
source/presentation/
  styles/            Palette.swift  Symbols.swift  Metrics.swift  Typography.swift
  player/            Views/ (PlayerView)  ViewModels/ (PlayerViewModel)  Previews/ (PreviewPlayer)
  acknowledgements/  Views/ (AcknowledgementsView)  ViewModels/ (AcknowledgementsViewModel)  Models/ (Acknowledgement)
```

- **`styles`** (`PresentationStyles`) — `Palette` (screen, on-screen text, secondary text), `Symbols`, `Metrics` (the 4:3 screen, the player's minimum size, padding, spacing), `Typography`.
- **`player`** (`PresentationPlayer`) — `PlayerViewModel(console:)` (`state: .nothingLoaded`, `consoleName`, `message`); `PlayerView` (the screen, preview "Nothing loaded").
- **`acknowledgements`** (`PresentationAcknowledgements`) — `Acknowledgement` (name, SPDX licence, notice, source URL); `AcknowledgementsViewModel(entries:)` (`state: .empty | .listed`); `AcknowledgementsView` (preview "Empty"). Its entries come from `apps/Acknowledgements.json` through `Acknowledgement.bundled(for:)`.

### The apps

- **`apps/macos/Sources/iStationApp.swift`** — the player window, and "Acknowledgements…" in the app menu opening its own window; builds `PS1Console`, `PlayerViewModel` and `AcknowledgementsViewModel`.
- **`apps/ios/Sources/iStationApp.swift`** — the player in a navigation stack, with a toolbar button for the acknowledgements sheet.

## Recipes

### Adding a module

1. Decide its layer (the lowest one that can hold it) and its one-phrase concern.
2. Create `src/istation/source/<layer>/<module>/` and `src/istation/tests/<layer>/<module>/`, each with at least one Swift file.
3. Add its row to `modules` in `Package.swift`: `Module(.<layer>, "<Name>", uses: [<targets>], testSupport: [<support targets>], derivedFrom: .projectPSX),` — on one line, `derivedFrom:` only for a ported module; its target is `<Layer><Name>`. If the apps use it, add the target to a product. Every file opens with its SPDX header (below).
4. Add its name to its layer card's **Modules** line and a row to [ADR 0002](../adrs/module-map.md)'s table (`| <layer> | \`<module>\` | <uses> |`), and a `<TestableReference>` for its `<Layer><Name>Tests` target to `iStation.xcodeproj/xcshareddata/xcschemes/macOS Personal.xcscheme` (copy a neighbour's block, change the three names).
5. Add it to the Codebase Map in CLAUDE.md and a section above.
6. Run `swift test` — the layering and layer-context checks must pass.

### Adding a place (a Presentation feature module)

1. Create `source/presentation/<place>/Views/` and `ViewModels/`, and `tests/presentation/<place>/`; add its `Module(.presentation, …)` row and its target to the `EmuKit` product.
2. Write the view-model first: `@MainActor @Observable`, named states, intents named for what the person does; test it headlessly.
3. Write the views bound to it, every visual from `styles`, each with a named `#Preview` per visible state inside `#if DEBUG`, over fakes in `Previews/`.
4. Build its view-model in each app's `iStationApp.swift` and mount its view.
5. Add it to the Presentation card, ADR 0002's table, the `macOS Personal` scheme's tests and the Codebase Map. Run `swift test`.

### Headers, provenance and the acknowledgements list

Every Swift file in the package and the apps opens with

```swift
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
```

A file ported from a reference sits in a module whose row says `derivedFrom: .projectPSX` (or `.play`), carries that reference's licence (`MIT` or `BSD-2-Clause`), keeps the reference's copyright line as a `SPDX-FileCopyrightText` line beside iStation's, and names its source: `// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés`. A component whose notice an app carries gets an entry in `src/istation/apps/Acknowledgements.json` (its name, SPDX licence, source URL, the apps that carry it, its notice verbatim); a new licence also gets its text in `LICENSES/<id>.txt`. `ArchitectureTests` fails on any one missing.

### Adding a view

In its module's `Views/`, one top-level view per file, bound to that module's view-model, visuals from `styles`, with a named `#Preview` per visible state in the same file, inside `#if DEBUG`.

### Adding a debug view or a tool

A debug view goes in its module's `Debug/` and opens with `#if PERSONAL_BUILD`; an import of TraceKit (`DataTracing`) sits inside `#if PERSONAL_BUILD`. `ArchitectureTests` fails on either outside the guard.

### Adding or promoting a shared component

A component a second module wants moves to `source/presentation/styles/Components/` (never copied): make its inputs plain values and callbacks (no feature view-model), move its previews with it, update both users, delete the original.

### Adding a token

Add it to `Palette`, `Symbols`, `Metrics` or `Typography`, named for its role, and replace the literal that prompted it. `ArchitectureTests` rejects literal colors, sizes and paddings in feature views.

### Changing an entitlement

Edit the routine's file in `apps/<platform>/`. An App Store file never carries `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow` (either spelling); `ArchitectureTests` fails on one, and on an app without both routines' files.

### Adding a persisted format

Settings, memory cards and save states: a new field decodes with a default; a save state carries its version and an older one is refused with a message; each released shape gets a recorded fixture its tests read, never edited ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md) §5).

### Adding a disc format

A new Data module per format (e.g. `chd`); its fixtures are built in memory in `SupportDiscFixtures` — never a real image.

### Proving an architecture rule

Plant the violation (an import, a directory, a row, an entitlement), run `swift test --filter ArchitectureTests`, confirm the failure names the rule in brackets and the file, then remove the plant. A rule SwiftPM itself refuses to load (a cycle, `styles` using a sibling) is planted in a copy of `Package.swift` and checked with `ISTATION_ARCHITECTURE_MANIFEST=<copy> swift test --filter ArchitectureTests`: the checks parse the copy while the build uses the real manifest. An import that would not compile is planted inside `#if false`, which the compiler skips and the check still reads.
