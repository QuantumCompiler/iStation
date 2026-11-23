# iStation — Developer Reference

The module-by-module reference: the tree, each module's files and interfaces, the build/test commands, and the recipes for every extension point. The rules and their reasons are in [CLAUDE.md](CLAUDE.md) and the [ADRs](../../adrs/darwin/README.md); this file says *where things are and how to work with them*.

## Directory tree

```
CLAUDE.md                      root pointer → lib/documentation/CLAUDE.md
README.md                      public overview
LICENSE · LICENSES/            iStation's MIT licence; MIT.txt and BSD-2-Clause.txt for the SPDX headers
.github/workflows/ci.yml       the repository's pipeline: docs, version bump, tag and release
.github/workflows/darwin.yml   the Apple apps' pipeline: what changed, then build darwin (cicd.sh --app darwin --test)
.claude/                       settings.json (Superpowers; worktree.baseRef: head) · skills/: the 13 istation-* lifecycle skills
.gitignore                     build output and .build/, Local.xcconfig, .superpowers/, .claude/worktrees/, .claude/settings.local.json
lib/
  documentation/               by kind, then platform: CLAUDE.md (the router); assistant/ backlog/ adrs/ reference/,
                               each a README.md and darwin/ (this application), with macos/ and ios/ beneath
  release/VERSION              the release, and the only thing that names one; the apps' version follows it
  scripts/
    cicd.sh                    the one build path, a developer's and CI's: --app darwin, --test, --docs, --all
    changed.sh                 what each pipeline is built from, and whether it changed since the latest release
    pr-ci.sh                   rehearses a pull request's CI run on the test merge into stable
    required-checks.py         proposes stable's required checks from a pull request's passing jobs (--apply: yours)
    validate_docs.py           the docs validator (each application's backlog index ↔ documents, every link)
    version-check.sh           CI's `version bump`: what merging into stable publishes, and whether VERSION allows it
    release-from-pr.sh         CI's `tag and release`: tags a merged pull request's commit v<VERSION>, publishes its source
    latest-release.sh          the newest published release's tag and commit
  src/darwin/                  the Apple apps, self-contained (Apogee's layout)
    Package.swift              the module map (ADR 0002), the products PS1Core, EmuKit and TraceKit, PERSONAL_BUILD in debug
    iStation.xcodeproj/        the two apps over the package; four app schemes (macOS/iOS × Personal/App Store) and one
                               per Presentation module (ADR 0017); its navigator shows the whole repository
    apps/
      Acknowledgements.json    every notice the apps carry, bundled into both
      Config/                  Version.xcconfig · AppStore.xcconfig (Release) · Personal.xcconfig (Debug) · Local.xcconfig (yours, git-ignored)
      macos/                   Sources/iStationApp.swift · AppStore.entitlements · Personal.entitlements
      ios/                     Sources/iStationApp.swift · AppStore.entitlements · Personal.entitlements
    scripts/
      build.sh                 the one entry point: build.sh personal macOS|iOS [--unsigned] · appstore macOS|iOS
      build-personal.sh        the personal routine: one app, Debug, as "iStation Personal.app" into build/DerivedData
      archive-appstore.sh      the App Store routine: one app, Release, archived into build/<platform>/
    source/
      infrastructure/          CLAUDE.md · bytes/
      data/                    CLAUDE.md · iso9660/ systemcnf/ playlists/ tracing/
      business/                CLAUDE.md · r3000a/ ps1/ session/
      presentation/            CLAUDE.md · styles/ player/ acknowledgements/
    tests/
      infrastructure/ data/ business/ presentation/   CLAUDE.md each · one directory per module
      support/                 sandbox/ (infrastructure) · discfixtures/ (data) · mips/ r3000atrace/ (business)
      architecture/            the layering, layer-context and project-rule checks
    tools/
      jit-probe/               the JIT probe (3a): one sandboxed allow-jit app, build.sh, results in README.md
      projectpsx-trace/        ProjectPSX at f4dc13aea42d with trace logging (3d): trace.patch, host/, build.sh, run.sh
      swanstation-oracle/      SwanStation built unmodified, and frontend.c, its headless libretro frontend (3d)
      istation-run/            the Swift console from the command line, the CPU-check program, trace diff (3d, 3g)
      ps1-tests/               fetch.sh: the open CPU tests' programs and their psx.log files, into .build/ (3d, 3g)
      gate/                    run.sh: v0.0.1's gate with the user's BIOS — the boot and the CPU tests on all three (3g)
```

`lib/src/darwin/build/` (archives and DerivedData) and every `.build/` are git-ignored.

## Build, test, run

From `lib/src/darwin/` unless noted.

| Task | Command |
|---|---|
| Build the package | `swift build` |
| Strict build (CI) | `swift build --explicit-target-dependency-import-check=error` |
| Test (includes the layering, layer-context and project-rule checks) | `swift test` |
| One module's tests | `swift test --filter DataISO9660Tests` |
| Only the architecture checks | `swift test --filter ArchitectureTests` |
| Build one module alone | `swift build --target PresentationPlayer` |
| Personal build of an app | `./scripts/build.sh personal macOS` (or `iOS`, for the Simulator) |
| App Store archive of an app | `./scripts/build.sh appstore macOS` (or `iOS`); `ISTATION_TEAM_ID=<team> …` also signs and exports — yours |
| Xcode (repo root) | `open lib/src/darwin/iStation.xcodeproj`; scheme `macOS Personal`: ⌘R runs, ⌘U runs every package test; a module's own scheme (`PresentationPlayer`) builds and tests it alone |
| All tests through Xcode (repo root) | `xcodebuild test -project lib/src/darwin/iStation.xcodeproj -scheme "macOS Personal" -destination 'platform=macOS'` |
| TraceKit's throughput (2.5 GB in a temporary folder) | `ISTATION_BENCHMARK=1 swift test -c release --filter ThroughputTests` |
| The R3000A's instructions per second (the spike's loop, 300 M instructions) | `ISTATION_BENCHMARK=1 swift test -c release --filter BusinessR3000ATests.BenchmarkTests` |
| The whole console's speed (the same loop, 600 frames) | `ISTATION_BENCHMARK=1 swift test -c release --filter BusinessPS1Tests.BenchmarkTests` |
| The CPU check: one program on ProjectPSX and the Swift console, traces diffed (repo root) | `lib/src/darwin/tools/projectpsx-trace/build.sh && lib/src/darwin/tools/istation-run/cpu-check.sh` |
| The gate, with your own BIOS (repo root; after both tools' `build.sh` and `lib/src/darwin/tools/ps1-tests/fetch.sh`) | `lib/src/darwin/tools/gate/run.sh <bios> [--scph1001] [--out <folder>]` |
| Everything CI runs, the one build path (repo root) | `lib/scripts/cicd.sh --all` (or `--app darwin`, `--test`, `--docs`) |
| Rehearse a pull request's CI run (repo root) | `lib/scripts/pr-ci.sh` (`--uncommitted` to include what isn't committed) |
| Has the apps' source changed since the latest release? (repo root) | `lib/scripts/changed.sh darwin <from> HEAD` |
| Docs validator (repo root) | `python3 lib/scripts/validate_docs.py lib/documentation` |
| What merging into stable would publish (repo root) | `lib/scripts/version-check.sh` |
| Rehearse a pull request's release (repo root; `--publish` is CI's) | `lib/scripts/release-from-pr.sh <pr>` |
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

**Signing with your team.** Your development team never enters the repository (the user's call, 2026-11-14). Both routines' xcconfigs end with `#include? "Local.xcconfig"`, and `lib/src/darwin/apps/Config/Local.xcconfig`, git-ignored, holds `DEVELOPMENT_TEAM = <your team ID>` on your Mac; without the file nothing changes, and `scripts/archive-appstore.sh`'s `ISTATION_TEAM_ID` still overrides it. Set the team there, not in Xcode's Signing & Capabilities pane: the pane writes `DEVELOPMENT_TEAM` into `project.pbxproj`, which is committed — if it does, move the value to `Local.xcconfig` and delete the line from the project.

## The test table

Every test target is Swift Testing, named `<Layer><Module>Tests`, at `tests/<layer>/<module>/`, and listed in the `macOS Personal` scheme's tests.

| Suite | Layer | What it covers |
|---|---|---|
| `InfrastructureBytesTests` | Infrastructure | little-endian reads; out-of-range reads are 0 |
| `DataISO9660Tests` | Data | find and read a file in cooked and raw images; reject non-ISO |
| `DataSystemCNFTests` | Data | PS1/PS2 boot keys, serials, PSX.EXE, no boot key |
| `DataPlaylistsTests` | Data | cue files quoted and unquoted; m3u comments; unreadable files |
| `DataTracingTests` | Data | the trace formats byte for byte; round trips across the buffer; truncated, foreign, newer and unknown input; FNV-1a vectors and the register checksum; the first divergence by field; checkpoints; throughput (off by default) |
| `BusinessR3000ATests` | Business | every instruction family against psx-spx over an in-memory bus (`Harness.swift`) and `SupportMIPS`'s assembler: ALU and the overflow trap, shifts, MULT/DIV and their edge cases, loads with the load-delay slot, LWL/LWR/SWL/SWR at every offset, branches and jumps with the delay slot, SYSCALL, BREAK, reserved instructions, address and bus errors, interrupts, RFE and COP0's other commands, the COP0 moves and which registers they reach, COP1, COP3 and LWCn/SWCn as ps1-tests' `cop` shows them on hardware, user mode, cache isolation, COP2 routing and Coprocessor Unusable; the tracer through TraceKit's records; the benchmark (off by default) |
| `BusinessPS1Tests` | Business | over BIOS images and PS-EXEs built in code (`Harness.swift`): the memory map's mirrors, segments, read-only BIOS, empty expansions and bus errors; the I/O ports' widths against ps1-tests' io-access-bitwidth log; I_STAT and I_MASK, and the CPU taking the vertical blank; the timers' clocks, targets and flags; DMA's OTC, DPCR and DICR; the NTSC frame and GPUSTAT; PS-EXE parsing and loading; the TTY through expansion 2, the BIOS's putchar and the boot hook, what an EXE printed apart from the BIOS, and an EXE waiting while the BIOS never reaches its shell; an empty controller port; the load times of RAM, the BIOS, the scratchpad and an I/O port, and psx-spx's formula for the rest; the console powering on, and its narrow interface (`ConsoleInterfaceTests.swift`: `ShellTests`, `ConsoleBootTests`): the shell watched from power-on until it is first reached, and on while putchar is captured, `reachedShell` turning true once and staying, an EXE given before the shell starting in its place outside any exception, the BIOS's vertical-blank handler still running, one given after it waiting for good — to play it, the console powers on again and is given it again — and a second EXE replacing one that waits, an EXE waiting for a shell the BIOS never reaches, the shell or a putchar call reached at a slice's first instruction or interrupted at a slice's end (EPC the watched address) taken once, never inside the exception, a fresh machine at each power-on, a failed power-on changing nothing, nothing booted or reached while powered off; in personal builds (`PersonalConsoleTests.swift`: `DebugSnapshotTests`, `TracingConsoleTests`), the debug snapshot against the CPU after a known program — its cycles the CPU's, not the system clock's — its TTY, and the console's taken between frames, and the tracing console's tracer seeing what a machine's does over the same image and frames, its RAM read, an EXE waiting for a shell never reached, a fresh machine at each power-on and a failed one changing nothing; the review's regressions (`BusRegressionTests`, `DeviceRegressionTests`): RAM_SIZE's window, the expansions' sizes, the locked gaps, the port widths, DMA's bounds and endings, DICR's interrupt, the GPU's clock, fields and GP1(08h); the benchmark (off by default) |
| `BusinessSessionTests` | Business | over BIOS images and a PS-EXE built in code (`Harness.swift`, with `SupportMIPS`'s programs and images, which `BusinessPS1Tests` shares) and `ManualClock`, a clock the test moves a sixtieth at a time, every wait with a timeout: a new session powered off and holding no console; power-on at frame 0 and no frame before a sixtieth has passed, a wrong-size BIOS refused and changing nothing, powering on again starting afresh; sixty ticks running sixty frames in one second of the clock, the frame waiting between ticks, a frame one sixtieth late caught up and a session further behind pacing from now instead of racing, frames per second measuring the frames actually run, and with `ContinuousClock` frames keeping to the clock (the one test on real time: after the first frame, half a second holding at most 60 frames a second and at least 15, a floor a loaded machine meets; the exact 60 is `ManualClock`'s proof, over the same `FramePace`); pause holding the frame and resume continuing from it, each only in its state; reset powering on again from frame 0 and booting the same EXE again, a paused session included, and doing nothing before power-on; stop ending the loop, releasing the console and finishing the stream, and a stopped session powering on again with new streams; the stream starting with the current snapshot and following the frames, and one taken once stopped giving the stopped snapshot until the next stop; an EXE given at power-on starting once the BIOS reaches its shell, one waiting for a shell the BIOS never reaches, and without one nothing waiting; in personal builds (`PersonalSessionTests`), the instructions growing frame by frame, the debug snapshot there once powered on, and the BIOS's putchar heard only when captured. `swift test` runs debug, so the App Store build's `PS1Console` path is compiled, not tested, unless `swift test -c release -Xswiftc -enable-testing --filter BusinessSessionTests` is run |
| `PresentationStylesTests` | Presentation | every color role, text style, space, radius, duration and layout size in the design's `json/tokens.json` (read by its repository path) against its `styles` member, and every `contrastPairs` entry recomputed from the Swift values; the theme's resolution under the light, dark and high-contrast appearances; each symbol an SF Symbol that exists, there by macOS 14 and iOS 17; a job's status, current step, progress and which button Return, Escape and ⌘. press; each tone a `contrastPairs` entry with its symbol; a shortcut's keycap glyphs; the screen's 4:3 shape; distinct symbols |
| `PresentationPlayerTests` | Presentation | over `FakeSession`, a scripted `ConsoleSessionControls` that records every call: nothing loaded, and no control applying; a run followed from frame 0 once its starter calls `started(_:)`, its frames and frames per second as the snapshots give them, the rate hidden until the session has measured a whole second, and a PS-EXE named as the library names it; pause holding the frame and resume running from it, each only in its state, and the controls reaching the session in the order given; Reset and Stop asking first and pausing the game, one question at a time, a pause sent even when the player shows paused so a Resume still on its way can't leave the game running under the alert, Reset's Details naming the kept BIOS file, its size and a PS-EXE's `boot(exe:)`, confirming Reset running from frame 0 and Stop ending the run and saving nothing, cancelling leaving the game paused or the run kept; a session stopped elsewhere stopping the player, a run started after a stop followed, a stopped player following the next power-on, a run told before the old one stops followed once it powers on, a stream that ends without a stop leaving the player as it was, and a player let go letting its session go; the window titled with the run while it plays; full screen toggled while playing, following the window's own, left on stopping and once nothing plays; numbers grouped by thousands as the design writes them |
| `PresentationAcknowledgementsTests` | Presentation | the empty state; entries listed in order; each app gets only the entries it carries; the committed `apps/Acknowledgements.json` decodes for both apps (Play! macOS-only); a missing bundled list is no entries |
| `ArchitectureTests` | — | `LayeringTests`, `LayerContextTests`, `ProjectRulesTests` (ADRs 0002, 0013, 0014, 0016, 0017, 0019, 0021–0024) |

## Modules

### Infrastructure

- **`bytes`** (`InfrastructureBytes`) — `LittleEndian.swift`: `[UInt8].u16le(_:)`, `.u32le(_:)`; a read past either end is 0. Used by `iso9660`.

### Data

- **`iso9660`** (`DataISO9660`) — `ISO9660.swift`: `SectorReader` (internal; detects raw 2352-byte sectors by the sync pattern), `ISO9660(url:)`, `entries(in:)`, `find(_:)`, `read(_:maxBytes:)`, `close()`, `DiscError`.
- **`systemcnf`** (`DataSystemCNF`) — `SystemCNF.swift`: `SystemCNF(text:)` → `console` (`.ps1`, `.ps2`), `serial`; `BOOT2` means PS2, `BOOT` PS1.
- **`playlists`** (`DataPlaylists`) — `Playlists.swift`: `Playlists.cueTracks(_:)`, `Playlists.m3uEntries(_:)`.
- **`tracing`** (`DataTracing`, product `TraceKit`, personal builds only) — [reference/trace-formats.md](../../reference/darwin/trace-formats.md). `Checksum.swift`: `FNV1a64`, `RegisterChecksum.of(gpr:hi:lo:sr:cause:epc:)`; `InstructionRecord.swift` (and `FullStateRecord`); `FrameRecord.swift`; `TraceFile.swift`: `TraceHeader`, `TraceGranularity`, `TraceRecord`, `TraceError`, `TraceWriter` (1 MB buffer; `append`, `finish()`), `TraceReader` (streaming `next()`, `readAll()`); `TraceDiff.swift`: `TraceDiff.firstDivergence(_:_:ignoringCycles:)` → `TraceDivergence` (index, both records, the differing fields); `Checkpoints.swift`: `Checkpoints.reduce(_:window:)`, `firstDivergentWindow`, `write`, `read`.

### Business

- **`r3000a`** (`BusinessR3000A`, product `PS1Core`; ported from ProjectPSX's `CPU.cs`, so every file carries its notice) — `R3000A.swift`: `R3000A<Bus, Cop2, Tracer>` (a final class; `step()` runs one instruction and returns its fetch cycles; `handleInterrupts()`, called by the console between instructions; `settlePendingLoad()`, for a loader setting registers; `pc`, `nextPC`, `hi`, `lo`, `cycles`, `register(_:)`/`setRegister`, `cop0Register(_:)`/`setCOP0Register`, `jump(to:)`), its pipeline (write-back, the load-delay slot) and `raise`; `Instructions.swift`: decode and execute, ProjectPSX's two opcode tables as switches; `Bus.swift`: `R3000ABus` (fetch, 8/16/32-bit loads and stores with `throws(BusError)` — a narrow store passes the whole source register — `peek32`, memory's word without a load's cost or a device's side effects, for the look-ahead and SWL/SWR, and `interruptPending`), `Fetch`, `BusError`; `Coprocessor2.swift`: `Coprocessor2`, `NoCoprocessor2` (the IOP, and the PS1 until v0.2.0's GTE: COP2 is Coprocessor Unusable); `Tracer.swift`: `R3000ATracer`, `RetiredInstruction`, `NoTracer`; `Exceptions.swift`: `ExceptionCode`, `COP0Register`. Every departure from ProjectPSX is a comment beside the code naming psx-spx; the hot path is `@inlinable`, and every stored `var` `@exclusivity(unchecked)` (ADR 0015 §4).
- **`ps1`** (`BusinessPS1`, product `PS1Core`; uses `BusinessR3000A`; ported from ProjectPSX, so every file carries its notice) — `PS1Console.swift`: `PS1Console`, what the session runs for the apps, fixed to `NoTracer` — its narrow interface, plain values given and read between frames (`name`, "PS1"; `isPoweredOn`; `powerOn(bios:)`, a fresh machine each time; `runFrame()`; `frame`; `boot(exe: PSEXE)`, which starts the EXE in place of the BIOS's shell once the BIOS reaches it — one given after that waits for good, so the session powers on, then boots; `bootIsPending`; `reachedShell`; and in personal builds `debugSnapshot: PS1DebugSnapshot?` — each nothing, false or nil while powered off); `PS1Machine.swift`: `PS1Machine<Tracer>` (the bus and the CPU; `runFrame()`, `runSlice()`, `run(cycles:)` — ProjectPSX's loop of ~100-cycle slices, which, from power-on until the shell is first reached and for as long as `capturesBIOSPutchar`, tests each PC inline — one AND, and three compares for the 64 addresses that pass it — and calls `watch()` only at 0x80030000, 0xA0 and 0xB0; `load(_:)` starts a PS-EXE now, `boot(_:)` once the BIOS reaches 0x80030000 — never at once, which would start the EXE wherever the BIOS was, often inside an interrupt's exception — a second EXE replacing one that waits; `reachedShell`, true from the PC's first visit to 0x80030000 on; `tty`, and `ttySinceEXE`, without what the BIOS printed before the EXE; `bootIsPending` while a booted EXE waits for the shell, for good when the BIOS never gets there or already had; `capturesBIOSPutchar`), `PS1Error`; `PS1DebugSnapshot.swift` (personal builds only): `PS1DebugSnapshot`, one `Sendable`, `Equatable` value — `pc`, the 32 `registers`, `hi`, `lo`, `sr`, `cause`, `epc`, `cycles` (the CPU's, the count TraceKit's records carry), `frame`, `tty`, `ttySinceEXE` — with a public memberwise init for previews and tests, and `PS1Machine.debugSnapshot`, which both consoles read; `PS1TracingConsole.swift` (personal builds only): `PS1TracingConsole<Tracer: R3000ATracer>`, `PS1Console`'s members over a machine with a tracer (`powerOn(bios:tracer:capturesBIOSPutchar:)`), plus `tracer` (a copy of the CPU's, its references the console's own) and `withRAM(_:)`, for a recording's TraceKit instruction and frame records as `istation-run run` writes them; `PS1Bus.swift`: `PS1Bus`, the memory map (the inlined fast path for RAM and BIOS, everything else through `read`/`slowStore`, bus errors where psx-spx maps nothing or locks the address), its devices, `peek32`, `withRAM(_:)` (guest RAM, read-only, without a load's cost: for traces and tools), `copyToRAM`, `zeroRAM`; `MemoryControl.swift`: the delay/size registers, COM_DELAY, RAM_SIZE, cache control, each region's load time (psx-spx's formula; the hardware log for RAM, scratchpad, I/O and cache control), and the expansions' and RAM banks' sizes; `InterruptController.swift` (`Interrupt`); `Timers.swift`; `DMA.swift` (at most 0x10000 words a store or a tick); `GPU.swift` (timing, GPUSTAT, GP1 — no drawing); `DeviceStubs.swift` (`CDROMStub`, `SPUStub`, `MDECStub`, `PortsStub` — its controller port an empty one, a byte sent answered 0xFF); `Expansion2.swift` (the TTY, its last 1 MB kept, `ttyCount`, and POST); `PSEXE.swift` (`PSEXE`, `PSEXEError`).
- **`session`** (`BusinessSession`, product `PS1Core`; uses `BusinessPS1`, and `BusinessR3000A` in personal builds for the counting tracer; iStation's own and not a core, but what the apps do with one, [ADR 0024](../../adrs/darwin/four-layers-and-business-holds-the-session.md)) — `ConsoleSession.swift`: `ConsoleSession<SessionClock: Clock>`, an actor whose own state is the console — `PS1Console` in App Store builds, `PS1TracingConsole<InstructionCounter>` in personal builds, chosen at compile time — so every call into it is made there, one at a time, between frames (ADR 0015 §4); `init(clock:)`, and `init()` over `ContinuousClock`, as the apps run it; `snapshot`; `powerOn(bios:exe:)` (in any state a fresh console: `powerOn(bios:)`, then the PS-EXE to `boot(exe:)` before the first frame, which runs a sixtieth of a second later; a wrong-size BIOS throws `PS1Error` and changes nothing), and in personal builds `powerOn(bios:exe:capturesBIOSPutchar:)`; `pause()`, `resume()`, `reset()` (power on again with the same BIOS, boot the same PS-EXE again and run from frame 0, a paused session too), `stop()` (the loop ended, the console released, every stream finished with the stopped snapshot; nothing saved); `snapshots()`, a new `AsyncStream` per call, the current snapshot first, the newest kept for a slow reader. Its frame loop is a `Task.detached` that holds the session weakly and carries a number, so a loop that a pause, reset, power-on or stop ended runs no frame more; `FramePace` makes frame n due at start + n/60 s, catches up a frame up to one late, and after a longer stall starts the pace again from now, never in a burst. Frames per second counts the frames run over each whole second of running, 0 until one has. `ConsoleSessionSnapshot.swift`: `ConsoleSessionSnapshot`, `Sendable` and `Equatable` — `state` (`.poweredOff`, `.running`, `.paused`, `.stopped`), `frame`, `framesPerSecond`, `reachedShell`, `bootIsPending`, and in personal builds `instructions` and `debugSnapshot` — with a public init for fakes, previews and tests. `ConsoleSessionControls.swift`: `ConsoleSessionControls`, what the player drives (pause, resume, reset, stop, `snapshots()`; no power-on), which `ConsoleSession` conforms to and fakes stand in for. `InstructionCounter.swift` (personal builds only): an `R3000ATracer` counting the instructions retired.

### Presentation

```
source/presentation/
  styles/            Palette.swift  Theme.swift  Typography.swift  Metrics.swift  Motion.swift  Symbols.swift
                     Components/ (JobSheet  DetailsAlert  Chip  Banner  Keycap)  Models/ (JobPresentation  Tone)  Previews/ (PreviewJobs)
  player/            Views/ (PlayerView  PlayerHUD  PlayerWindow)  ViewModels/ (PlayerViewModel)  Models/ (PlayerRun  PlayerAlert)
                     Previews/ (PreviewPlayer)
  acknowledgements/  Views/ (AcknowledgementsView)  ViewModels/ (AcknowledgementsViewModel)  Models/ (Acknowledgement)  Previews/ (PreviewAcknowledgements)
```

- **`styles`** (`PresentationStyles`) — the design's [`json/tokens.json`](../../design/darwin/json/tokens.json) in Swift, each member named for its role as the file's `swiftui` map says ([ADR 0023](../../adrs/darwin/presentation-is-mvvm-and-styles-carries-the-design.md)). `Palette`: a static member per color role, each a dynamic `NSColor`/`UIColor` provider of its dark, light and high-contrast values, resolved at draw time (`screen`, `onScreen` and `secondaryText` kept; the focus ring and the sheet and alert dimming stay the system's). `Theme`: the theme setting — Match the system (the default: dark or light as the system is, High contrast while Increase Contrast is on), Dark, Light, High contrast — and the resolution the providers read, through `Theme.applied`, which Settings (5e) sets with the scheme each choice asks for (dark whenever it resolves to high contrast). `Typography`: the macOS and iOS text styles (`largeTitle` to `caption`), their weights and the monospaced face, scaled on macOS by the text-size setting's multiplier and on iOS by Dynamic Type. `Metrics`: `space1` to `space10`, the radii, the macOS and iOS layout sizes (`Metrics.layout`, a sheet's and an alert's width among them), and the player's own (the 4:3 screen, its minimum size, padding, spacing). `Motion`: fast, base and slow and the design's curve, none under Reduce Motion. `Symbols`: an SF Symbol per icon the design draws. `Components/`, the shared components, each with a named preview per state: `JobSheet` over `Models/`' `JobPresentation` (steps, progress, summary, buttons), its buttons' `SheetButtonStyle` (`.bordered`, `.primary`, `.destructive`; public, for the player's Resume too), `DetailsAlert` (an alert whose Details disclosure shows the exact call), `Chip`, `Banner`, `Keycap`.
- **`player`** (`PresentationPlayer`; uses `BusinessSession`, and `BusinessPS1` for the console's name) — the player as the design's Today player draws it. `Models/`: `PlayerRun` (the BIOS file's name and size and, for a PS-EXE, its `Program`'s name and file name, as the starter tells the player), `PlayerAlert` (title, message, Details, confirm button). `PlayerViewModel(session: any ConsoleSessionControls)`: `started(_ run: PlayerRun)`, which whatever starts a run (5c, 5d) calls just before or after it powers the session on, after which the view-model follows `session.snapshots()` on the main actor — across a stop too, since a stop finishes every stream: after one it takes the session's next stream, so a run powered on after a stop is seen, while a stream that ends without one ends the follow, and so does letting the view-model go; `state` (`.nothingLoaded`, `.running`, `.paused`, `.stopped`, only ever from a snapshot), `run`, `frame`, `framesPerSecond`, `isFullScreen`, `confirmation` (`.reset`, `.stop`); the intents `pause()`, `resume()`, `togglePause()`, `askToReset()` and `askToStop()` (asking pauses the game: the pause is sent whatever the last snapshot said, after any control before it), `confirm()`, `cancel()` (a game the question paused stays paused), `toggleFullScreen()`, `exitFullScreen()`, `fullScreenDidChange(_:)`, each control sent to the session after the one before; and the texts and switches the views read (`message`, `statusText`, `hudFrameText`, `framesPerSecondText`, `statusLine`, `windowTitle` — the run's name while it plays, as the design's toolbar names it — `alert`, `canPause` … `canToggleFullScreen`), numbers grouped by thousands as the design writes them. `Views/`: `PlayerView` (the "No picture yet" panel counting frames under the HUD, the paused overlay with Resume in its place, the idle and stopped screens, and Reset's and Stop's `DetailsAlert`), `PlayerHUD` (the status chip, the name, the frame counter and frames per second; in full screen also Pause or Resume and Exit full screen), and on macOS `PlayerWindow.swift`: `playerWindow(_:idleTitle:)` (the window's chrome — the toolbar, Stop leading with the design's back chevron; Pause or Resume and Reset, then Full screen in a group of its own for the design's separator, trailing; the window titled with the run's name while it plays and `idleTitle` otherwise, its status line under the title — and its full screen kept in step with the player both ways) and `PlayerCommands`, the Game menu (Pause or Resume ⌘P, Reset… ⌘R, Enter or Exit Full Screen ⌃⌘F, Stop… ⌘., as the design's Game menu names it), with previews "Window, nothing loaded", "Window, running", "Window, running a PS-EXE", "Window, paused", "Window, Reset confirm" and "Window, stopped", which apply the chrome alone, never the window's full screen; an image renderer draws no window chrome, so the toolbar and title show only in Xcode's canvas. Previews "Nothing loaded", "Running", "Running, first second", "Running a PS-EXE", "Paused", "Stopped", "Reset confirm" and "Stop confirm" (each also for a PS-EXE), "Full screen" and "Minimum size", and the HUD's "HUD running", "HUD running, first second", "HUD paused" and "HUD full screen", over `Previews/`' `PreviewSession`, an actor answering the controls without a console.
- **`acknowledgements`** (`PresentationAcknowledgements`) — `Acknowledgement` (name, SPDX licence, notice, source URL); `AcknowledgementsViewModel(entries:)` (`state: .empty | .listed`); `AcknowledgementsView` (previews "Empty" and "Listed", over `PreviewAcknowledgements`' in-memory entries). Its entries come from `apps/Acknowledgements.json` through `Acknowledgement.bundled(for:)`.

### The apps

- **`apps/macos/Sources/iStationApp.swift`** — one main window, a single `Window` scene rather than a group, so neither File › New nor the tab bar opens a second one: the player takes it (`playerWindow(_:idleTitle:)`, titled "iStation", or "iStation — Personal build", while nothing plays; at least 800 × 560 less the toolbar, 1280 × 800 by default), with the Game menu (`PlayerCommands`), one console at a time; closing the window leaves the session as it is, until 5d decides what closing does to a run; "Acknowledgements…" in the app menu opens its own window. Builds one `ConsoleSession()`, `PlayerViewModel(session:)` over it, and `AcknowledgementsViewModel`.
- **`apps/ios/Sources/iStationApp.swift`** — the player in a navigation stack, with a toolbar button for the acknowledgements sheet; builds `PlayerViewModel(session: ConsoleSession())` and `AcknowledgementsViewModel`.

## Recipes

### Adding a module

1. Decide its layer (the lowest one that can hold it) and its one-phrase concern.
2. Create `lib/src/darwin/source/<layer>/<module>/` and `lib/src/darwin/tests/<layer>/<module>/`, each with at least one Swift file.
3. Add its row to `modules` in `Package.swift`: `Module(.<layer>, "<Name>", uses: [<targets>], testSupport: [<support targets>], derivedFrom: .projectPSX),` — on one line, `derivedFrom:` only for a ported module; its target is `<Layer><Name>`. If the apps use it, add the target to a product. Every file opens with its SPDX header (below).
4. Add its name to its layer card's **Modules** line and a row to [ADR 0002](../../adrs/darwin/module-map.md)'s table (`| <layer> | \`<module>\` | <uses> |`), and a `<TestableReference>` for its `<Layer><Name>Tests` target to `lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/macOS Personal.xcscheme` (copy a neighbour's block, change the three names).
5. Add it to the Codebase Map in CLAUDE.md and a section above.
6. Run `swift test` — the layering and layer-context checks must pass.

### Adding a place (a Presentation feature module)

1. Create `source/presentation/<place>/Views/` and `ViewModels/`, and `tests/presentation/<place>/`; add its `Module(.presentation, …)` row and its target to the `EmuKit` product.
2. Write the view-model first: `@MainActor @Observable`, named states, intents named for what the person does; test it headlessly.
3. Write the views bound to it, every visual from `styles`, each with a named `#Preview` per visible state inside `#if DEBUG`, over fakes in `Previews/`.
4. Build its view-model in each app's `iStationApp.swift` and mount its view.
5. Add it to the Presentation card, ADR 0002's table, the `macOS Personal` scheme's tests and the Codebase Map, and give it its own shared scheme, `iStation.xcodeproj/xcshareddata/xcschemes/<Target>.xcscheme`, building it and testing its bundle (ADR 0017). Run `swift test`.

### Headers, provenance and the acknowledgements list

Every Swift file under `source/`, `tests/` and `apps/` (`Package.swift` excepted: its first line is the tools version) opens with

```swift
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors
```

A file ported from a reference sits in a module whose row says `derivedFrom: .projectPSX` (or `.play`), carries that reference's licence (`MIT` or `BSD-2-Clause`), keeps the reference's copyright line as a `SPDX-FileCopyrightText` line beside iStation's, and names its source: `// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés`. A component whose notice an app carries gets an entry in `lib/src/darwin/apps/Acknowledgements.json` (its name, SPDX licence, source URL, the apps that carry it, its notice verbatim); a new licence also gets its text in `LICENSES/<id>.txt`. `ArchitectureTests` fails on any one missing.

### Adding a view

In its module's `Views/`, one top-level view per file, bound to that module's view-model, visuals from `styles`, with a named `#Preview` per visible state in the same file, inside `#if DEBUG`.

### Adding a debug view or a tool

A debug view goes in its module's `Debug/` and opens with `#if PERSONAL_BUILD`; an import of TraceKit (`DataTracing`), and every name of the core's personal-only API (`PS1DebugSnapshot`, `PS1TracingConsole`, `debugSnapshot`), sits inside `#if PERSONAL_BUILD`. `ArchitectureTests` (`toolsArePersonalOnly`) fails on any of them outside the guard.

### Adding a file Xcode's navigator should show

`lib/src/darwin/iStation.xcodeproj` shows the whole repository, not only the apps: the README and CLAUDE.md, `lib/documentation/`, the package, the apps' groups, `lib/src/darwin/tools/`, `lib/scripts/`, `lib/release/`, `.github/`, `.claude/`, the licences and `.gitignore`. Most folders are synchronized (blue in the navigator), so a new file in them appears by itself: `lib/documentation/`, `lib/scripts/`, `lib/release/`, `.github/`, `.claude/skills/`, `LICENSES/`, `lib/src/darwin/tools/gate/`, and the apps' and each tool's source folders (`Sources/`, `host/`). `.claude/` itself lists `settings.json` by hand around its synchronized `skills/`, because Superpowers' worktrees under `.claude/worktrees/` are whole checkouts. Each tool's top level is listed file by file instead, because every tool that builds does so into a hidden `.build/` and a synchronized folder shows hidden folders too — SwanStation's clone and its GPL source among them, which no one opens. So a new file at a tool's top level is added to that tool's group under `tools` by hand (File ▸ Add Files to "iStation", no target), and a tool folder is never added whole; a new top-level folder in the repository gets its own synchronized group.

### Adding or promoting a shared component

A component a second module wants moves to `source/presentation/styles/Components/` (never copied): make its inputs plain values and callbacks (no feature view-model), move its previews with it, update both users, delete the original. A component the design already draws in two or more places starts there; a plain value it shows sits in `styles/Models/`, importing no UI framework.

### Adding a token

A color, size, font, space, radius or duration starts in [the design](../../design/darwin/README.md), never in `styles`:

1. Add it to the design's `json/tokens.json`, named for its role — a color with its dark, light and contrast values, and a `contrastPairs` entry for each new text pair — with its line in the `swiftui` map naming its `styles` member.
2. From `lib/documentation/design/darwin/`, run `node tools/sync.mjs`, then the design's checks (`node tools/check.mjs`, and `--render` after a markup change), and publish the changed files to the canvas by [the design's sync rule](../../design/darwin/CLAUDE.md#the-sync-rule).
3. Add its member to `Palette`, `Symbols`, `Metrics`, `Typography` or `Motion`, named for its role, with the value `tokens.json` gives it (a color as a dynamic provider of its three values), and replace the literal that prompted it.
4. Run `swift test`: the tokens test in `tests/presentation/styles/` fails while `styles` and `tokens.json` differ, and `ArchitectureTests` rejects literal colors, sizes and paddings in feature views.

An icon takes the same path through the design's `html/main.html` (its `ICON` set) instead of `tokens.json`, then its SF Symbol in `Symbols`.

### Changing an entitlement

Edit the routine's file in `apps/<platform>/`. An App Store file never carries `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow` (either spelling); `ArchitectureTests` fails on one, and on an app without both routines' files.

### Adding a persisted format

Settings, memory cards and save states: a new field decodes with a default; a save state carries its version and an older one is refused with a message; each released shape gets a recorded fixture its tests read, never edited ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).

### Adding a disc format

A new Data module per format (e.g. `chd`); its fixtures are built in memory in `SupportDiscFixtures` — never a real image.

### Changing the pipeline

Each application has its own pipeline (`darwin.yml` for the Apple apps) beside the repository's (`ci.yml`), and every job builds through `lib/scripts/cicd.sh` — never a command of its own. What a pipeline is built from is declared once, in `lib/scripts/changed.sh`; a new application adds its entry there and its own workflow. A required job never gets a job-level `if:` — it would report skipped and never pass — so its steps are skipped instead (as `build darwin`'s are when nothing changed). After adding, removing or renaming a job: once the pull request's run passes, `lib/scripts/required-checks.py --pr <N>` proposes the required checks, and `--apply` sets them — it changes the repository's settings, so it is the user's to run.

### Proving an architecture rule

Plant the violation (an import, a directory, a row, an entitlement), run `swift test --filter ArchitectureTests`, confirm the failure names the rule in brackets and the file, then remove the plant. A rule SwiftPM itself refuses to load (a cycle, `styles` using a sibling) is planted in a copy of `Package.swift` and checked with `ISTATION_ARCHITECTURE_MANIFEST=<copy> swift test --filter ArchitectureTests`: the checks parse the copy while the build uses the real manifest. An import that would not compile is planted inside `#if false`, which the compiler skips and the check still reads.
