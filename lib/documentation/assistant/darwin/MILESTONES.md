# iStation — Milestones

The detailed record of finished work: what shipped, how it was built, the trade-offs taken and how it was verified. Pending work lives in [`backlog/`](../../backlog/darwin/README.md); this file holds finished work only.

## Milestone A — The construction

**Goal.** Make iStation buildable over many sessions without the chat as memory: the user's Code Scaffold (2026-10-26) carved into a four-layer architecture with mechanically enforced dependencies, compiling and green; a network of `CLAUDE.md` files; this docs home; and the project-local lifecycle skills. It also delivers the first two lines of the v0.0.1 roadmap: the scaffold compiles, and its tests are green.

**Built** (construction, 2026-10-31):

- **The package** (`src/istation/Package.swift`, swift-tools-version 6.0, Swift 6 language mode, macOS 14): the `modules` table — the layer law's one declaration ([ADR 0002](../../adrs/darwin/module-map.md)) — generating 21 library targets and 21 Swift Testing targets; 3 test-support targets (`SupportSandbox`, `SupportDiscFixtures`, `SupportLibraryFakes`); the `iStation` executable (`source/main/iStationApp.swift`); and `ArchitectureTests`.
- **The carve** of the scaffold's two targets (19 files) into 21 modules: Infrastructure `bytes`, `locations`, `bundles`, `process`; Data `catalog`, `iso9660`, `systemcnf`, `paramsfo`, `playlists`, `emulators`, `store`; Business `identification`, `scanning`, `discovery`, `launching`, `library`; Presentation `styles`, `shell`, `library`, `settings`, `app`. The scaffold's logic is unchanged except where the layers required a seam:
  - `CommandBuilder` → `LaunchContract.arguments(for:booting:options:)` (Data) + `GameLauncher` (Business: executable, process, `LaunchError`); `Platform.emulator` → `EmulatorChoice` (Business).
  - `EmulatorLocator` → `AppBundles` (Infrastructure) + `EmulatorDiscovery` (Business); the `NSWorkspace` bundle-ID lookup → Launch Services (`LaunchServicesLookup`), keeping AppKit out of the lower layers.
  - `GameLauncher.launch` → `ProcessRunner` behind `ProcessRunning` (Infrastructure), the one place a process is started.
  - `LibraryStore.merge` → `PlayHistory.merge` (Business); `LibraryStore` takes its file URL; `AppSettings.rpcs3GameFolder` became optional (nil = RPCS3's default), so no default reaches the real home; `ParamSFO` got its own error type.
  - The scanner's per-file probe → `DiscIdentifier.identify(file:hint:)` (Business `identification`), with the game-file extension sets beside it.
  - `LibraryModel` → Business `Library` (`@MainActor @Observable`, its services injected as protocols) plus one view-model per place: `ShellViewModel`, `LibraryGridViewModel`, `SettingsViewModel`, and `AppViewModel` as the composition root. `NSOpenPanel` → SwiftUI `.fileImporter`; `NSApp.activate(ignoringOtherApps:)` → `NSApplication.activate()` in `MainWindow`.
  - Every color, symbol, size and font moved to `styles` (`Palette`, `Symbols`, `Metrics`, `Typography`); `GameTile` takes a `GameTileModel`.
  - Every view has named `#Preview`s per visible state over in-module fakes ("Empty library", "Library", "Scanning", "Error", "Playing", "Nothing set up", "Set up", "First launch").
- **The tests**: the scaffold's 12 XCTest cases, ported to Swift Testing, split one directory per module and extended to 87 module tests, plus a `library.json` recorded from the real encoder at v0.0.1 (`RecordedLibraryFileTests`).
- **The checks** (`tests/architecture/`): `LayeringTests` (14 rules), `LayerContextTests` (5), `ProjectRulesTests` (4).
- **The scripts**: `src/istation/scripts/build-app.sh` (the scaffold's, at version 0.0.1); `scripts/validate_docs.py` (the docs validator); `.github/workflows/ci.yml` (the strict build, `swift test` and the validator on `macos-15`; built to run on every push and pull request, narrowed the same day to pull requests and merges into `stable` — the user's call, 2026-10-31).
- **The docs**: the root `CLAUDE.md` and `README.md`; the [router](../../CLAUDE.md); this home (CLAUDE, SPEC, ROADMAP, MILESTONES, DEVELOPER, the backlog with 1a, M1 and M2, ADRs 0001–0008, two reference contracts); a card at each of the eight layer roots in `source/` and `tests/`.
- **The skills** (`.claude/skills/`): the core set — `istation-backlog-investigate-spike`, `-create-spike`, `-create-item`, `-investigate-bug`, `-execute-item`, `-execute-call-resolution`, `istation-maintenance-update-documents` — and the optional set — `istation-backlog-execute-group`, `-swap-item`, `-swap-version`, `istation-maintenance-summarize-pull-request`, `-summarize-release`, `-update-release`.

**Trade-offs.**

- 21 modules for about 1,700 lines of scaffold, over two targets: more targets and directories, accepted because every edge is now a declared, checked fact ([ADR 0003](../../adrs/darwin/granular-modules.md)).
- The module map lives in `Package.swift` as one-line rows that a test parses, rather than in a separate map file: the declaration *is* the build and cannot drift from it. The cost: the rows must keep their one-line shape.
- The checks are a Swift test target, not a separate script, so a routine `swift test` runs them. SwiftPM's `--explicit-target-dependency-import-check=error` catches only imports of modules a target does not depend on at all (measured: a dependency's dependency passes), so the test's own import scan is the line that requires direct declaration.
- Preview fakes are copied into each module (`shell`, `library`, `settings`), per [ADR 0006](../../adrs/darwin/presentation-previews.md); preview games are real-shaped (the disc fixtures' titles and serials), not yet recorded from a real library.
- `.fileImporter` over `NSOpenPanel` keeps view-models AppKit-free, but loses the emulator chooser's /Applications start folder (M2).

**Verified** (2026-10-31, macOS 27, Xcode 27.1, Swift 6.4):

- `swift build --explicit-target-dependency-import-check=error` — clean, no warnings in Swift 6 language mode.
- `swift test` — 110 tests in 22 test targets, all passing (87 module tests, 23 architecture checks).
- **Every architecture rule was seen to fail on a planted violation, then the plant removed: 44 plants, 44 caught**, each failure naming its rule in brackets and the offending file — empty map and empty layer; unknown source directory; unmapped module; missing module and the hole it leaves in the mirror; a Presentation module without `Views/`/`ViewModels/`; upward, unknown, self and unused edges; a cycle; an undeclared (transitive) import; an upward import; importing the entry point; importing test code; SwiftUI below Presentation; SwiftUI in a view-model and AppKit in `Models/`; an unadmitted, an empty, and a root-level file in a Presentation module; `styles` using a sibling; a view importing Business; a literal padding in a component; a view without a preview; `#Preview` outside `#if DEBUG`; a `Previews/` file without the guard; upward and undeclared test imports; upward and unknown test support; an upward support edge; an undeclared support import; an unmapped support directory; orphan tests; card drift; a missing test card; ADR 0002 drift; ADR 0001 out of order; a `Process()` outside `InfrastructureProcess`; an external package; a `.bin` file in the repository; a real-home lookup outside `Locations`; `Locations.user()` in a test. The rules SwiftPM refuses to load (a cycle, `styles` using a sibling) were planted in a copy of the manifest via `ISTATION_ARCHITECTURE_MANIFEST`; SwiftPM itself refused a real cycle ("cyclic dependency declaration found").
- `./scripts/build-app.sh` — builds `build/iStation.app`, version 0.0.1, ad-hoc signed.
- **Smoke launch**: the app ran for six seconds over a sandbox home (`CFFIXED_USER_HOME`, which redirects both `homeDirectoryForCurrentUser` and Application Support), stayed up, found DuckStation, PCSX2 and RPCS3 in /Applications, and wrote its `library.json` only into the sandbox. No game was launched; that is the gate (1a).
- `python3 scripts/validate_docs.py documentation` — clean.

**Decisions consumed.**

- 2026-10-31: construct the project with the four-layer scheme, carving the scaffold into the modules now, rather than leaving the port as an item (the user's call).
- 2026-10-31: one version per roadmap phase (the user's call); releases on a `v<x.y.z>` branch, merged into `stable` and tagged (the user's call).
- 2026-10-31: a GitHub Actions workflow on a macOS runner (the user's call); the core and optional skill sets (the user's call).
- 2026-10-31: Swift 6 language mode; Swift Testing over XCTest; the skill prefix `istation`; lowercase module directories with `<Layer><Name>` targets; the module carve itself (the defaults, taken at construction — each veto-able).
- 2026-10-26: everything in [SPEC.md](SPEC.md)'s foundational choices (the user's design).

## Milestone B — Opening in Xcode

**Goal.** Open iStation in Xcode from the root of the repository, without hunting for `src/istation/Package.swift` (the user's request, 2026-10-31).

**Built** (2026-10-31):

- `iStation.xcodeproj` at the repository root: a project with **no targets of its own** whose navigator holds the package at `src/istation`, which Xcode resolves as a local package; and one shared scheme, `iStation` (`xcshareddata/xcschemes/iStation.xcscheme`), that builds and runs the package's `iStation` executable (⌘R) and tests all 22 test targets, `ArchitectureTests` included (⌘U).
- `ArchitectureTests/LayerContextTests.swift` gained `theXcodeSchemeTestsEveryTarget`: the scheme's test list must equal the module map's test targets plus `ArchitectureTests`, so a new module cannot silently drop out of ⌘U.
- The docs that say how to open the project or add a module: the root README, CLAUDE.md (Stack & environment, the checklist), DEVELOPER.md (tree, commands, recipes), the four source layer cards, ROADMAP's v1.0.0 decision note, and the execute-item and update-documents skills.

**Trade-offs.**

- A thin opener, not an Xcode app target: the package stays the one build definition, `swift test` and CI are unchanged, and the v1.0.0 question — an Xcode app target for the icon, signing and notarization — stays open.
- With a shared scheme present, Xcode no longer auto-creates a scheme per test target; one module's tests run from the Test navigator, or with `swift test --filter`.
- The scheme names each test target by hand: a new module adds one `<TestableReference>`, and the check fails until it does.
- ⌘R runs the unbundled executable over the real home folder, exactly as `swift run iStation` does.

**Verified** (2026-10-31, Xcode 27.1):

- `xcodebuild -list -project iStation.xcodeproj` resolves the package and lists the one scheme, `iStation`.
- `xcodebuild test -project iStation.xcodeproj -scheme iStation -destination 'platform=macOS'` — TEST SUCCEEDED, 111 tests in 22 test targets; `swift test` — the same 111, green.
- The new check failed on a planted scheme with a test target removed and on one with an unknown target added (2 plants, 2 caught), and passed once restored.
- Building through Xcode left nothing untracked but the project itself (Xcode's `src/istation/.swiftpm/` is git-ignored).

**Decisions consumed.**

- 2026-10-31: an `.xcodeproj` at the repository root for opening in Xcode (the user's call); a thin project over the package rather than an app target, so the v1.0.0 Xcode-project decision stays the user's (the default, taken).

## Milestone C — The re-vision

**Goal.** Re-envision iStation (the user's call, 2026-11-07, by the brief "Port PS1 and PS2 emulators to Swift"): from a launcher in front of the user's DuckStation, PCSX2 and RPCS3 to native Swift emulators ported from open-source references — PS1 from SwanStation, then PS2 from PCSX2 — with the library app as their frontend. SPEC listed "emulating any hardware" as a non-goal and ADR 0008 forbade it, so the direction is written down before any emulator code.

**Built** (2026-11-07; docs only, plus comments that cited ADR 0008):

- [SPEC.md](SPEC.md) rewritten with dated notes: the one-liner, background, foundational choices (Swift ports of open references; Apple platforms with iOS for PS1 only; GPLv3 outside the App Store; the licence boundary), the game view, consoles and references, porting, playing, distribution (PS3 later as a separate executable), non-goals, principles and success criteria.
- Three records: [ADR 0010](../../adrs/darwin/cores-are-ports-of-open-references.md) (the cores are ports of open references; installed emulators cover the rest; no Sony files; supersedes [ADR 0008](../../adrs/darwin/emulators-are-separate-programs.md), whose status line now says so), [ADR 0011](../../adrs/darwin/each-module-carries-its-licence.md) (each module carries its licence) and [ADR 0012](../../adrs/darwin/cores-shape-and-hot-paths.md) (a CPU module and a console module behind one narrow interface; concrete types in hot paths).
- [CLAUDE.md](CLAUDE.md): what this is, stack and licences, a section on the cores, the ported-code invariant in place of the emulators-are-separate one, open fixtures in the no-Sony-files invariant, versioning, the checklist and release. [ROADMAP.md](ROADMAP.md) re-planned (v0.0.1 the R3000A boots OpenBIOS … v2.x PS2).
- The backlog: 1a retired and deleted; Architecture A1 and v0.0.1's track 2 (2a–2e) written from the spike.
- The root README and CLAUDE.md, the router, this home's README, the Business and Infrastructure cards, the launch contract's introduction, DEVELOPER's test table, five skills that named ADR 0008 or the launcher-only non-goals, and the comments citing ADR 0008 in `GameLauncher.swift`, `ProcessRunner.swift`, `ProjectRulesTests.swift` and `Package.swift`.

**The spike behind it** (measured 2026-11-07 in a scratch folder; nothing vendored).

*Redacted 2026-11-07 under [ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md), when the App Store brief made GPL emulators' source off limits: what this spike learned about GPL emulators' internals is removed; licence and provenance facts, the build, and iStation's own measurements remain.*

- **SwanStation's provenance is clean.** 6,201 commits: DuckStation's history up to its author's last commit, 2022-01-11, then libretro's own work; no commit since 2023 mentions taking code from DuckStation. `LICENSE` is GPLv3; its own sources carry no per-file headers. The 26 files that do: Dolphin's (GPLv2-or-later, only in the Vulkan and D3D12 renderers), PGXP (GPLv2-or-later), MIT. Its `dep/` libraries: libchdr, vixl, xbyak, xxhash (BSD), OpenBIOS, libretro-common, glad (MIT), stb (public domain), vulkan-loader (Apache-2.0) — all GPLv3-compatible.
- **OpenBIOS's licence file**, as bundled in SwanStation, reads MIT.
- **It builds on Apple Silicon**: CMake and Ninja, arm64, Debug (9.2 MB `swanstation_libretro.dylib`) and RelWithDebInfo (5.5 MB), 165 steps each, 53 warnings, no errors.
- **What Swift's hot path costs** (a toy MIPS loop, 300 million instructions, optimized, M3 Max): bus in the same module 697–808 M instructions/s; in another module 704–816 M; CPU generic over its bus with `@inlinable` 705 M; the same without `@inlinable` ~500 M; bus behind a protocol type 496–558 M.
- **Revula** (status: 121 tools, 14 external backends): `revula_parse_binary` fails on Mach-O (its LIEF has no `Section.address`; the field is `virtual_address`); `revula_symbols` works but returns 57,302 symbols without sizes, a page at a time. Tracing every instruction through tool calls is far too slow for a BIOS boot. RetroArch is not installed.
- **ps1-tests** (MIT): its `cpu/` folder holds 4 tests — `access-time`, `code-in-io`, `cop`, `io-access-bitwidth` — about timing and I/O, not instruction semantics; its programs ship only in a 2021 release zip (6.6 MB) and leave the stack pointer at 0.
- **PCSX2**: 27 third-party folders. ps2autotests is ISC.

**1a, retired.** Its first run, on the user's Mac (2026-11-07): all three installed emulators were found automatically; the scan of the user's folders found PS1 58 games (48 with a serial), PS2 57 (55 with a serial) and PS3 19 disc folders (`<name>.ps3/PS3_GAME/`). iStation started DuckStation with a PS1 game (`SCUS-94423`, `.cue`), which stopped at DuckStation's own BIOS prompt: the BIOS folders in DuckStation's and PCSX2's settings no longer exist, and RPCS3 has no PS3 firmware. That session still counted about two minutes of play time — iStation counts the time the emulator was open. Of the 10 PS1 games without a serial: 3 `.cue` sheets name a missing `.bin`, 4 raw Mode 2 discs have a SYSTEM.CNF entry that points outside the data track, 1 `.cue`'s first file is not ISO 9660, 1 `.bin` is empty, 1 was not examined. Installed versions: DuckStation `0.1-10193-g86bf55162` (universal), PCSX2 `v2.4.0` (x86_64, under Rosetta), RPCS3 (no version in its `Info.plist`; arm64). Earlier evidence (2026-10-31): every flag iStation passes is in the installed binaries' help text. The two launcher fixes it points to are in ROADMAP → Ideas, not queued.

**Trade-offs.**

- Docs before code: the backlog holds the first milestone, specced, and nothing is built yet.
- Retiring 1a leaves the launcher verified by its tests and one partial run; it stays the way to play PS2 and PS3, and PS1 until v0.2.0.
- The licence boundary is a rule before it is a check: A1 gates the first ported module (2c), so no GPL-3.0 code lands unchecked.
- The PS1 console starts as one module; devices are carved out only behind the trace harness.

**Verified** (2026-11-07, macOS 27, Xcode 27.1):

- `python3 scripts/validate_docs.py documentation` — ALL CLEAN: 8 index rows; 306 relative links across 54 files.
- `swift build --explicit-target-dependency-import-check=error` — clean; `swift test` — 111 tests in 22 test targets, all passing (only comments changed in code).
- Every live reference to ADR 0008 now points at ADR 0010; the ones left are history (Milestone A) and the ADR index's superseded row.

**Decisions consumed.**

- 2026-11-07: re-envision iStation as Swift ports of open-source references, PS1 first from SwanStation, then PS2 from PCSX2, reusing the R3000A for the IOP; PS3 out of scope, behind a narrow interface; outside the App Store; iOS for PS1 only (the user's brief).
- 2026-11-07: the library app stays as the frontend, launching installed emulators for consoles without a native core (the user's call, the recommendation taken).
- 2026-11-07: shared infrastructure under GPL-2.0-or-later (the user's call).
- 2026-11-07: v0.0.1's bar is OpenBIOS booting to its shell with a trace identical to SwanStation's, plus ps1-tests' `cop` and `code-in-io`; `access-time` and `io-access-bitwidth` move to v0.1.0 (the user's call).
- 2026-11-07: retire the v0.0.1 launcher gate, 1a (the user's call).
- 2026-11-07: cores in Business, licence-tagged; concrete types in hot paths; the reference traced by a local patch and a headless frontend under `tools/`; open fixtures beside their licences through an allow-list (the defaults, taken).

## Milestone D — The App Store re-vision

**Goal.** Make the docs follow the user's brief "PS1 and PS2 emulators in Swift (App Store-eligible)" (2026-11-07), which replaces Milestone C's plan the same day: two Apple apps — macOS (PS1 and PS2) and iOS (PS1) — eligible for the App Stores, with shipped code ported only from permissively licensed references and GPL emulators used only as black-box oracles; each app with an App Store routine and a personal routine.

**Built** (2026-11-07; docs only, plus comments that cited the superseded records):

- [SPEC.md](SPEC.md) rewritten: two apps, permissive references (ProjectPSX for PS1, Play! for PS2), GPL emulators as oracles, the two build routines, Apple constraints (one `MAP_JIT` region, AArch64 only, no PS2 on iOS), App Store distribution under Guideline 4.7, non-goals (no GPL emulator's source read; no OpenBIOS; no launching other emulators).
- Four records: [ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md) (shipped code only from permissive sources; GPL emulators black boxes; supersedes 0010), [ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md) (iStation's own code MIT; notices kept; supersedes 0011), [ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) (core shape and hot paths; supersedes 0012) and [ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md) (two build routines; the library app retired; supersedes 0007 for its file).
- [CLAUDE.md](CLAUDE.md): what this is, stack and licences, the cores, the shipped-code invariant, the no-Sony-files invariant (no OpenBIOS), the retiring library-file invariant, the codebase map's note, versioning, the checklist and release. [ROADMAP.md](ROADMAP.md) re-planned.
- The backlog: A1, track 2 (2a–2e), M1 and M2 cancelled and deleted; Architecture A2 and v0.0.1's track 3 (3a–3g) written.
- The root README and CLAUDE.md, the router, this home's README, the Business and Infrastructure cards, DEVELOPER's test table, five skills, the two reference contracts (marked retiring; the launch contract's source-file column removed), and the comments citing ADR 0010 in `GameLauncher.swift`, `ProcessRunner.swift`, `ProjectRulesTests.swift` and `Package.swift`.
- Milestone C's spike and ADRs 0010 and 0012 redacted: what they said about GPL emulators' internals is removed (ADR 0013).

**Evidence** (checked 2026-11-07 on GitHub; licence files and repository layout only):

- **ProjectPSX** — MIT, last pushed 2026-07-13: a .NET 10 core library (`ProjectPSX/`, about 366 KB of C#: `Core/BUS.cs`, `CPU.cs`, `GTE.cs`, `ProjectPSX.cs` and `Devices/` for CD-ROM, DMA, EXP2, GPU, input, interrupt controller, MDEC, SPU and timers), a cross-platform OpenTK frontend and a Windows-only WinForms one. Its README: a valid BIOS is required (SCPH1001 is the development default); CD-ROM timing and resumable DMA transfers are listed as not implemented. The .NET SDK is not installed on the user's Mac.
- **Play!, Play--Framework, Play--CodeGen, Nuanceur** — each `License.txt` is a BSD licence © Jean-Philip Desjardins with no "neither the name" clause (the two-clause form); GitHub reports `NOASSERTION` because it doesn't detect the file.
- **Play-Dependencies** — no licence of its own; its folders: bzip2, glew, lzmasdk, nlohmann_json, sqlite, tdemu, iCade-iOS, `unrarsrc-5.2.5` (out, by the brief), `d3dcompiler_winxp` and the Windows build scripts (Windows-only, out).
- **OpenBIOS** — the brief lists it as GPL; the licence file bundled with it in SwanStation (seen 2026-11-07) reads MIT. The brief's rule stands either way: OpenBIOS is not used.
- **This session read GPL emulator source** before the brief: parts of DuckStation's, PCSX2's and RPCS3's command-line handling on 2026-10-31 (for the launcher's flags), and parts of SwanStation's and PCSX2's source on 2026-11-07 (for the plan of Milestone C). Under ADR 0013 §3 it wrote docs only, and the core is ported by sessions that haven't read them. Its scratch clones and builds of GPL emulators were deleted.

**Trade-offs.**

- Two re-visions in one day: Milestone C's documents lived for hours; their ids (A1, track 2) stay spent.
- Retiring the library app drops working, tested code (21 modules, 111 tests); item 3b decides whether the format readers carry over.
- A GPL oracle gives guest state from outside — per frame or per breakpoint — not every instruction; ProjectPSX's own traces fill that gap, and SwanStation decides.
- The PS1 gate needs a real BIOS (ProjectPSX does), so it is the user's run rather than a hermetic test; hermetic tests cover the CPU and console in code.

**Verified** (2026-11-07, macOS 27, Xcode 27.1):

- `python3 scripts/validate_docs.py documentation` — ALL CLEAN: 8 index rows; 339 relative links across 58 files.
- `swift build --explicit-target-dependency-import-check=error` — clean; `swift test` — 111 tests in 22 test targets, all passing (only comments changed in code).
- A sweep of the docs and skills for pointers into GPL emulators' source (file names, line numbers, function names) finds none outside this entry's account of what was redacted.

**Decisions consumed.**

- 2026-11-07: the App Store brief replaces Milestone C's plan: PS1 from ProjectPSX, PS2 from Play!; GPL emulators black-box oracles only; macOS (PS1, PS2) and iOS (PS1) apps eligible for the App Stores; two build routines (the user's brief).
- 2026-11-07: iStation's own code is MIT (the user's call).
- 2026-11-07: start the apps fresh; the library app and its launcher retire (the user's call).
- 2026-11-07: the PS1 milestone is the brief's — ps1-tests' CPU tests passing with a trace matching SwanStation's — replacing Milestone C's narrower bar (the user's brief).
- 2026-11-07: the brief's packages become products of the one layered package; the apps are targets in `iStation.xcodeproj`; OpenBIOS is not used, as a binary either (the defaults, taken).


## Milestone E — JIT under the App Store routine

**Goal.** Know, before any PS2 work, whether a macOS app built the App Store way can generate and run code: App Sandbox on, hardened runtime, `com.apple.security.cs.allow-jit`, never `allow-unsigned-executable-memory` or `get-task-allow` (v0.0.1 item 3a, the brief's first task).

**Built** (3a, 2026-11-07): `tools/jit-probe/` — a one-file SwiftUI macOS app (`Sources/JITProbe.swift`, iStation's own code, MIT) with a `--probe` mode; `Sources/OSCacheControl.h`, a one-line bridging header, because `sys_icache_invalidate` is not exported to Swift by `Darwin`; `Info.plist` (placeholder identifier `local.istation.jit-probe`); `AppStore.entitlements` (sandbox + `allow-jit`) and `NoJIT.entitlements` (the control); `build.sh` (swiftc, bundle, `codesign --options runtime` ad-hoc or with a named identity, into git-ignored `.build/`); `README.md` with the results table and the user's two runs. The probe maps a `MAP_JIT` region, toggles `pthread_jit_write_protect_np`, writes `mov w0, #42; ret`, invalidates the instruction cache, calls it and expects 42, then tries a second region.

**Trade-offs.** A swiftc-built bundle rather than an Xcode project keeps the probe one file and one script; TestFlight (run 3) needs an Xcode target, which its README describes. A control build without `allow-jit` was added to show the entitlement, not the build, is what grants the region.

**Verified** (2026-11-07, macOS 27.0.1, build 26A434, M3 Max):

- Run (0), the control — sandboxed, hardened runtime, no `allow-jit`: both `mmap(MAP_JIT)` calls refused with `EINVAL`.
- **Run (1) — sandboxed (container `local.istation.jit-probe`), hardened runtime, `allow-jit`, ad-hoc signed: region 1 mapped, the code ran and returned 42: PASS**, from a shell and through Launch Services alike.
- A second `MAP_JIT` region was **granted** in run (1) and ran too — Apple's porting guide describes one region per process; under ad-hoc signing it is not enforced. Whether real signing enforces it is open until runs (2) and (3).
- Runs (2), signed with the user's Apple Development identity, and (3), TestFlight, are prepared in `tools/jit-probe/README.md` and are the user's. Run (3) needs an Apple Distribution certificate this Mac doesn't have yet.

**Decisions consumed.**

- 2026-11-07: verify JIT under the App Store routine first (the user's brief); three runs, (2) and (3) the user's; a failure raises the PS2 decision (the defaults, confirmed by the user).


## Milestone F — The skeleton and both build routines

**Goal.** The brief's second task: the package's new shape and both build routines, producing empty macOS and iOS apps — and the library app's retirement (v0.0.1 item 3b; the user's call to start fresh, 2026-11-07).

**Built** (3b, 2026-11-07):

- **Retired**: the library app's 17 other modules (`locations`, `bundles`, `process`; `catalog`, `paramsfo`, `emulators`, `store`; `identification`, `scanning`, `discovery`, `launching`, `library`; the old `styles`, `shell`, `library`, `settings`, `app`), their tests and `SupportLibraryFakes`, the entry point `source/main/`, `scripts/build-app.sh`, and the two contracts (`reference/emulator-launch-contract.md`, `reference/library-file.md`). Kept, by the default confirmed 2026-11-07: `bytes`, `iso9660`, `playlists`, `systemcnf` with their tests, `SupportSandbox` and `SupportDiscFixtures` (`makeSFO` and `Sandbox.makeApp`, now unused, removed). `SystemCNF` reports its own `Console` (`.ps1`, `.ps2`) instead of the retired `Platform`.
- **The package** (`src/istation/Package.swift`): platforms macOS 14 and iOS 17; the products `PS1Core` (`BusinessPS1`) and `EmuKit` (`PresentationStyles`, `PresentationPlayer`, `PresentationAcknowledgements`); `PERSONAL_BUILD` defined for every target in debug. New modules: `BusinessPS1` (`PS1Console`, a powered-off placeholder), `PresentationStyles` (palette, symbols, metrics, typography for the player), `PresentationPlayer` (`PlayerView`, `PlayerViewModel`, preview "Nothing loaded"), `PresentationAcknowledgements` (`Acknowledgement`, `AcknowledgementsViewModel`, `AcknowledgementsView`, preview "Empty"), each with its tests.
- **The apps** (`src/istation/apps/`): `iStation macOS` (the player window; "Acknowledgements…" in the app menu) and `iStation iOS` (the player in a navigation stack; an acknowledgements sheet), placeholder identifiers `local.istation.macos` and `local.istation.ios`. Each personal build titles itself "iStation — Personal build".
- **The routines**: `apps/Config/Version.xcconfig` (`MARKETING_VERSION = 0.0.1`), `Personal.xcconfig` (the Debug configuration: `DEBUG PERSONAL_BUILD`), `AppStore.xcconfig` (the Release configuration; `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`, because local signing otherwise injects `get-task-allow`); per app, `AppStore.entitlements` (macOS: App Sandbox, read-only user-selected files, `allow-jit`; iOS: none) and `Personal.entitlements` (`get-task-allow`; macOS also `allow-jit`); four shared schemes (`macOS Personal`, `macOS App Store`, `iOS Personal`, `iOS App Store`), the package's test targets in `macOS Personal`; `scripts/build-personal.sh` and `scripts/archive-appstore.sh` (`ISTATION_TEAM_ID` signs and exports — the user's).
- **`iStation.xcodeproj`**: two app targets over the package, which sits in the project as a folder reference — a package reference alone exposes only its products, and Xcode then finds no test bundles (measured 2026-11-07).
- **The checks** (`ArchitectureTests`): `toolsArePersonalOnly` (an import of a tool module — `DataTracing`, from 3c — outside `#if PERSONAL_BUILD`, or a file under a `Debug/` directory that doesn't open with it, in the package or the apps); `appStoreEntitlementsAreClean` (every `AppStore.entitlements` free of `allow-unsigned-executable-memory` and `get-task-allow` in either spelling; every app with both routines' files); the process rule widened to the whole package and the apps (its `system(` pattern narrowed so `Font.system(size:)` isn't a match); the real-home rule now without an exception; the entry-point rules removed; the scheme check moved to `macOS Personal`; `Debug/` admitted in a Presentation module.
- **CI** (`.github/workflows/ci.yml`): also builds both apps' personal routine unsigned.
- **Docs**: the eight layer cards, ADR 0002's table, CLAUDE.md (what this is, build, the UI, the cores' rules, the invariants — the library-file invariant retired, the real-home one rewritten, the release-build one added — the Codebase Map, versioning, the checklist, release, CI), DEVELOPER.md (rewritten), the root README, the reference index, four skills, and the dead links in ADRs 0007, 0008 and 0010 turned to text.

**Trade-offs.** The routines are the standard Debug and Release configurations rather than custom ones, so the package's `PERSONAL_BUILD` can key off `.when(configuration: .debug)` and Swift packages build in their usual modes. The placeholder console and empty player are deliberate thin seams that 3e, 3f and v0.1.0 fill. The project file was generated once by a script outside the repository and is maintained in Xcode from here.

**Verified** (2026-11-07, Xcode 27.1, macOS 27.0.1):

- `swift build --explicit-target-dependency-import-check=error` — clean; `swift test` — 44 tests in 9 test runs, all passing (18 module tests, 26 architecture checks); `xcodebuild test -scheme "macOS Personal"` — the same 44, **TEST SUCCEEDED**.
- All four schemes build (macOS for `generic/platform=macOS`, iOS for the Simulator), signed and as CI builds them unsigned; `archive-appstore.sh macOS` and `iOS` each produce an archive; the macOS archive's entitlements are exactly App Sandbox, read-only user-selected files and `allow-jit`; the personal builds carry `get-task-allow` and the "Personal build" title, the App Store builds neither.
- The personal macOS app launched and stayed up.
- **The new rules were seen to fail on planted violations, then restored: 10 plants, 10 caught** — a `DataTracing` import under `#if false` in a core and under `#if !PERSONAL_BUILD` in an app; an unguarded `Debug/` view; `com.apple.security.get-task-allow` in the macOS App Store file and `get-task-allow` in the iOS one; `allow-unsigned-executable-memory`; a missing `Personal.entitlements`; scheme drift in `macOS Personal`; `Process()` in an app; `NSHomeDirectory()` in a test.

**Decisions consumed.**

- 2026-11-07: start the apps fresh; the library app retires (the user's call). Two routines per app, `PERSONAL_BUILD`, xcconfig and entitlements per routine, a scheme or script per routine (the user's brief). The packages are products of the one layered package; the apps are targets in `iStation.xcodeproj` (the re-vision's default).
- 2026-11-07: keep the four format readers; iOS 17; `PS2Core` with the PS2 work; placeholder bundle identifiers (the defaults, confirmed by the user).


## Milestone G — TraceKit

**Goal.** "The oracle decides": a ported subsystem is right when its guest-visible behaviour matches, and the first divergence is the bug. Three sources must write comparable traces — the Swift port, ProjectPSX with trace logging and SwanStation recorded from outside — so the format, a recorder, a reader and the diff come first (v0.0.1 item 3c).

**Built** (3c, 2026-11-07): `DataTracing` (Data layer, product `TraceKit`, personal builds only; iStation's own code, MIT) in `src/istation/source/data/tracing/` — `Checksum.swift` (`FNV1a64`; `RegisterChecksum` over the 32 general registers, HI, LO and COP0 SR, CAUSE, EPC), `InstructionRecord.swift` (24 bytes, and `FullStateRecord`, 160), `FrameRecord.swift` (32), `TraceFile.swift` (the 16-byte `ISTR` header, `TraceWriter` with a 1 MB buffer, the streaming `TraceReader`, `TraceError`), `TraceDiff.swift` (the first divergence with its differing fields by name; a cycles-off flag no gate uses — until 3d's gate, which uses it for ProjectPSX's instructions), `Checkpoints.swift` (an `ISCK` file of one FNV-1a checksum per window). Its contract, byte by byte: [reference/trace-formats.md](../../reference/darwin/trace-formats.md). Tests in `tests/data/tracing/`; the `macOS Personal` scheme tests them.

**Trade-offs.** FNV-1a 64 over little-endian bytes, chosen because ProjectPSX's C# patch and SwanStation's C frontend (3d) can write it identically in a few lines, not for strength. Tagged, fixed-size records keep the reader simple and let full-state records interleave with instruction records; the tag costs one byte in 25. The image and audio checksums are carried now and compared only once v0.1.0 and v0.2.0 fix their sample formats; RAM is the gate's measure. No app links `TraceKit` yet; a core will reach it only through a generic tracer that release builds specialize to nothing (3e).

**Verified** (2026-11-07, M3 Max, macOS 27.0.1):

- Both encodings pinned byte for byte against hand-written bytes; FNV-1a 64's published vectors (`""`, `"a"`, `"foobar"`) and two register checksums computed independently in Python; round trips across the buffer boundary (100,000 records); truncated, empty, foreign, newer-version and unknown-tag input each a named error; the first divergence by index and field, the end of a shorter trace, ignored cycles; checkpoint reduction (one changed record changes exactly its window) and its file round trip — 22 tests.
- **Throughput** (`ISTATION_BENCHMARK=1 swift test -c release --filter ThroughputTests`): 100 million instruction records, 2,500,000,016 bytes, **written in 3.96 s (25 M records/s) and read in 1.90 s (53 M records/s)**.
- `swift test` — 66 tests in 10 test runs, green; `xcodebuild test -scheme "macOS Personal"` — TEST SUCCEEDED; the strict build clean; `toolsArePersonalOnly` already guards `DataTracing` (Milestone F).

**Decisions consumed.**

- 2026-11-07: TraceKit is the trace format, recorder and diff, personal builds only (the user's brief); the records and the diff's fields as specified (the defaults, confirmed by the user).


## Milestone H — Provenance headers and notices

**Goal.** [ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md): iStation's own code is MIT; code ported from ProjectPSX keeps its MIT notice and code from Play! its BSD notices; every app shows every notice it carries — with a check, before the first ported module (Architecture item A2, which gated 3e).

**Built** (A2, 2026-11-07):

- **Licence texts**: the root `LICENSE` (MIT, © 2026 iStation contributors); `LICENSES/MIT.txt` and `LICENSES/BSD-2-Clause.txt` (the REUSE layout).
- **Headers**: every Swift file under `src/istation/source/`, `tests/` and `apps/` — 41 files when it landed — opens with `// SPDX-License-Identifier: MIT` and `// SPDX-FileCopyrightText: 2026 iStation contributors`.
- **The module map**: `Module` rows take `derivedFrom:` (`.none` by default, `.projectPSX`, `.play`) on their one line; `Repository.swift`'s parser reads it.
- **The acknowledgements list**: `src/istation/apps/Acknowledgements.json` — iStation, ProjectPSX (MIT, © 2019 Pedro Cortés, both apps), Play!, Play! Framework, Play! CodeGen and Nuanceur (BSD-2-Clause, © Jean-Philip Desjardins, macOS only), each with its notice as its repository holds it (read through GitHub's API, 2026-11-07: ProjectPSX at `f4dc13aea42d`, Play! at `1f27232772e4`, Play--Framework `3368a5a7d9cb`, Play--CodeGen `a5009f7dca06`, Nuanceur `d96578b5a18e`), its source URL and the apps that carry it. Both app targets bundle it; `Acknowledgement.list(from:for:)` and `bundled(for:)` read it; each app's acknowledgements screen lists its own entries.
- **The checks** (`ArchitectureTests/ProjectRulesTests.swift`): `everyFileHasItsHeader` (both header lines; the licence has its text in `LICENSES/`), `portedModulesNameTheirSources` (every file in a ported module carries `// Ported from <repository>/<path> — <its copyright line>` and its reference's licence), `everyLicenceIsAcknowledged` (every licence a header names, and every reference the map names, is in the list; no entry without a notice or an app). The `Previews/` rule now skips comment lines before `#if DEBUG`.

**Trade-offs.** The list is one JSON file the apps bundle as a resource, rather than a Swift constant, so a notice is its licence text verbatim and both apps and the checks read the same bytes. It names the Play! libraries now, before any of their code ships, so the PS2 work can't forget them; until then the macOS screen over-acknowledges, which no licence forbids. iStation is its own first entry, so its MIT notice travels in the apps too.

**Verified** (2026-11-07): `swift test` — 72 tests in 10 test runs, green; both apps build with `Acknowledgements.json` in their bundles. **The new rules were seen to fail on planted violations, then restored: 6 plants, 6 caught** — a file without its header; a header naming `Apache-2.0` (no text, no entry); a `.projectPSX` module whose file names no source; a `.play` module whose file is MIT; a ProjectPSX module with ProjectPSX missing from the list; an entry with no notice.

**Decisions consumed.**

- 2026-11-07: iStation's own code is MIT (the user's call); derived code keeps its reference's notice; nothing GPL ships (the user's brief).
- 2026-11-07: the three-line header, "iStation contributors" as the holder, the list as one JSON file, mixed files MIT with both copyright lines and Play!-derived files BSD-2-Clause (the defaults, confirmed by the user).

## Milestone I — The R3000A interpreter

**Goal.** The first ported code: the PS1's CPU as an interpreter, ported from ProjectPSX's `ProjectPSX/Core/CPU.cs` (MIT, pinned at `f4dc13aea42d`) — the only CPU path that works on iOS and the accuracy baseline for everything after — and generic over its bus, so the PS2's I/O processor can reuse it (v0.0.1 item 3e; [ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)).

**Built** (3e, 2026-11-07, by a session that has never read a GPL emulator's source):

- **`BusinessR3000A`** (Business layer, product `PS1Core`; `Module(.business, "R3000A", …, derivedFrom: .projectPSX)`), in `src/istation/source/business/r3000a/` — every file with ProjectPSX's notice and its provenance line:
  - `R3000A.swift`: `R3000A<Bus: R3000ABus, Cop2: Coprocessor2, Tracer: R3000ATracer>`, a final class. Its state is ProjectPSX's (`pc` and `nextPC`, the branch and delay-slot flags, HI/LO, the write-back and the two-stage load delay, COP0 with PRID 2). `step()` runs fetch, execute, memory access and write-back and returns the fetch's cycles; `handleInterrupts()` is called by the console between instructions, as ProjectPSX's run loop does; `raise` pushes SR's mode stack and records CAUSE, EPC, BD, BT and the jump destination.
  - `Instructions.swift`: ProjectPSX's main and SPECIAL opcode tables as two switches, with the COP0 moves and RFE, and the COP2 transfers.
  - `Bus.swift`: `R3000ABus` (fetch with its cycles; 8-, 16- and 32-bit loads and stores that `throw(BusError)`; `interruptPending`; and, since the review, `peek32`, memory's word with no load's cost and no device's side effects).
  - `Coprocessor2.swift`: `Coprocessor2`, and `NoCoprocessor2` for the IOP — and for the PS1 until v0.2.0's GTE.
  - `Tracer.swift`: `R3000ATracer`, `RetiredInstruction` (with a pointer to the registers, valid during the call), `NoTracer`.
  - `Exceptions.swift`: `ExceptionCode`, `COP0Register`.
- **`SupportR3000ATrace`** (`tests/support/r3000atrace/`): `TraceKitTracer` writes TraceKit's instruction records, plus a full-state record every `fullStateInterval`. It re-exports `DataTracing` through its declared edge, so a Business test reaches TraceKit without a direct import the layer check would refuse.
- **Tests** in `tests/business/r3000a/`:
  - `Harness.swift`: an in-memory `TestBus` (2 MB, bus errors beyond) and a small assembler.
  - One suite per family: `ArithmeticTests` (with `MultiplyDivideTests`), `LoadStoreTests`, `BranchTests`, `ExceptionTests`, `Coprocessor2Tests`, `TracingTests` and `BenchmarkTests`.
  - The `macOS Personal` scheme runs them.

**Where it departs from ProjectPSX** (psx-spx decides; each is a comment beside the code):

- Misaligned fetches, loads and stores always raise address errors, and ADD/ADDI/SUB always trap on overflow. ProjectPSX does both only when built with `CPU_EXCEPTIONS`.
- A fetch from nothing raises IBE and a load or store DBE; ProjectPSX has no bus errors.
- The exception vector follows SR's BEV. ProjectPSX's `SR & 0x400000 >> 22` parses as `SR & 1`, which is always 0 after the mode push, so it always vectors to RAM.
- COP2, LWC2 and SWC2 need SR's CU2, and with `NoCoprocessor2` they raise Coprocessor Unusable.
- A misaligned SWC2 raises the store's address error; ProjectPSX raises the load's.
- SWL and SWR are held back while the cache is isolated, like the other stores, and so are LWC2 and SWC2.

Added by the review (2026-11-07):

- **User mode.** With SR's KUc set, a fetch, load or store outside KUSEG is an address error, and without CU0 the COP0 moves and RFE raise Coprocessor Unusable. ProjectPSX has no user mode. Kernel mode's path is unchanged: a load or store tests one flag, as it tested isolation alone.
- **COP0's commands.** Only RFE (function 10h) runs; TLBR, TLBWI, TLBWR and TLBP are Reserved Instructions, and BC0F and BC0T raise Coprocessor Unusable. ProjectPSX runs every command as RFE.
- **COP0's registers.** MTC0 to the registers the PS1 lacks (0–2, 4, 10) or to garbage ones (16–31) changes nothing; TAR, BadVaddr, EPC and PRID are read-only; DCIC keeps only its bits 0xFF80F03F. MFC0 of 16–31 reads the last real register read. ProjectPSX writes every one — for 16–31 past the end of its 16-word array — and raises Reserved Instruction on reading 16–31.
- **The exception entry.** An interrupt taken just after a branch records the branch's destination in TAR (ProjectPSX writes `pc`), and nothing at the vector is in a delay slot: the branch flags are cleared.
- **SWL and SWR** merge their bytes into a peek of memory, not a load: no load's time, no device's read side effects, and a device gets one byte store per lane. ProjectPSX loads the whole word.

Decided by the hardware (2026-11-14, ps1-tests' `cop` and its `psx.log`, recorded on a real PS1, in 3g's runs with the user's BIOS images):

- **COP1 and COP3, and LWC0/1/3 and SWC0/1/3**, raise Coprocessor Unusable while SR's CUn bit is clear — LWC0 and SWC0 even in kernel mode, where MFC0 and MTC0 still work — and do nothing while it is set. ProjectPSX ran them all as NOPs, a quirk kept until a trace decided; psx-spx has LWC0 and SWC0 always raise it, which the hardware log contradicts with CU0 set. LWC1, SWC1 and LWC3 aren't tested and follow the others.
- **A COP0 command other than RFE and the four TLB commands** does nothing: `cop` runs one with rs 1Fh and function 0 on hardware without an exception, where the review had made every such command a Reserved Instruction.

**ProjectPSX's quirks kept until SwanStation's trace (3d) decides:**

- BLTZAL/BGEZAL write r31 directly rather than through write-back.
- Enabling interrupts by MTC0 with a software interrupt pending sets EPC to the instruction after the next one, which never runs.
- An interrupt waits while the next instruction is a COP2 one.
- LWL and LWR ignore cache isolation.

**Trade-offs.**

- **No runtime exclusivity checks.** Every stored `var` of the CPU is `@exclusivity(unchecked)`. Swift checks each access to a class's stored property at run time, even in optimized builds and wherever the inlined hot path lands, and on the spike's loop those checks held the interpreter to **18 M instructions/s**. Holding the state behind unsafe pointers instead also avoids the checks but measured 213 M; the attribute measured 238–267 M, with simpler code. ADR 0015 §4 now says so, and the card and the checklist carry the rule.
- **Real access widths.** Byte and halfword loads use the bus's 8- and 16-bit reads, where ProjectPSX reads 32 bits and truncates: the same result from RAM, and the right width for 3f's devices.
- **Peeking the next instruction.** The COP2 postponement looks at the next instruction through `bus.peek32`, which answers RAM, the BIOS and the scratchpad and nil for a device, as ProjectPSX reads RAM or BIOS directly — no cycles, no side effects. (Until the review it went through `bus.fetch`, which a timer's mode register or the SPU's end could answer.)
- **Cycles.** The count is the fetch's cycles only, as in ProjectPSX: the bus says what each region costs.

**Verified** (2026-11-07, M3 Max, macOS 27.0.1, Xcode 27.1):

- **The instruction tests**: every instruction family against psx-spx's semantics, 60 tests in 8 suites, green. They cover:
  - both delay slots (a delay-slot load to the same register wins; an ALU write in a load's delay slot wins over the load);
  - LWL/LWR/SWL/SWR at every byte offset, and the unaligned pairs;
  - every exception the document names, with EPC, BD, BT, BadVaddr and the vector;
  - interrupts (enabled, masked, after a branch, postponed before COP2, software);
  - RFE, the COP0 moves, cache isolation, COP2 routing;
  - the tracer through TraceKit's records.
- **Planted bugs, 3 of 3 caught, then restored**: the load-delay overwrite rule disabled; BEV ignored; the overflow check removed.
- **Instructions per second** (`ISTATION_BENCHMARK=1 swift test -c release --filter BenchmarkTests`): the spike's loop (`lw`, `addiu`, `sw`, `addiu`, `bne`, `nop`; 300 million instructions) runs through the full pipeline at **238–267 M instructions/s** across two runs. That is about a third of the spike's toy interpreter, which had no pipeline, flags or exceptions, and about seven times the PS1's 33.9 MHz. A tracer switched off by its type (its hook would sum every word) runs at the same rate as `NoTracer`: the hook folds away, so tracing off costs nothing measurable.
- **Provenance**: the checks pass for the new `.projectPSX` module (`portedModulesNameTheirSources`, `everyLicenceIsAcknowledged`).
- **The full suite**: `swift test` — 132 tests in 11 test runs, green (ArchitectureTests included); the strict build clean; the docs validator clean; `xcodebuild test -scheme "macOS Personal"` — TEST SUCCEEDED.
- **Trace against trace** (met 2026-11-07, with 3d's tools): `tools/istation-run/cpu-check.sh` runs one program built in code — 1,162 instructions over 159 addresses and 61 distinct operations (opcodes, SPECIAL functions, REGIMM branches and COP0 operations), psx-spx's division edge cases among them, then an endless loop — from the reset vector on ProjectPSX's traced build and on the Swift console, and the two instruction traces agree on all 18,833 instructions ProjectPSX's frame holds: every register after every instruction (a full-state record each) and every cycle count. The first run found one difference, ProjectPSX's: it treats the cache as isolated — its LB, LBU, LH, LHU, LW, SB, SH and SW ignored — until SR is first written, though its SR reads 0 (a C# field's `false` default). A BIOS writes SR at once, so the program does too.
- **After the review** (2026-11-07): an independent review of 3e and 3f — each finding checked by a skeptic against psx-spx and ProjectPSX — confirmed the defects above and fixed them, each with a test that fails without it; the worst was MTC0 to registers 16–31 writing past COP0's array. Now **76 tests in 8 suites**, green, and the R3000A and PS1 tests clean under AddressSanitizer. The benchmark re-measured **257–261 M instructions/s** (`NoTracer`, two runs; a summing tracer 235–246 M). The CPU check still agrees with ProjectPSX's trace, to the end of its 37,666 records.

**Decisions consumed.**

- 2026-11-07: PS1 from ProjectPSX; the IOP reuses this CPU (the user's brief). One CPU module generic over its bus, concrete types in the hot path (ADR 0015).
- 2026-11-07: where ProjectPSX and psx-spx disagree, psx-spx and SwanStation's recorded behaviour (3d) decide, and the difference is noted beside the code; no disassembler — TraceKit's diff prints raw instruction words (the defaults, confirmed by the user).

## Milestone J — The PS1 console

**Goal.** A PS1 around the R3000A, so a BIOS can boot (3g): the memory map, the interrupt controller, the timers, DMA, the GPU's timing, the TTY, and enough of the other devices to answer the BIOS, ported from ProjectPSX (`Core/BUS.cs`, `Core/ProjectPSX.cs`, `Devices/InterruptController.cs`, `Devices/TIMERS.cs`, `Devices/DMA/`, `Devices/Expansion/Exp2.cs` and the timing of `Devices/GPU/GPU.cs`, at `f4dc13aea42d`), with PS-EXE loading for test programs (v0.0.1 item 3f; [ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §3).

**Built** (3f, 2026-11-07, by a session that has never read a GPL emulator's source). `BusinessPS1` (`Module(.business, "PS1", uses: ["BusinessR3000A"], …, derivedFrom: .projectPSX)`), in `src/istation/source/business/ps1/`, every file with ProjectPSX's notice and its provenance line:

- **`PS1Machine<Tracer>`**: the R3000A specialized over `PS1Bus`, and ProjectPSX's run loop — about 100 cycles of CPU (each instruction's fetch and load wait states counted toward the slice), then the devices for what they took, then the interrupt check. `runFrame()` runs to the next vertical blank. `load(_:)` lands any pending load, then starts a PS-EXE now; `boot(_:)` starts one when the BIOS reaches its shell at 0x80030000. `tty` is expansion 2's output, plus the BIOS's putchar (A(3Ch), B(3Dh)) when `capturesBIOSPutchar` is on, as ProjectPSX's `TTY()` hears it. Its CPU has `NoCoprocessor2` until v0.2.0's GTE, so COP2 raises Coprocessor Unusable.
- **`PS1Console`**: what the apps hold. It is powered off until `powerOn(bios:)` gets a 512 KB image.
- **`PS1Bus`**: the memory map. The 2 MB of RAM is mirrored through the window RAM_SIZE sets (the BIOS's 8 MB); then the scratchpad (KUSEG and KSEG0), the I/O ports, expansions 1–3 as far as their size registers reach, the read-only BIOS and the cache control register. RAM and BIOS fetches and RAM loads and stores take an `@inlinable` fast path. `peek32` reads memory for the CPU's look-ahead, and `withRAM(_:)` hands tools the guest RAM, both without a load's cost.
- **`MemoryControl`**: the delay/size registers, COM_DELAY, RAM_SIZE and cache control, with psx-spx's fixed bits; each region's load time, and the expansions' and RAM banks' sizes.
- **`InterruptController`**, **`Timers`** and **`DMA`**: the seven channels with DPCR and DICR. OTC writes real tables; the device channels feed the stubs, a word at a time, at most 0x10000 words a store or a tick.
- **`GPU`**: NTSC timing (263 lines of 3413 video cycles; an interlaced field 262.5), GPUSTAT and the GP1 display commands; no drawing.
- **The stubs**: `CDROMStub`, `SPUStub` (SPUSTAT follows SPUCNT, which the BIOS waits on), `MDECStub` and `PortsStub`. Each answers with psx-spx's power-on state. Since 3d's oracle comparison (2026-11-07), `PortsStub`'s controller port answers as an empty one, as ProjectPSX's JOYPAD does with no device answering: a byte sent comes back 0xFF and sets JOY_STAT's RX-not-empty until read, with no acknowledge — what SwanStation, with nothing plugged in, shows too once an exchange completes. Its exchange is instant and needs nothing of JOY_CTRL, where SwanStation's takes time and waits for TX enable and /JOY; wider RX reads, JOY_BAUD across a reset and JOY_CTRL's bit 4 differ too — gaps for 3g's comparison to show if they matter.
- **`Expansion2`**: the TTY, its most recent 1 MB kept, and the POST display. **`PSEXE`**: reads, writes and loads the format.
- **Two shared changes**: `R3000ABus`'s narrow stores now pass the whole source register (3e's interface, changed with its tests), and the tests' assembler moved to `SupportMIPS` (`tests/support/mips/`), shared by both cores' tests.
- **Tests** in `tests/business/ps1/`, the `macOS Personal` scheme already running them.

**Where it departs from ProjectPSX** (psx-spx and the hardware decide; each is a comment beside the code):

- **Wait states.** A load costs its region's access time, charged to the devices' clock, so the devices run at the real rate. ProjectPSX charges loads nothing and ticks its devices three times faster to compensate (`MIPS_UNDERCLOCK`). The times come from psx-spx's formula over the delay registers for expansions 1–3, the BIOS, the SPU and the CD-ROM, and from ps1-tests' `access-time` log, recorded on hardware, for RAM (5), the scratchpad (1), the I/O ports (3) and cache control. Fetches keep ProjectPSX's 1 and 20 cycles, so cycle counts stay comparable with its traces. Stores cost nothing (the write buffer).
- **Bus errors** where psx-spx maps nothing or locks the address: past RAM_SIZE's banks (its 0x0888 leaves 2 MB), past each expansion's size from DEV0, DEV8 and DEV1 (judged on an access's first byte; ProjectPSX's second TTY port at 0x1F802080 stays open), psx-spx's locked gaps in the I/O region and in KSEG2, between the regions, beyond the BIOS, and the scratchpad through KSEG1 or as code. ProjectPSX has no bus errors: it mirrors RAM through everything below 0x1F000000 and its expansion ROM through expansion 1, reads memory-control bytes or a nearby device in the I/O gaps, mirrors the BIOS through 0x1F804000–0x1FC7FFFF, and reads all ones from 0x1FC80000 up.
- **Widths, from psx-spx and the `io-access-bitwidth` log on hardware.**
  - A narrow store reaches a 32-bit port as the whole source register, and a narrow load reads its byte lane of the port.
  - The 8-bit CD-ROM port is read again for each byte of a wider load.
  - The SPU's 16-bit registers take a byte or halfword store's low halfword, ignore a byte store to an odd address, and read or write two registers for a word.
  - The controller and serial ports' 16-bit registers take a byte store at an odd address shifted left 8, and only a word store's low halfword.
  - A DMA channel's BCR takes a narrow store in its own byte lanes, and a halfword store to DICR's upper half clears its force-IRQ bit.
  - Expansion 2 reads all ones at every width, as the log shows. Expansions 1 and 3 read all ones too, by choice — nothing is attached — though the log's expansion 3 row reads open-bus values that aren't modelled.
  - DICR keeps its bits 0–5, and timer targets are 16 bits.
- **DMA.** Words move one at a time, and nothing guest-sized is allocated (ProjectPSX hands the device a span of RAM). No store or tick moves more than 0x10000 words on a channel; ProjectPSX moves GPU-from-RAM's and MDEC in's every block at once, up to 2³² words. A transfer follows CHCR's step, −4 included, in 24 bits, writing nothing past RAM's window; MADR and BCR end as psx-spx says; a block size or count of 0 means 0x10000 in every sync mode. DICR's bit 31 is psx-spx's formula and requests the interrupt as it rises, and a completion sets its flag only with the master enable on. 0x1F8010xC mirrors CHCR, and OTC's CHCR keeps only bits 24, 28 and 30, with bit 1 fixed from power-on.
- **The GPU.** The video clock is the NTSC console's 53.693175 MHz, kept exactly against the CPU's 33.8688 MHz; ProjectPSX uses 11/7 (psx-spx's PSone/PAL ratio) and drops the remainder on every tick. An interlaced field is 262.5 lines, 263 and 262 in turn. GPUSTAT's bit 13 reads 1 without interlace and alternates by field with it, at 240 lines too; bit 31 reads 0 in the vertical blank. GP1(40h–FFh) mirror GP1(00h–3Fh), and GP1(08h)'s 368-pixel bit means divider 7 whatever HDS1 holds (ProjectPSX indexed past its table).
- **Smaller fixes.** The memory control registers are initialized, with the values the BIOS writes as they read back; ProjectPSX leaves them as uninitialized memory. OTC entries are 24 bits. JOY_CTRL's and SIO_CTRL's bit 6 resets the port's mode, control and baud registers (ProjectPSX's SIO1 is plain memory). The TTY keeps its last 1 MB.
- **Loading.** psx-spx's size field decides how much of a PS-EXE loads (ProjectPSX copies the whole file), its fill region is zeroed, a load still in the CPU's delay slot lands before the EXE's registers are set, and the EXE starts when the PC reaches the shell, which holds for any BIOS. ProjectPSX skips the fill and patches SCPH-1001's image at 0xBFC06FF0.

**Trade-offs.** psx-spx calls its access-time formula approximate, and against the hardware log it misses for expansion 2 (15/29/57 cycles against 11/26/56), the CD-ROM (7/13/25 against 8/14/26) and the SPU (21/41 against 18/39). It is kept, since it responds to the registers the BIOS writes, and 3g settles the differences against SwanStation's output; the BIOS and expansions 1 and 3 match. The log's open-bus values (I_MASK's upper half reading 0x1234_0678, for one, and expansion 3) aren't modelled. GP0 is consumed unread until v0.1.0 draws, so GPUSTAT's drawing bits stay 0. The CD-ROM never answers, so a real BIOS's boot may wait on it; which registers it needs is read from 3d's traces before any stub does more. Two of ProjectPSX's behaviours stay until 3g's comparison with SwanStation: the vertical blank's interrupt comes at the field's end whatever GP1(07h)'s Y2 holds (the console counts frames off the same signal, so moving it means separating the two), and a linked-list DMA stops only after 0xFFFF nodes, which with 255-word nodes costs about 0.1 ms of host time per store today and will cost more once GP0 draws.

**Verified** (2026-11-07, M3 Max, macOS 27.0.1, Xcode 27.1):

- **The console's tests**: 41 hermetic tests in 10 suites, over BIOS images and programs built in code, plus the benchmark, off by default. They cover:
  - the memory map's mirrors, segments, read-only BIOS, empty expansions and bus errors;
  - the I/O widths, each against a row of the hardware log;
  - the CPU taking the vertical blank every frame through a handler and RFE;
  - the timers' clocks, targets, IRQ and flags; OTC's table, DPCR and DICR;
  - the NTSC frame, within 200 cycles over 10 frames, and GPUSTAT;
  - PS-EXE round trips and loading;
  - the TTY through expansion 2, the BIOS's putchar and the boot hook;
  - the load costs of RAM, the BIOS, the scratchpad and an I/O port, measured as cycles per loop, and psx-spx's formula for the regions the delay registers govern; the console powering on.
- **Planted bugs, 4 of 4 caught, then restored**: a narrow store truncated; the video clock at 10/7; RAM loads free; the CD-ROM port not repeated.
- **Speed** (`ISTATION_BENCHMARK=1 swift test -c release --filter BusinessPS1Tests.BenchmarkTests`): the spike's loop on the whole console — CPU, bus, wait states and devices, 600 frames — runs at **209–210 M instructions/s, 10.3× the PS1's 33.8688 MHz**, two runs.
- **The full suite**: `swift test` — 173 tests in 11 test runs, green (the architecture checks included); the strict build and the release build clean; the docs validator clean; `xcodebuild test -scheme "macOS Personal"` — TEST SUCCEEDED; both apps' personal routines build (`./scripts/build-personal.sh macOS`, `iOS`).
- **For 3g**: the per-frame comparison with ProjectPSX, carried into 3g's document.
- **After the review** (2026-11-07, the review in Milestone I): the bus and device findings fixed — among them a GP1(08h) mode that indexed past the dot-divider table, a DMA store that could ask the host for 17 GB, and the CPU's look-ahead reading past the SPU's registers — each with a regression test (`BusRegressionTests`, `DeviceRegressionTests`). Now **76 tests in 15 suites**, green, and clean under AddressSanitizer; `swift test` runs 223 tests in 11 test runs, green, with the strict and release builds clean. The console's benchmark re-measured **218–222 M instructions/s, 10.7–10.9× the PS1**. SwanStation's frame records still match the console's on the CPU-check image over 5 frames, identically.

**Decisions consumed.**

- 2026-11-07: one console module, devices carved out only behind the trace harness (ADR 0015).
- 2026-11-07: the stubs answer as psx-spx documents each device's power-on state; NTSC only; what `access-time` and `io-access-bitwidth` need — wait states, register widths — ported here (the defaults, confirmed by the user).

## Milestone K — The reference and the oracle

**Goal.** The two references the Swift PS1 core is checked against, able to trace: ProjectPSX, the MIT reference it is ported from, instruction by instruction with trace logging added to its source; and SwanStation, the more accurate GPL oracle, built unmodified and recorded from outside through libretro's public API — then both run on the user's own BIOS images (v0.0.1 item 3d; [ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).

**Built** (3d, 2026-11-07 to 2026-11-14, by a session that has never read a GPL emulator's source; nothing here ships, every build lives in a git-ignored `.build/`):

- **`tools/projectpsx-trace/`** — ProjectPSX pinned at `f4dc13aea42d`, cloned and patched by `build.sh`. `trace.patch` adds `IStationTrace.cs` (MIT, iStation's own), which writes TraceKit's instruction, full-state and frame records and the TTY, and hooks it into ProjectPSX: the retired instruction, the BIOS's putchar and expansion 2's DUART (from an EXE's entry point on), a settable BIOS path, readable guest RAM, both controller slots empty. `host/` is a headless runner: it opens the CD-ROM's lid (ProjectPSX's CD has no tracks without a disc image, and a BIOS's GetID would throw), answers ProjectPSX's waits for console input, checks its arguments, and exits 3 or 4, keeping what was recorded, when ProjectPSX throws or an EXE never starts. The .NET 10 SDK is Homebrew's checksummed package unpacked into `.build/dotnet/`.
- **`tools/swanstation-oracle/`** — SwanStation pinned at `631f0fb31b80`, cloned and built unmodified by `build.sh`, its build output kept to a log no core-writing session opens; `frontend.c` (MIT), a headless libretro frontend written only against libretro-common's `libretro.h` (`d9597c359a5c`): it learns the core's options from its requests (the interpreter, the software renderer, no memory cards, never OpenBIOS), plugs no controller in, links the BIOS under the names the core asks for, and writes frame records — guest RAM's checksum — and, on request, a RAM dump.
- **`tools/istation-run/`** — the Swift console from the command line: `run` (instruction, full-state and frame traces, the TTY, a RAM dump, tracing from a given frame, instructions per second), `diff`, `frames` and `cpu-check-image`; `cpu-check.sh` runs one program built in code on ProjectPSX and the Swift console and diffs their traces.
- **`tools/ps1-tests/fetch.sh`** — ps1-tests' release `build-158` and its four CPU tests' hardware `psx.log` files.
- **In the package**, for the comparisons: `PS1Machine.ttySinceEXE` and `bootIsPending` (an EXE's own output, not its BIOS's), `Expansion2.ttyCount`, and `PortsStub`'s controller port answering as an empty one, as ProjectPSX's and SwanStation's do with nothing plugged in (Milestone J).

**Trade-offs.** SwanStation's TTY can't be heard: the core passes none to libretro's log, so its tests are judged by others' output, and its traces by guest RAM alone — the picture and sound checksums wait for v0.1.0 and v0.2.0 (the user's call, 2026-11-14). ProjectPSX runs an EXE only on SCPH-1001, whose LoadRunShell it patches. With the lid open, a BIOS sees no disc in a way an empty closed drive wouldn't show, which can send ProjectPSX's boot down another path. Every frame record checksums 2 MB, outside the instructions-per-second figure.

**Verified** (2026-11-07 to 2026-11-14, M3 Max, macOS 27):

- **Clean checkouts**: both `build.sh` scripts build from a fresh copy (SwanStation's by the helper session, which relayed numbers only: 45 seconds, HEAD at the pin, the clone unchanged).
- **The CPU check** (3e's guardrail): one program built in code — 1,162 instructions, psx-spx's division edge cases among them — agrees on ProjectPSX and the Swift console for all 18,833 instructions of ProjectPSX's frame, registers and cycles; SwanStation's frame records on the same image match the Swift console's.
- **The user's BIOS images** (2026-11-14, the agent's run by the user's call): 23 PS1 BIOS images, v1.0 J to v4.5 E — named in reports only by version and hash — each through `tools/gate/run.sh`:
  - every tool's boot traces read cleanly with `DataTracing`: ProjectPSX per instruction (608,384–625,057 instructions in its 60 frames, 15 MB) and per frame, SwanStation per frame (1,200 frames, 39,616 bytes), and the Swift console's (1.64–1.66 M instructions in 60 frames, 41.5 MB);
  - **ProjectPSX agrees with the Swift console on every instruction of its 60 traced frames, on all 23 images** — 14.3 million instructions — but for one 14-instruction stretch: the BIOS's read of an expansion ROM's licence header at 0x1F000084, where ProjectPSX returns 0 from its RAM mirror and the Swift console all ones, nothing being attached (psx-spx doesn't say); control flow never parts;
  - **the boot**, 1,200 frames: the Swift console runs 430.8–440.2 M instructions (NTSC BIOSes) or 510.4–511.8 M (PAL) in 2.6–3.1 s; ProjectPSX takes 4.3–5.1 s and SwanStation 4–5 s;
  - **the TTYs against `psx.log`**, from each test's title line: ProjectPSX (on SCPH-1001) fails 8 of `cop`'s 17 checks — its no-op COP1, COP3 and LWCn/SWCn, its COP0 commands, its COP2 — and resets in `code-in-io` once code runs from the scratchpad: its known gaps. SwanStation's isn't heard: its known gap. The Swift console's are 3g's.
- **Three adversarial reviews** of the tools before their commit found 30, 25 and 14 defects, all fixed; the strict build, `swift test` (228 tests in 11 runs) and the docs validator green.

**Decisions consumed.**

- 2026-11-07: ProjectPSX traced from inside its source; SwanStation only from outside, unmodified, guest state only (the user's brief); pinned commits moved only by a dated decision; per-frame records from the oracle (the defaults, confirmed by the user).
- 2026-11-14: the .NET SDK unpacked locally, and the per-frame comparison guest RAM's until v0.1.0 and v0.2.0 (the defaults, confirmed by the user); the user's images include SCPH-1001, so ProjectPSX's TTY was compared and the default for a BIOS without it wasn't needed; the agent makes the BIOS runs with the files the user names (the user's call).

## Milestone L — The BIOS boots

**Goal.** v0.0.1's PS1 gate (item 3g, the user's brief): the Swift console boots real BIOS images to the shell, passes ps1-tests' CPU tests against their hardware logs up to known gaps, and agrees with ProjectPSX instruction by instruction — on the user's own BIOS images, which never enter the repository.

**Built** (3g, 2026-11-07 to 2026-11-14):

- **`tools/gate/run.sh`** — one run per BIOS image: the boot on the Swift console, ProjectPSX and SwanStation (1,200 frames per frame, the first 60 per instruction), ps1-tests' four CPU tests on each, every TTY against its hardware `psx.log` from the test's title line on, and `report.md` and `frames.tsv`. A tool that fails is listed, and a trace cut short never reads as agreement.
- **The coprocessors as the hardware has them** (Milestone I): COP1, COP3 and LWCn/SWCn raise Coprocessor Unusable while their CU bit is clear and do nothing while it is set, and a COP0 command other than RFE and the TLB commands does nothing — what `cop`'s hardware log showed, against ProjectPSX's and the review's readings.

**Verified** (2026-11-14, the agent's run with the user's 23 PS1 BIOS images, v1.0 J to v4.5 E, named only by version and hash; M3 Max, macOS 27):

- **The BIOS reaches its shell on all 23 images**: each starts ps1-tests' programs, as the shell's entry at 0x80030000 starts an EXE.
- **ps1-tests against the hardware logs**, on all 23: `code-in-io` matches. `cop` matches but for the three checks that need a GTE (`testCop2Enabled`, `testCop2InvalidOpcode`, `testSwc2Enabled`). `io-access-bitwidth` matches but for open-bus values (T0_TARGET's and I_MASK's upper halves, expansion 3), SIO1's 0x1F80105C, which reads 0xC0C0 on hardware, GPUSTAT's bit 31, the line parity at the moment of the read (psx-spx: it flips every scanline in 240-line mode), and, on v4.0 J alone, the BIOS's own first word, the log having been recorded on another BIOS. `access-time` comes within about a cycle everywhere — RAM 5.8 against 5.1–5.3, I/O 3.2–3.3 against 3.1–3.8, the scratchpad 1.0 against 0.9–1.5 — but for psx-spx's formula for expansion 2 (15–57 against 11–56), the SPU and the CD-ROM; the cycle comes from the timers advancing once per ~100-cycle slice, ProjectPSX's run loop, so a read inside a slice sees a stale count. These are the known gaps (the user's call).
- **ProjectPSX agrees on every instruction** of its 60 traced frames on all 23 images — 14.3 million — but for one 14-instruction stretch, the expansion ROM header read at 0x1F000084 (Milestone K).
- **Instructions per second for the boot** (ADR 0015's enforcement from here on): 164 M across the 23 images' 1,200-frame boots, 10.5 billion instructions in 64 seconds of emulation — 2.6–3.1 s a boot, about 4.8 times the PS1's 33.8688 MHz in instructions.
- **SwanStation, frame by frame**: the RAM of both consoles is zero at power-on and differs from the first frame. The boot runs at another pace — on SCPH-5501 the Swift console has written 3,028 non-zero bytes by frame 1 against SwanStation's 711 — and converges: by frame 600 they differ in 1,424 of 2,097,152 bytes. Then SwanStation's shell keeps running and the Swift console's waits: it polls GPUSTAT's bit 27 at 0x800509DC for a VRAM-to-CPU transfer, and the GPU consumes GP0 unread until v0.1.0. The frame-by-frame match is v0.1.0's gate (the user's call).
- The strict build, `swift test` (228 tests in 11 runs), the CPU check and the docs validator green.

**Decisions consumed.**

- 2026-11-07: the milestone is the brief's (the user's brief); OpenBIOS not used (ADR 0013 §6); every CPU test's expected output its hardware `psx.log` (the user's call, 2026-11-07).
- 2026-11-14: "boots" means the BIOS reaches its shell; the frame-by-frame match with SwanStation moves to v0.1.0, after the GPU's VRAM transfers; the remaining differences are recorded as known gaps (the user's calls); the agent makes the BIOS runs with the files the user names (the user's call).

## Milestone M — Documentation by kind, then platform

**Goal.** The documentation laid out as the user's Apogee repository lays its own (v0.0.1 item 4a; the user's call, 2026-11-14): by kind, then by platform, so each kind of document sits in one place and a second application would get a folder in each.

**Built** (4a, 2026-11-14):

- **`lib/documentation/`** — the router `CLAUDE.md` in Apogee's shape (a kinds table, a platforms table, the facts that cross the boundary), and four kinds, each with a `README.md` listing its platform folders: `assistant/darwin/` (CLAUDE, SPEC, ROADMAP, MILESTONES, DEVELOPER), `backlog/darwin/` (the index and `v0.0.1/`), `adrs/darwin/` (the 17 records and their index, numbers and history unchanged) and `reference/darwin/` (the trace formats). Each kind's `darwin/` holds `macos/` and `ios/`, a note for what binds one OS alone; an item for one OS goes in the backlog's `darwin/<os>/v<x.y.z>/`. The old docs home's README folded into the router.
- **`lib/scripts/validate_docs.py`** — taught the layout: an application's index is `backlog/<app>/README.md`, a row's document sits in its table's folder directly under it or under an OS folder, and the kinds' own READMEs aren't indexes.
- **Every path moved with the files**: 33 files `git mv`ed, then every relative Markdown link in the repository recomputed — resolved where it pointed, re-aimed from where its file now sits — and the present-tense mentions rewritten in the docs, the root `CLAUDE.md` (kept as the pointer, with the hard rules) and `README.md`, the 13 skills, the layer cards, the architecture checks (ADR 0001's and 0002's paths), `Package.swift`'s and `Version.xcconfig`'s comments, the tools' READMEs and `frontend.c`, `ci.yml`, and the Xcode navigator, whose `lib` group now holds `documentation` and `scripts`. MILESTONES' text and dated decisions keep the paths they were written with.

**Verified** (2026-11-14): the validator clean on the new layout — one index, darwin's (6 rows), 355 links across 66 files — and, on a copy, it fails on a planted row whose document is missing and on a planted broken link, and accepts an item under `macos/v0.0.1/`; `swift test` (228 tests, the ADR checks reading the new paths) and the strict build green; the macOS app builds; `git grep documentation/istation` finds only MILESTONES' history.

**Decisions consumed.**

- 2026-11-14: mimic Apogee's layout, adapted for iStation (the user's call); the root `CLAUDE.md` stays as a pointer, the one application is `darwin` with `macos/` and `ios/`, and the move lands after 3g (the defaults, confirmed by the user).

## Milestone N — The code under `lib/src/darwin/`

**Goal.** The Apple apps' code self-contained under `lib/src/darwin/`, as the user's Apogee repository keeps its own (v0.0.1 item 4b; the user's call, 2026-11-14), with each Presentation module given its own scheme (the user's call, vetoing the default to wait).

**Built** (4b, 2026-11-14):

- **The move**: `src/istation` → `lib/src/darwin` (the package, `apps/`, `scripts/`, `source/`, `tests/`), `iStation.xcodeproj` → `lib/src/darwin/iStation.xcodeproj` beside the package, and `tools/` → `lib/src/darwin/tools/` — whole directories, so the git-ignored `Local.xcconfig` and every tool's `.build/` (the ProjectPSX clone, the .NET SDK, SwanStation's build) moved with them, unopened.
- **The project**: the package referenced at its own folder (`.`), the schemes' package references at `container:`, the apps' groups at `apps/`, the routines' entitlements relative to the project, and an "iStation repository" group at `../../..` keeping the whole repository in the navigator (the user's call of 2026-11-14, kept).
- **Per-module schemes** ([ADR 0017](../../adrs/darwin/every-presentation-module-has-its-scheme.md)): `PresentationStyles`, `PresentationPlayer` and `PresentationAcknowledgements`, each building its module and running its bundle; `everyPresentationModuleHasItsScheme` checks them.
- **`scripts/build.sh personal|appstore macOS|iOS`** — the one entry point, over the two routines' scripts, which now run from `lib/src/darwin/`.
- **Every anchor and path**: the architecture checks find the repository three levels above the package; `istation-run` depends on `../..` (the package `darwin`); `.gitignore`, `ci.yml` (`working-directory: lib/src/darwin`), the docs, the cards, the skills, the root `README.md` and the tools' READMEs name the new places — links recomputed, present-tense mentions rewritten, MILESTONES' and dated decisions' kept.

**Verified** (2026-11-14): from `lib/src/darwin/`, the strict build (from a fresh build cache) and `swift test` (229 tests in 11 runs, the architecture checks reading the new root and the new scheme check among them) green; all four app schemes build, and each module scheme's tests pass in Xcode (2, 1 and 5); removing `PresentationPlayer.xcscheme` fails the new check; `cpu-check.sh` still agrees with ProjectPSX (37,666 records) and the gate runs from its new place; the docs validator clean; `git grep src/istation` finds only history.

**Decisions consumed.**

- 2026-11-14: the tools in `lib/src/darwin/tools/`, the project in `lib/src/darwin/` with the whole repository in its navigator, `scripts/build.sh` over the two routines' scripts (the defaults, confirmed by the user); a scheme per Presentation module now (the user's veto of the default).

## Milestone O — The release in `lib/release/VERSION`

**Goal.** One file names the release, the apps' version follows it, a check guards it, and the merge into `stable` is the release — Apogee's procedure (v0.0.1 item 4c; the user's calls, 2026-11-14).

**Built** (4c, 2026-11-14):

- **`lib/release/VERSION`** (`0.0.1`) — the release, and the only thing that names one. `lib/src/darwin/scripts/build.sh` writes `MARKETING_VERSION` in `apps/Config/Version.xcconfig` from it, and `ArchitectureTests` (`theVersionFollowsTheRelease`) fail while `VERSION`, `MARKETING_VERSION` and ROADMAP's "In progress" heading disagree.
- **`lib/scripts/version-check.sh`** — CI's `version bump`, on every pull request into `stable`: `VERSION` holds x.y.z, a release branch is named for it, and with the apps' code (`lib/src/`, `lib/release/`) changed since the latest release, `v<VERSION>` is unreleased — else the change would ship in no release; a documentation-only merge with a released `VERSION` publishes nothing and passes. It asks GitHub (gh) whether a version is released, else the tag on origin; "could not ask" fails.
- **`lib/scripts/release-from-pr.sh`** — CI's `tag and release`, once a pull request into `stable` merges: the merge commit's `VERSION` names the release; a tag already at another commit means that version is out, and the merge publishes nothing; otherwise `gh release create` tags the merge commit `v<VERSION>` and publishes its source in one step. Without `--publish`, a rehearsal. `lib/scripts/latest-release.sh` finds the newest published release.
- **`ci.yml`** gains both jobs (and runs on a pull request's `closed`, guarded so only a merge into `stable` releases); the update-release skill sweeps `VERSION` first and hands the user the pull request whose merge is the release; CLAUDE.md's Versioning and Release sections say so. The navigator shows `lib/release/`.

**Verified** (2026-11-14): `version-check.sh` passes on the branch as it is ("merging publishes v0.0.1", no release yet) and fails on each plant — a branch named `v0.0.2`, a released version with the code changed, a `VERSION` of `0.1` — and passes a released version with only documentation changed; `release-from-pr.sh` refuses a missing pull request and a missing number; `theVersionFollowsTheRelease` fails on a planted `MARKETING_VERSION = 0.0.2`, and `build.sh` writes it back from `VERSION`; `swift test` (230 tests), the strict build and the macOS build green; the docs validator clean. The jobs themselves run first on the release's pull request.

**Decisions consumed.**

- 2026-11-14: a merge into `stable` is the release (the user's call); `build.sh` writes `MARKETING_VERSION` from `VERSION`, guarded by a test (the default, confirmed by the user).

## Milestone P — One build path and a pipeline per app

**Goal.** Apogee's pipeline shape (v0.0.1 item 4d; the user's call, 2026-11-14): one build path a developer and CI share, a pipeline per application beside the repository's, and a local rehearsal before a pull request.

**Built** (4d, 2026-11-14):

- **`lib/scripts/cicd.sh`** — the one build path: `--app darwin` builds both Apple apps' personal routine unsigned through the app's own `scripts/build.sh` (which gained `--unsigned`: CI never signs), `--test` runs the strict build and `swift test`, `--docs` the validator, `--all` everything.
- **`lib/scripts/changed.sh`** — what each pipeline is built from, declared once (darwin: `lib/src/darwin/`, `lib/release/VERSION`, `cicd.sh`, `changed.sh`, `darwin.yml`), and whether it changed between two commits; documentation builds no app.
- **Two pipelines**: `ci.yml`, the repository's (`docs`, `version bump`, `tag and release`), and `darwin.yml`, the Apple apps' (`what changed (darwin)` against the latest release, then `build darwin` — `cicd.sh --app darwin --test` on GitHub's `xcode-27` image, or the same job passing empty on Linux when nothing changed). Required jobs carry no job-level `if:`; their steps are skipped instead. Still only for a pull request and a merge into `stable`.
- **`lib/scripts/pr-ci.sh`** — rehearses a pull request's run on the test merge into `origin/stable`, in a temporary worktree, each job through the script its workflow calls; `--uncommitted` includes what isn't committed, new files too. **`lib/scripts/required-checks.py`** — proposes `stable`'s required checks from a pull request's passing jobs; `--apply`, which changes the repository's settings, is the user's.
- CLAUDE.md's checklist asks for the rehearsal before a pull request, and its CI bullet describes both pipelines; DEVELOPER has the commands and a "Changing the pipeline" recipe.

**Verified** (2026-11-14): `cicd.sh --all` green end to end in 52 seconds (the strict build, 230 tests, both apps unsigned, the validator); `changed.sh darwin` answers false for a planted documentation commit and true for a planted code commit; `pr-ci.sh --uncommitted` passes every job on the test merge, and with a planted failing test fails `build darwin`, as CI would; the first rehearsal found two of its own bugs — new files missing from `--uncommitted`, and a missing `changed.sh` read as "unchanged" — both fixed; `required-checks.py --verify` reads `stable` as unprotected, and it refuses a pull request that doesn't exist. The workflows run first on the release's pull request.

**Decisions consumed.**

- 2026-11-14: the newest Xcode image (`xcode-27`); no packaged artifact until v1.0.0; required checks proposed by the script and applied by the user (the defaults, confirmed by the user).

## Milestone Q — Superpowers inside the lifecycle, and application-aware skills

**Goal.** Apogee's agentic procedure (v0.0.1 item 4e; the user's call, 2026-11-14): Superpowers enabled and mapped onto the docs-first lifecycle, and every skill starting by working out which application it is for.

**Built** (4e, 2026-11-14):

- **`.claude/settings.json`**, as Apogee's: `superpowers@claude-plugins-official` enabled, `worktree.baseRef: head`. **`.gitignore`** gains `.superpowers/`, `.claude/worktrees/` and `.claude/settings.local.json`.
- **CLAUDE.md → Working process → "Superpowers fits the docs-first lifecycle"**: the one-time setup (the user's), a table mapping each Superpowers skill onto a lifecycle step with where iStation's rule wins, and "What else holds". Where iStation differs from Apogee: the agent makes and pushes the one squash commit; the clean room covers every subagent Superpowers dispatches (ADR 0013 §2–§3); the tests are `lib/scripts/cicd.sh --test`. Checking it against the installed Superpowers 7.0.2 shaped the landing: ExitWorktree `keep`, then the index's 🚧 edit undone, `git merge --squash`, `cicd.sh --test` on the squashed result, the commit and push, then `git worktree remove` and `git branch -D`. ExitWorktree's `remove` refuses a squash-landed branch. It also shaped the rest: per-task commits stay on the item branch; a residual Critical or Important review finding stops the landing; `systematic-debugging`'s working examples and references are only the permissive ones; and each `Ruling:` is carried into the item's MILESTONES entry, since the ship deletes the document that holds **Decisions made**.
- **The 13 skills** (`.claude/skills/istation-*/SKILL.md`):
  - Each opens with "0. Which application?", the same text in every skill. It resolves `darwin` (today's one application) and, for work that binds one OS, its `macos/` or `ios/` folder, from the arguments, then the conversation. It asks when that is still ambiguous, or when a request names an application with no folder yet.
  - Docs paths are written `lib/documentation/<kind>/<app>/…`. The only links are the router and the repo-wide sections of darwin's CLAUDE.md (Committing and pushing, Superpowers, Versioning, Release and Install).
  - Each was compared with its Apogee twin (`update-release` has none) and took what fits, while keeping iStation's commit-and-push and clean-room steps:
    - each skill's Superpowers step;
    - execute-group's batch contract (the answers committed before the first item, a stopped item's worktree kept and named, the sanctioned acts);
    - create-item's bar per section and its link depths;
    - investigate-bug's sandboxed reproduction and its fixture rule;
    - swap-item's and swap-version's reference surveys and ordered replaces;
    - summarize-pull-request's and summarize-release's evidence commands and leak check;
    - update-documents' walk of the skills and the pipeline.
- **Fixed in passing**:
  - The library-era references (ADR 0007, `library.json`, `Locations.sandbox`, `CFFIXED_USER_HOME`) became today's support modules (`SupportSandbox`, `SupportMIPS`, `SupportDiscFixtures`) and tools.
  - Two clean-room hazards are gone: investigate-bug's "read the emulator's source instead" and investigate-spike's "the emulators' own sources" now point to ProjectPSX, Play! and psx-spx.
  - The `iStation.xcscheme` that no longer exists became the `macOS Personal` scheme's tests, in CLAUDE.md's checklist and two skills.
  - The backlog index states its link depths correctly.
  - A trace, RAM dump or log from a run over the user's BIOS or a game is never committed as a fixture.
  - Release tags are read from origin.
  - update-release keeps ROADMAP's heading on the release until the next version's first commit, as `theVersionFollowsTheRelease` requires; a `## Shipped` section, between In progress and Planned, is created then. It rehearses the sweep with `pr-ci.sh --uncommitted`.
- **`ArchitectureTests`**: the repository walks in `noGameOrFirmwareFiles` and `appStoreEntitlementsAreClean` skip `worktrees`, so a Superpowers worktree under `.claude/worktrees/` isn't walked as part of this checkout. Each worktree runs its own suite.
- **The Xcode navigator** lists `.claude/` as `settings.json` plus a synchronized `skills/`, no longer the whole folder, so `.claude/worktrees/` (whole checkouts) stays out of it, as the tools' `.build/` folders do (DEVELOPER.md).

**Left out from Apogee's skills** (the default, confirmed 2026-11-14: named here):
- Apogee's other applications and their cross-queue siblings (`cli`, `mod`, `design`, `gui/`, `unix/`, `windows/`, its lettered GUI tracks).
- Its dev channel: `apogee-dev`, `~/.apogee-dev`, `make install MODE=dev`. iStation's counterpart is 4f.
- Real-model weights and the model-family rules; probes over `APOGEE_HOME` and the installed `apogee` binary.
- `lib/design/` and its design canvas.
- The CLI's C++ paths, its completion audit, its model rosters and its layer cards.
- Its "Stable: CI must pass" ruleset checks, and its install and platform texts for release notes.
- "The user makes the commit" and "pushing is on the user's word".
- Closing an id's gap when an item moves (swap-item), and track numbers moving with their version (swap-version): iStation never reuses or renumbers ids.

**Trade-offs.**
- The ladder repeats in every skill (Apogee's way), so changing it means editing 13 files.
- With one application, the ladder's question is nearly always about the OS folder.
- Every `Ruling:` goes into MILESTONES, not only the load-bearing ones. That is the conservative choice, so nothing is lost, and it is open to veto.
- The library-era trigger phrases stay in the descriptions.
- The item's guardrail, "no `lib/documentation` path in `.claude/skills/`", was itself rewritten by 4a's migration from the old `documentation/istation`. It is checked as: no `documentation/istation` path, and no docs path naming `darwin` outside the ladder and the repo-wide links.

**Verified** (2026-11-14):
- `python3 lib/scripts/validate_docs.py lib/documentation`: ALL CLEAN, 347 links across 63 files, every SKILL.md included.
- A script finds, in all 13 skills, the ladder word for word, no hard-coded darwin docs path, no `documentation/istation`, no Apogee name, and every anchor naming a real CLAUDE.md heading.
- A dry run of `/istation-backlog-investigate-spike` asks before reading anything. "Spike adding controller remapping" gets the question of macOS, iOS or both; "spike a Windows build of iStation" gets the question of which application.
- `lib/scripts/cicd.sh --test`: the strict build, then 230 tests in 11 runs, all passing.
- Two independent review passes: a consistency critic over the 13 skills, then a check of the skills and of the mapping against the installed Superpowers 7.0.2. They raised 39 findings, all fixed.
- Not done: installing the plugin (the user's); no item has been built in a Superpowers worktree yet.

**Decisions consumed.**

- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call); every task still ends with one commit and a push (2026-11-07, not reopened).
- 2026-11-14: a Superpowers worktree item lands as one squash commit on the release branch, then is pushed; each skill takes what fits from its Apogee twin, and what only fits Apogee is named above (the defaults, confirmed by the user).

## Milestone R — Development on the personal channel

**Goal.** Apogee's "Development runs on the dev channel", for the Apple apps (v0.0.1 item 4f; the user's call, 2026-11-14). Until now each app had one bundle identifier for both routines, so a personal build and an App Store install shared their container, defaults and imported-file bookmarks. Once the apps import BIOS files and games (v0.2.0), development would have read and changed the user's real library.

**Built** (4f, 2026-11-14):

- **`apps/Config/Personal.xcconfig`**: `PRODUCT_BUNDLE_IDENTIFIER[sdk=macosx*] = local.istation.macos.personal`, `[sdk=iphone*] = local.istation.ios.personal`, `PRODUCT_NAME` and `CFBundleDisplayName` "iStation Personal", and `PRODUCT_MODULE_NAME = iStation`, which keeps the Swift module's name.
- **`apps/Config/AppStore.xcconfig`**: the App Store identity, unchanged (`local.istation.macos`, `local.istation.ios`, named "iStation").
- **`iStation.xcodeproj`**: the four app configurations no longer set `PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME` or `INFOPLIST_KEY_CFBundleDisplayName`, which would override both xcconfigs. `scripts/build-personal.sh` prints the `iStation Personal.app` path. Each target has one product reference, which both routines share. When Xcode reopened the project it renamed that reference to the Debug configuration's product, `iStation Personal.app`, and it wrote every scheme's `BuildableName` as `iStation.app`, the Personal schemes included. Both were kept as Xcode writes them (found at the pre-merge docs pass, 2026-11-14). These names are only labels: xcodebuild finds a target by its identifier, and each routine builds its own bundle, `iStation Personal.app` or `iStation.app`.
- **`ProjectRulesTests`** has two new tests:
  - `routinesHaveTheirOwnIdentity` fails when an app's two routines share an identifier or leave one unset, when the personal build isn't named as one, or when a target setting overrides them.
  - `theIdentityCheckCatchesItsViolations` runs that check against planted text: a shared identifier, and a target override.
- **CLAUDE.md → Working process → "Development runs on the personal channel"**: live passes, smoke tests and "try it" steps use the personal build; the App Store routine is built and archived, never launched against the user's data. The Stack paragraph, README, DEVELOPER and the four skills that make live runs (execute-item, execute-group, investigate-bug, investigate-spike) point to it.

**Trade-offs.**

- On macOS a non-localized `CFBundleDisplayName` changes nothing the user sees: Finder, Spotlight and the menu bar showed plain "iStation" (`kMDItemDisplayName`, measured on the build). `INFOPLIST_KEY_CFBundleName` is ignored by Xcode's generated Info.plist. So the personal routine renames the product itself, and the bundle is `iStation Personal.app`, with the module name pinned.
- On iOS the Home Screen shortens the name to "iStation Personal" in one line, as the screenshot showed.
- The personal macOS routine isn't sandboxed (ADR 0016), so it keeps its defaults under its own identifier, not in a container. The App Store routine's container is `~/Library/Containers/local.istation.macos`, which development never opens.

**Verified** (2026-11-14):

- All four routines built unsigned. Their `Info.plist`s read `local.istation.macos.personal` / `local.istation.ios.personal` named "iStation Personal", and `local.istation.macos` / `local.istation.ios` named "iStation".
- The guardrail's side-by-side run was made on an iOS 18.5 Simulator, which touches no real install: both iOS routines installed together and launched at once (two processes), each with its own data container. Before this, installing one would have replaced the other. The Home Screen showed "iStation Personal" beside "iStation". The two apps were then uninstalled and the Simulator shut down.
- `routinesHaveTheirOwnIdentity` fails, naming the shared identifier, when the macOS personal identifier is set to `local.istation.macos` in the real xcconfig; that change was restored.
- `lib/scripts/cicd.sh --all` passed end to end in 19 seconds: the strict build, 232 tests in 11 runs, both apps' personal routine unsigned (each printed as `iStation Personal.app`), and the validator.

**Decisions consumed.**

- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call).
- 2026-11-14: the personal identities are `local.istation.macos.personal` and `local.istation.ios.personal`, displayed as "iStation Personal"; the App Store identifiers stay `local.istation.macos` and `local.istation.ios` until the user's App Store Connect identifiers exist (v1.0.0) (the defaults, confirmed by the user).

## Milestone S — The design's tokens in `styles`

**Goal.** v0.1.0 item 5a, first of track 5: bring the `styles` module up to the app design's `json/tokens.json` ([`design/darwin/`](../../design/darwin/README.md)), so every screen in track 5 can be built to the design, and add the components the design draws in two or more places. Until now `styles` had three colors, two symbols, five metrics and three fonts, and ADR 0020 said "There is no custom theme: `Palette` names SwiftUI's own colors."

**Built** (5a, 2026-11-22), in `lib/src/darwin/source/presentation/styles/`:

- **`Palette.swift`**: the 42 color roles, one static member each, every member built from its row in `Palette.roles` (token, member, and the dark, light and high-contrast values written as `tokens.json` writes them, `.rgb(0x1E1E21)`, `.rgba(0x00000099)`), as a dynamic `NSColor`/`UIColor` provider resolved at draw time. No asset catalog, and no system color or material in a role the app draws. `screen`, `onScreen` and `secondaryText` keep their names.
- **`Theme.swift`** (new): the theme setting (`system`, `dark`, `light`, `highContrast`; Match the system is the default) and its resolution to `ResolvedTheme` (dark, light, contrast); `Theme.applied`, the choice the providers read; the scheme each choice asks of the system (`colorScheme`, `appearanceName` on macOS, `userInterfaceStyle` and `accessibilityContrast` on iOS); `TextSize` (Small, Medium, Large, Extra large). Unknown stored values read as the default.
- **`Typography.swift`**: `Typography.Style`, the eight text styles in the macOS and iOS ramps with their weights, applied with `.textStyle(_:weight:monospaced:)`; the text-size multiplier on macOS (`\.textSize`), Dynamic Type on iOS. The player's and acknowledgements' fonts are unchanged.
- **`Metrics.swift`**: `space1` to `space10`, the six radii, and `LayoutSizes` for each platform (`Metrics.mac`, `Metrics.iOS`, `Metrics.layout` for the current one), the job sheet's and alert's widths and the results list's height among them, added to `tokens.json` first. The player's names stay as aliases.
- **`Motion.swift`** (new): fast, base and slow (0.12, 0.2, 0.32 s), the design's curve, and no animation under Reduce Motion.
- **`Symbols.swift`**: 55 entries, an SF Symbol for each key of the design's `ICON` set, each there by macOS 14 and iOS 17.
- **`Models/`** (no imports): `JobPresentation` (title, steps with their states, progress, summary, per-file results, output, buttons, and which key presses which) and `Tone` (neutral, muted, ok, warning, danger, info, verify: each a pair of the design's roles and its symbol).
- **`Components/`**: `JobSheet`, `DetailsAlert`, `Chip`, `Banner`, `Keycap`, each with a named `#Preview` per state inside `#if DEBUG`, over `Previews/PreviewJobs`.
- **Tests**, in `tests/presentation/styles/`: `TokensTests`, `ThemeTests`, `PaletteProviderTests`, `ToneTests`, `SymbolsTests`, `JobPresentationTests`, `KeycapTests` (with `Design.swift`, which reads `tokens.json` and `html/main.html` by repository path); 50 tests in 8 suites, from 2.
- **`LayeringTests`**: `presentationModulesHaveTheMVVMShape` admits `Models/` in `styles`.
- **The design**: `tokens.json`'s `swiftui` map names each role's `Palette` member (42 roles, 54 notes; `focus` and the sheet dimming of `bg-overlay` stay system-drawn, and say why), and gains the three sizes above; `node tools/sync.mjs` copied it into `html/main.html` and the seven pages that embed it. `Layout` and `Processes` name the shared components in `styles` where they named a Jobs module; the `Contract` page's Branding call drops the accent and the look. Published to [the canvas](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) as this item landed.
- **The docs**: [ADR 0023](../../adrs/darwin/presentation-is-mvvm-and-styles-carries-the-design.md) supersedes ADR 0020; CLAUDE.md (the UI section, the Codebase Map, the checklist, and the one exception to "no singletons"), DEVELOPER ("Adding a token" first in `tokens.json`, the module's section, the test table), both Presentation cards and the live ADR 0020 citations follow.

**Trade-offs.**

- **`Theme.applied` is process-wide.** AppKit and UIKit hand a dynamic color only the appearance or traits it is drawn in, and SwiftUI hands each color an appearance built from its color scheme, so an explicit choice can reach the providers no other way. The routes tried and refused: `NSAppearance(named: .accessibilityHighContrastDarkAqua)` returns plain Dark Aqua on this macOS (pinned by `highContrastCannotBeNamed`); neither an `NSAppearance` subclass nor `_colorSchemeContrast` reached a provider in an `NSHostingView`; a custom `ShapeStyle` reading the environment worked, but would have made members something other than `Color`. CLAUDE.md's Code Style names it as the one exception to "no singletons", and ADR 0023 records why.
- **macOS has no high contrast an app can turn on.** An explicit High contrast draws the palette's contrast values, and asks for Dark Aqua; AppKit's own controls draw high contrast only while the system's Increase Contrast is on.
- **Hand-written values, checked twice.** The colors are Swift literals, not generated, so `TokensTests` compares each with `tokens.json` and recomputes every contrast pair from the Swift side.
- **The user's own accent color is not used**: the design's amber is the accent. The focus ring stays the system's, in the user's accent.

**Verified** (2026-11-22):

- `lib/scripts/cicd.sh --app darwin --test` in the item's worktree: the strict build, `swift test` (280 tests in 11 runs, from 232; the three benchmarks skipped as before) and both apps' personal routine built unsigned, `iStation Personal.app` for macOS and for the iOS Simulator; exit 0. `xcodebuild build-for-testing -scheme PresentationStyles` for the iOS Simulator also passed, so the iOS-only branches compile.
- Planted violations, then restored: `fg-muted`'s dark value darkened in `Palette` failed `everyColorRoleHasItsPaletteRow`, `everyContrastPairMeetsItsMinimum` and `eachToneIsAContrastPair`; Light resolved to the dark theme failed `anExplicitChoiceWins`, `anExplicitChoiceIsWhatIsDrawn` and `explicitChoicesApplyThroughTheAppearance`.
- `node tools/check.mjs` and `--render`: 138 color pairs at their minimum, 2015 renders, 8 flows, 29 shortcuts, 72 boards, 137 pages rendered in headless Chrome. The canvas's files matched the base commit's before the publish, so nothing on it was overwritten.
- Each component's previews were rendered to images in Dark, Light and High contrast through an `NSHostingView` (a throwaway test, deleted) and compared with the `Foundations-Components` board in the browser: steps and their states, the alert with Details open and closed, chips, banners and keycaps draw as the board does, and High contrast draws on its black window.
- Not verified: the system's Increase Contrast turned on (a system setting) with a preview open, which is the one way to see SwiftUI's own route to the contrast values; and whether the progress bar's accent tint shows in an active window (the offscreen render, an inactive window, drew it grey, as macOS draws inactive windows' controls).

**Decisions consumed.**

- 2026-11-22: the look is the design's graphite and amber, amber the accent (the user's call); colors are dynamic `NSColor`/`UIColor` providers, not an asset catalog (the default, confirmed by the user); the theme's default is Match the system, with High contrast under Increase Contrast (the default, confirmed by the user); the shared components start in `styles` (the default, confirmed by the user); the design is published as the item lands, and screens are checked by rendered previews (the user's calls, before the group run).
- 2026-11-22, rulings made building it:
  - High contrast: `Theme.applied`, as above, accepted at landing for the user's veto; it supersedes the build's first ruling, which set Dark Aqua alone and left an explicit High contrast drawing the dark values.
  - Settings' stored values: `system`, `dark`, `light`, `highContrast`; `small`, `medium`, `large`, `extraLarge` (tokens `s`, `m`, `l`, `xl`).
  - Text styles are `Typography.Style` cases, since `Typography.title` and `.body` were taken; their default weights come from the `Foundations-Type` board (largeTitle and title bold; title2, title3 and headline semibold; the rest regular). iOS ignores the text-size setting and follows Dynamic Type.
  - Symbols: `finder` is `folder.circle` (the real `finder` symbol is from 2025 and reserved for Apple's Finder), `spinner` is `circle.dashed` (`progress.indicator` is from 2024), `save` and `load` are `tray.and.arrow.down` and `tray.and.arrow.up`; where the design draws one shape twice the symbol is shared.
  - Spacing the design writes off the scale takes the nearest step (14 → `space4`, 10 → `space3`, 6 → `space2`); the keycap's 4 pt corner is `radiusControl` (6); icons size by text style.
  - The job sheet's buttons: Stop on ⌘., Close on Escape, Finish and Retry the accent default on Return; Escape with no Close stops a running job and otherwise finishes; a running sheet can't be dismissed. In `DetailsAlert` Cancel takes Escape and a destructive button is never the default.
  - One `Tone` for every component; a "skipped" step state, which the prototype draws; a pending step shows no word, as `main.html` has it, and VoiceOver says "Waiting".
  - The button style and the code block stay internal to `JobSheet` and `DetailsAlert` until a place needs them; the progress bar and spinner are the system's, the spinner a still `circle.dashed` under Reduce Motion; the sheet's and alert's chrome is the system's, their content on `Palette.raised`.
  - Additions the design doesn't draw: a banner's optional action, and `Keycap(_ shortcut:)`, so the shortcuts sheet can't disagree with the menus.
  - The iOS sheet width is 390, the iPhone width the design draws at; no iOS code reads it yet.

## Milestone T — The narrow interface: boot, the shell and debug values

**Goal.** v0.1.0 item 6a, the first of track 6: give `PS1Console`, the one thing the apps hold ([ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §5), what three of the design's gaps need and only `istation-run` could reach through `PS1Machine`: booting a PS-EXE (G5), knowing the BIOS reached its shell (G10), and, in personal builds, the debug values and in-app trace recording (G6). Until now `PS1Console` offered `name`, `isPoweredOn`, `powerOn(bios:)`, `runFrame()` and `frame`, and its name was "PlayStation".

**Built** (6a, 2026-11-22), in `lib/src/darwin/source/business/ps1/` (ported from ProjectPSX, every file with its notice):

- **`PS1Machine.swift`**: `reachedShell`, true from the first time the PC is about to run 0x80030000. The PC is watched from power-on until then, and afterwards only while BIOS putchar is captured, so play pays one Bool test per instruction. Each instruction's address is checked once, just before it runs: the slice's first above the loop (the interrupt check may have moved the PC), each next one right after the step before it. `isWatched(_:)` is one AND and three compares, inline, so only the three watched addresses (0x80030000, 0xA0, 0xB0) pay `watch()`'s call. `boot(_:)` now only records the EXE: one given before the shell starts there, in its place; one given after waits for good, since the shell is entered once per power-on; a second replaces one that waits.
- **`PS1Console.swift`**: `name` is "PS1"; `boot(exe:)`, `bootIsPending` and `reachedShell`, forwarding to the machine (nothing booted, false, while powered off); `powerOn(bios:)` starts a fresh machine, and one that throws changes nothing. Under `PERSONAL_BUILD`, `debugSnapshot: PS1DebugSnapshot?`, nil while powered off.
- **`PS1DebugSnapshot.swift`** (personal only): one `Sendable`, `Equatable` value taken between frames — pc, the 32 registers, hi, lo, sr, cause, epc, the CPU's cycles (the count TraceKit's full-state records carry), frame, tty and ttySinceEXE — built by one `PS1Machine` extension both consoles use.
- **`PS1TracingConsole.swift`** (personal only): `PS1TracingConsole<Tracer: R3000ATracer>`, beside `PS1Console`, with the same members plus `powerOn(bios:tracer:capturesBIOSPutchar:)`, `tracer` and `withRAM(_:)`, for the in-app recordings and the personal build's session (5b, 5f). `PS1Console` stays `PS1Machine<NoTracer>`.
- **Tests** (`tests/business/ps1/`, over BIOS images and EXEs built in code): `ConsoleInterfaceTests.swift` (`ShellTests`, `ConsoleBootTests`) and `PersonalConsoleTests.swift` (`DebugSnapshotTests`, `TracingConsoleTests`), among them a recording through `PS1TracingConsole<TraceKitTracer>` with frame records read back identical to one made `istation-run`'s way, and sweeps of 128 paddings that put the shell or a putchar call at a slice's first instruction or at its end under a pending interrupt. `BusinessPS1Tests` take `SupportR3000ATrace` and `SupportSandbox`. `ProgramTests` and `PlayerViewModelTests` expect "PS1".
- **`ProjectRulesTests`**: `toolsArePersonalOnly` also fails on `PS1DebugSnapshot`, `PS1TracingConsole` or `debugSnapshot` named outside an active `#if PERSONAL_BUILD` frame; `thePersonalOnlyCheckCatchesItsViolations` plants five violations and three non-violations.
- **The design**: the `Contract` page's rows C10, C19, C49, C40 and C41 are ready and C42 the app's, with their evidence; gaps G5, G6 and G10 say they're closed and what shipped; the Branding call drops the console's name, and a decision records "PS1". At the Today level a PS-EXE now plays (`canPlay`), its opening job takes the steps 5d builds (open the file, power on, start the program) and Reset's Details name `boot(exe:)`; `check.mjs`'s today flow covers it, the `Processes` page gains a "Play a PS-EXE" flow, and the Contract board's frame grows to 7000 to fit. The Today boards for the BIOS check and Tools keep their before-6a state, which 5c and 5f cite. Published to [the canvas](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) as this item landed.
- **The docs**: CLAUDE.md (the `ps1` row, and ⚠ Release builds' sub-rule and Enforcement for the personal-only API), DEVELOPER (the `ps1` entry, the test table), the design's README, and 5b's, 5d's and 5f's documents for what shipped.

**Trade-offs.**

- **The watch costs a booting machine one Bool, one AND and, rarely, three compares per instruction.** A BIOS reaches its shell in its first seconds, so play pays the Bool alone; the CPU-check image never reaches a shell, so it pays the whole watch, the worst case.
- **An EXE given after the shell waits for good**, rather than loading at once: a first version did load it, which started it wherever the frame ended, often inside the vertical blank's exception, so the BIOS's interrupts never fired again (shown with a code-built BIOS whose handler then ran 0 times in 60 frames). Booting is power on, then `boot(exe:)`, before the first frame; Reset does both again.
- **The snapshot has no instruction count and the plain console no putchar capture**: both come from `PS1TracingConsole` in personal builds (decided below), so the App Store build's console is unchanged.

**Verified** (2026-11-22):

- `lib/scripts/cicd.sh --app darwin --test` in the item's worktree: the strict build, `swift test` (309 tests in 11 runs, from 280; `BusinessPS1Tests` 107, from 79) and both apps' personal routine, macOS and the iOS Simulator; exit 0. `swift build -c release --explicit-target-dependency-import-check=error` (no `PERSONAL_BUILD`) and the macOS App Store routine's Release build, unsigned, compile without the personal-only API; the release objects carry none of its symbols.
- The guardrail's speed: `istation-run` (release) on the CPU-check image, 20 interleaved runs of 6,000 frames against the loop before 6a, ran within 0.4% of it, about 153 M instructions/s (the line was 136 M/s on 2026-11-21); `BenchmarkTests` (release) 244–245 M/s against 235–242. Instruction and cycle counts are unchanged (16,986,128 instructions over 600 frames).
- Mutations, each restored: not clearing the watch once the shell is reached failed the shell tests; removing the slice-start check failed `aShellReachedAsASlicesFirstInstructionIsTaken` and `putcharCalledAsASlicesFirstInstructionIsHeardOnce`; removing the slice-end guard heard a putchar twice; watching after every step failed the two interrupted-at-a-slice's-end tests.
- `git grep PlayStation` under `lib/src/darwin/apps`, `tests` and `source` finds nothing. `node tools/check.mjs` and `--render` pass: 54 contract rows (17 ready, 15 app, 19 gaps, 3 verify), 8 flows, 137 pages rendered. The canvas's files matched the base commit's before the publish.

**Decisions consumed.**

- 2026-11-22: `PS1Console.name` is "PS1" (the user's call); `reachedShell` is watched from power-on until first reached, then not (the default, confirmed by the user); the debug values are one `Sendable` snapshot taken between frames (the default, confirmed by the user); trace recording uses a personal-only console generic over its tracer, `PS1Console` staying `NoTracer` (the default, confirmed by the user); the design is published as the item lands (the user's call, before the group run).
- 2026-11-22, rulings made building it:
  - An EXE given after the shell was reached waits for good (`bootIsPending` and `reachedShell` both true); a second EXE replaces one that waits; `boot(exe:)` while powered off does nothing; a `powerOn` that throws changes nothing.
  - `reachedShell` means the PC reached 0x80030000, whatever brought it there.
  - The snapshot's `cycles` are the CPU's, not the system clock's, as TraceKit's records carry them; it also carries `ttySinceEXE`. `PS1Machine.debugSnapshot` is public, as `cpu`, `tty` and `cycles` are; the snapshot has a public memberwise init for previews.
  - `PS1TracingConsole.name` is a computed static (a generic type has no stored statics); its `tracer` is a copy of the CPU's tracer value.
  - Contract rows C40 and C41 are ready for what they name, their notes saying where the speed and the putchar output come from; C42, recording in the app, is the app's.
  - At the Today level a PS-EXE plays, since 5d builds it so; the BIOS check's and Tools' Today boards keep their before-6a state.
  - In personal builds 5b's session runs `PS1TracingConsole` with an instruction-counting tracer and optional putchar capture, which gives 5f's speed and putchar output; the App Store build runs `PS1Console`, and 6a's interface doesn't grow. 5b's session powers on with an optional PS-EXE, boots it before the first frame, and Reset does both again. Decided in the group run without the user, for the user's veto, and recorded in 5b's and 5f's documents.

## Milestone U — The console session and the player

**Goal.** v0.1.0 item 5b: the service that runs the console off the main actor, which every later screen uses (power on, frames at a steady pace, pause, reset and stop), and the player the design draws over it on macOS: the toolbar, the HUD, the "No picture yet" panel, the paused overlay, and Reset's and Stop's confirmations with their Details. Until now the player was one state, "Nothing to play yet.", and nothing ran the console.

**Built** (5b, 2026-11-22):

- **Business, the new module `session`** (`lib/src/darwin/source/business/session/`, iStation's own code, `Module(.business, "Session", uses: ["BusinessPS1", "BusinessR3000A"], testSupport: ["SupportMIPS"])`, in the `PS1Core` product):
  - `ConsoleSession.swift`: `ConsoleSession<SessionClock: Clock>`, an actor that owns one `PS1Console`, or under `PERSONAL_BUILD` a `PS1TracingConsole` with an instruction-counting tracer. It offers `powerOn(bios:exe:)` (the PS-EXE given to `boot(exe:)` before the first frame; under `PERSONAL_BUILD` also `powerOn(bios:exe:capturesBIOSPutchar:)`), `pause()`, `resume()`, `reset()` (power on and boot the same PS-EXE again), `stop()` (the loop ended and the console released), `snapshot` and `snapshots()`. `ConsoleSession()` runs on `ContinuousClock`. Its frame loop is a `Task.detached` that holds the session weakly, sleeps on the clock and asks the actor for each frame. `FramePace` puts frame n at start + n/60 s.
  - `ConsoleSessionSnapshot.swift`: a `Sendable`, `Equatable` value carrying the state (powered off, running, paused or stopped), the frame, the frames per second, `reachedShell` and `bootIsPending`; under `PERSONAL_BUILD` also `instructions` and `debugSnapshot`.
  - `ConsoleSessionControls.swift`: the protocol the player drives (pause, resume, reset, stop, snapshots), so previews and tests use fakes.
  - `InstructionCounter.swift` (personal only): the `R3000ATracer` that counts, as `istation-run` does.
- **Presentation, `player`**:
  - `Models/PlayerRun.swift`: the BIOS file's name and size, and a PS-EXE's name and file name, told by whatever starts a run.
  - `Models/PlayerAlert.swift`: a question's title, message, Details and confirm button.
  - `ViewModels/PlayerViewModel.swift`: `PlayerViewModel(session:)`, with states `.nothingLoaded`, `.running`, `.paused` and `.stopped`. Its intents are pause, resume, toggle pause, ask to reset, ask to stop, confirm, cancel and full screen. `started(_:)` follows the session's snapshots. It also gives the texts as `main.html` writes them.
  - `Views/PlayerView.swift`, `PlayerHUD.swift` and (macOS) `PlayerWindow.swift`: the screen, the HUD, `playerWindow(_:idleTitle:)` (the title, the toolbar, full screen kept in step with the window's own) and `PlayerCommands`, the Game menu.
  - `Previews/PreviewPlayer.swift`: a `PreviewSession` and a named preview per state: twelve of the screen, four of the HUD and six of the window.
- **`styles`**: `SheetButtonStyle` is public, for the paused overlay's Resume.
- **The apps**:
  - **macOS**: the composition root builds one `ConsoleSession()` and `PlayerViewModel(session:)`. It has one `Window` scene with a minimum of 800 × 560 less the toolbar and 1280 × 800 by default, the player area at least 640 × 480. The Game menu has ⌘P, ⌘R, ⌃⌘F and ⌘.; the File menu's print items and New Window are gone.
  - **iOS**: builds `PlayerViewModel(session: ConsoleSession())`.
- **Tests**:
  - `tests/business/session/`: `ConsoleSessionTests` (23) and `PersonalSessionTests` (3, personal builds), over code-built BIOS images and EXEs and a `ManualClock`, with one real-time test on `ContinuousClock`.
  - `tests/presentation/player/`: `PlayerViewModelTests` (38) over a scripted `FakeSession`.
  - `tests/support/mips/Programs.swift`: the image builders the PS1 and session harnesses share.
  - `BusinessSessionTests` joins the `macOS Personal` scheme.
- **The architecture**:
  - [ADR 0024](../../adrs/darwin/four-layers-and-business-holds-the-session.md) supersedes ADR 0018. Business is the cores and what the apps do with one, `session`, and the apps run a console only through it.
  - `LayerContextTests.adrListsTheLayersInOrder` reads ADR 0024.
  - Every live citation of the layer law points at it: the router, the three source cards, the tests cards, SPEC and the Presentation card.
  - ADR 0002's table has the `session` row and the Player row's new edge, and its products sentence names `BusinessSession`.
- **The design**:
  - The `Processes` board's console-thread row says the session paces `runFrame` by `ContinuousClock` at 60 a second until the video standard is known (G12), one call at a time in one isolation domain.
  - Contract rows C06, C07, C08 and C50 name `ConsoleSession`'s calls and are tagged ready, with their evidence.
  - The `Layout` board's window row says one `Window` scene.
  - Published to [the canvas](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) as this item landed.
- **The docs**:
  - CLAUDE.md: what this is, the architecture, the UI section, the personal-only API, the Codebase Map's `ps1`, `session` and `player` rows, the products, and Code Style.
  - DEVELOPER: the tree, the `ps1`, `session`, `styles` and `player` entries, both apps, and the test table.
  - The Business card's Position, Modules and May-depend-on lines, and the Business tests card's conventions.

**Trade-offs.**

- **One isolation domain, not one thread.** ADR 0015 §4's "driven from one thread" is read as the session actor's isolation. Every call into the console (frames, power on, boot, reads) runs on the actor, one at a time and between frames. Every session method is synchronous on the actor, so nothing can enter between a frame's start and its end.
- **Pacing:**
  - The first frame comes a sixtieth after power on, resume or reset, so frame 0 can be seen.
  - A frame up to one frame late is caught up. One later than that restarts the pace from now, so a stall never becomes a burst.
  - Frames per second counts each whole second of running, and is 0 until a whole second has run and while paused.
- **The personal build counts every instruction and takes a debug snapshot each frame.** A review measured about 76 µs a frame for the snapshot even with a full 1 MB TTY. The personal routine compiles at `-Onone` (`apps/Config/Personal.xcconfig`, unchanged since v0.0.1), where the core benchmarks about 13 M instructions a second. A BIOS that runs more instructions a frame than that allows shows fewer than 60 frames a second there. The session reports what it measures. The App Store build and `istation-run` are optimized.
- **The App Store side of the session is compiled, not run, by the routine checks.** `swift test` runs the debug build, `PERSONAL_BUILD` included. The release path passed 23 session tests by hand (`swift test -c release -Xswiftc -enable-testing --filter BusinessSessionTests`). Adding that run to `cicd.sh` would lengthen CI and is the user's call.
- **Departures from the boards, at the Today level:**
  - While paused, the overlay replaces the "No picture yet" panel. With no picture under the scrim, the two would overlap.
  - Stop keeps the boards' chevron, but its label is "Stop" and its tip "Stop (⌘.)": there is no library to go back to until 5d.
  - Stop's alert has no Save First…, which comes with save states (5l).
  - Enter Full Screen sits in the Game menu, where the design's menus put it under View. AppKit's own View › Enter Full Screen still answers ⌃⌘F too; both reach the same state, and 5e's menus settle it.
  - In the shipped app nothing starts a run until 5c (Run the BIOS) and 5d (opening a PS-EXE), so the toolbar and the Game menu stay disabled. Their behaviour is proved by the view-model tests and seen in the previews.

**Verified** (2026-11-22):

- `lib/scripts/cicd.sh --app darwin --test` in the item's worktree passed (exit 0): the strict build, `swift test` (372 tests in 12 runs, up from 309 in 11; `BusinessSessionTests` 26, `PresentationPlayerTests` 38, up from 1) and both apps' personal routine, for macOS and the iOS Simulator.
- `swift build -c release --explicit-target-dependency-import-check=error` is clean.
- A review built the macOS App Store routine (Release) with no warnings.
- The `macOS Personal` scheme's `xcodebuild test` passed the session and player tests.
- The Thread Sanitizer reported nothing over the player tests and the session suite.
- Repeat runs: the session tests passed 20 times in a row, and 20 more with four test processes running at once. The player tests passed 20 times in a row.
- Probes over a code-built BIOS:
  - In real time, the release session reached frames 60, 120 and 180 at 1.005, 2.003 and 3.004 s. Pause held frame 180 over 300 ms; resume carried on, reset went to 0 and stop released the console.
  - 800 controls sent from 8 tasks at once left exactly one loop.
  - A session let go without `stop()` ended its loop and finished its streams.
- Mutations, each restored:
  - The loop going on after pause, or the EXE not given at power on: 7 session tests failed.
  - Asking without pausing, Reset's Details losing the `boot(exe:)` line, or stopping without leaving full screen: 9 player tests failed.
  - Unchained controls, or the catch-up rule disabled, were each caught.
  - Reverting the review's three view-model fixes failed 8 checks.
  - The layer-order check pointed at an ADR 0024 copy with Data and Business swapped failed.
- **The boards, rendered.** A throwaway test, not committed, rendered each state's view in the light, dark and high-contrast themes. They were compared in the built-in browser with `Mac-TodayPlayer`, `Mac-PlayerPaused`, `Mac-PlayerFullscreen`, `Mac-ResetConfirm`, `Mac-StopConfirm`, `Mac-PlayerMin` and `Mac-PlayerRunning`'s HUD.
  - The HUD, the panel, both alerts with their Details, full screen's Pause and Exit buttons and the fit at 800 × 560 match at the Today level, with the departures above.
  - Window chrome (the title and the toolbar) doesn't render to an image; the six "Window, …" previews show it in Xcode's canvas.
- `node tools/check.mjs` and `--render` pass: 54 contract rows (21 ready, 11 app, 19 gaps, 3 verify), 137 pages. The docs validator is clean on a copy of the worktree.

**Decisions consumed.**

- 2026-11-21: the design's Today parts are v0.1.0's; each screen's gaps get interface items, and the screens are gated on them (the user's calls).
- 2026-11-22 (the defaults, confirmed by the user):
  - the runner is a new Business module, `session`;
  - frames are paced by `ContinuousClock` at 60 a second until 6h reports the video standard, with frames per second shown without a target (G12);
  - one window, one console at a time;
  - Stop asks first and saves nothing;
  - Reset's and Stop's Details name the calls, with the kept file's own name in place of the design's placeholder.
- 2026-11-22 (the user's calls, before the group run): the design is published as the item lands; screens are checked against their boards by rendered previews.
- 2026-11-22 (made in the group run without the user, for the user's veto):
  - personal builds run the session on `PS1TracingConsole` with an instruction-counting tracer and optional BIOS putchar capture;
  - the session takes a PS-EXE with power on, boots it before the first frame, and Reset does both again.
- 2026-11-22, rulings made building it:
  - **The module's edges:**
    - The Session row also uses `BusinessR3000A`, because `InstructionCounter` is an `R3000ATracer`; it is imported only under `#if PERSONAL_BUILD`, and the import checks read it as text in every build.
    - The row's test support is `SupportMIPS`. The image builders the two harnesses share moved into `SupportMIPS` (`Programs.swift`); `makeBIOS` and `shellBIOS` stay in each harness, since a Support target can't use a module.
    - `BusinessSession` joins `PS1Core`, and the Player row uses it.
  - **Session states and controls:**
    - The session has a `.poweredOff` state before power on.
    - Power on works in any state and starts afresh. A wrong-size BIOS throws `PS1Error.biosSize` and changes nothing.
    - Reset also runs a paused session, as the prototype does; it does nothing powered off or stopped.
    - Stop ends the loop and releases the console. The stopped snapshot keeps where it stopped, with frames per second 0. Pause, resume and reset do nothing afterwards.
    - Putchar capture is a separate `powerOn` overload that exists only under `PERSONAL_BUILD`, and Reset keeps its setting.
  - **Snapshot streams:** each `snapshots()` call is a new stream that starts with the current snapshot, keeps only the newest when its reader lags, and finishes at the next `stop()`.
  - **Following a run:**
    - The player never powers anything on. A starter (5c, 5d) powers the session on, then calls `started(_:)`.
    - The player follows the session across a stop, taking the next stream once it shows Stopped, so either call order works.
    - A player let go cancels its follow.
    - Controls reach the session in the order given, and the player's state comes only from snapshots.
  - **Asking:**
    - Asking Reset or Stop always sends a pause, and Cancel leaves the game paused, as `main.html` does.
    - The paused overlay hides while a question is open.
    - One question at a time.
  - **The texts:**
    - They are `main.html`'s, including Reset's "The game starts again…" when only the BIOS runs.
    - Stop's title is "Stop playing <name>?" for a program and "Stop the BIOS?" for the BIOS; the Game menu keeps "Stop…", as the design's menu names it.
    - Numbers are grouped as en-US, not by the system locale, so Details are exact.
    - The rate is a whole number, hidden until a second has been measured.
  - **The window:**
    - While a run plays the window is titled with the run's name, and with the routine's title otherwise.
    - The toolbar hides in full screen, where the HUD carries Pause or Resume and Exit full screen (Esc).
    - Full screen sits in its own toolbar group in place of the board's separator.
    - Closing the window leaves the session as it is; 5d decides what closing does to a run.
    - The stopped screen says "Stopped. Nothing is running." until 5d's library takes its place.
  - **The HUD:** the name is one line, truncated, since the design's `max-width: 280px` has no token. The bar's shadow falls from its shape alone.
  - **Contract rows:** C06, C07, C08 and C50 are tagged ready, backed by the session's tests.
  - **The layer law's citations:** every live citation points at ADR 0024. ADR 0023's account of what the apps build is corrected in ADR 0024's Consequences rather than by a superseding record. Superseded ADRs keep their own references as history.
  - **The real-time test** asserts at most 60 frames a second (+2) and at least 15 over half a second after the first frame. The exact 60 is the `ManualClock` tests' proof.
  - **A Sony file's name** is never used in a test: the kept-file test uses `bios-backup.bin`.

## Milestone V — First run and the BIOS

**Goal.** v0.1.0 item 5c: the first thing the Mac app needs is the user's own BIOS. Until now the app opened on a player that said "Nothing to play yet." and offered no way to choose one. This item builds the design's first run: Welcome, written for someone who has never heard of a BIOS; the BIOS check job (read the file, check its size, work out its SHA-1, power on and run 60 frames, then run on until the BIOS reaches its shell, refused at frame 600), with its Stop; the wrong-size and no-shell refusals; and the BIOS pane, with Run the BIOS. The BIOS is kept by a bookmark, never copied, and the App Store bookmark question (contract row C11) is prepared as a probe for the user to run.

**Built** (5c, 2026-11-22):

- **Data, the new module `library`** (`lib/src/darwin/source/data/library/`, iStation's own code, `Module(.data, "Library", testSupport: ["SupportSandbox"])`; `DataLibrary` joins the `EmuKit` product):
  - `Library.swift`: `Library` (`currentVersion` 1; `version`, required; `bios: BIOSRecord?`) and `BIOSRecord` (file name, folder, size, SHA-1, checked date, bookmark), every field decoding with a default.
  - `LibraryStore.swift`: `LibraryStore(url:)`, a synchronous, stateless `Sendable` struct over a versioned `library.json` at the URL the app hands in: `load()`, `save(_:)` (atomic, its folder made), `keepBIOS(_:)`, `forgetBIOS()` and `LibraryStoreError`. A corrupt, foreign, version-less or later-version file is refused and never saved over.
  - `Fingerprint.swift`: `Fingerprint.sha1(of:)`, CryptoKit's `Insecure.SHA1` as 40 lowercase hexadecimal digits.
  - `KeptFile.swift`: `bookmark(for:)`, `resolve(_:)` (with a stale flag), `size(at:)` (without reading, a symbolic link sized as its target) and `bytes(at:)`, each inside the file's security-scoped access; on macOS a security-scoped bookmark first and a plain one when the sandbox refuses it, plain on iOS.
- **Business, `session`**: `ConsoleSessionPowerControls.swift`, the protocol a starter drives (`ConsoleSessionControls` plus `powerOn(bios:exe:) async throws(PS1Error)` and `snapshot`); `ConsoleSession` conforms. The session harness's `Ticks` and `eventually` take any conforming session.
- **Presentation, the new place `bios`** (`lib/src/darwin/source/presentation/bios/`, `Module(.presentation, "BIOS", uses: ["BusinessPS1", "BusinessSession", "DataLibrary", "PresentationStyles"], testSupport: ["SupportSandbox"])`, in `EmuKit`, with its own shared scheme `PresentationBIOS`):
  - `Models/`: `BIOSStorage` and the app's `LibraryBIOSStorage` (the one way both view-models reach files), `BIOSRun`, `BIOSAlert`, and `BIOSText` (every sentence as `html/main.html` has it).
  - `ViewModels/BIOSCheckViewModel.swift`: the check over a console session of its own, never the player's, driving `JobSheet`'s `JobPresentation`; the chooser is the `Bool` `isChoosingFile`, bound to `.fileImporter`.
  - `ViewModels/BIOSPaneViewModel.swift`: the kept BIOS, its texts, Run the BIOS (the player's session powered on from frame 0, then the run handed to the player) and Show in Finder.
  - `Views/`: `WelcomeView`, `BIOSCheckSheet.swift` (`biosCheck(_:)`: the system's chooser, with the design's message and "Choose", and the job sheet), `BIOSPaneView` and, on macOS, `BIOSCommands` (File › Choose BIOS File… ⌘O while no BIOS is kept; Console › Run the BIOS).
  - `Previews/PreviewBIOS.swift`: a scripted preview session (no console; it sends the snapshots a preview asks for) and in-memory storage (a file of the size a preview asks for, whose read or keep can fail), and fifteen named previews, each reached through the view-models' initializers and intents: Welcome, Picker, Minimum size, Checking, Reaching the shell, Wrong size, No shell, Done, Stopped, Couldn’t read, Couldn’t keep, and four of the pane.
- **`styles`**:
  - `Models/Figures.swift`: `Figures.grouped(_:)`, the design's grouping of numbers by thousands, promoted from the player now that the BIOS screens use it too.
  - `Metrics.layout` gains `welcomeWidth` (460) and `paneMaxWidth` (720), from two new tokens in the design's `json/tokens.json` (`size.mac`, and 390 for both in `size.ios`), pinned by `TokensTests`.
- **`player`**: `playerWindow(_:idleTitle:)` is split into `playerChrome(_:idleTitle:)` and `playerFullScreen(_:)`, so the macOS app keeps full screen at the window's root while Welcome, the pane or the player shows; `playerWindow` is still the two together.
- **The macOS app** (`apps/macos/Sources/iStationApp.swift`): it builds the library at `<Application Support>/<bundle id>/library.json`, the player's session, a second session for the check, and the view-models. The window shows the player while a run plays, else the BIOS pane once a BIOS is kept, else Welcome; the check's chooser and sheet and the player's full screen sit around them. The File menu's empty New group gives way to Choose BIOS File…. The iOS app compiles the new modules through `EmuKit` and mounts neither: the iPhone's first run is 5n's.
- **The bookmark probe** (`lib/src/darwin/tools/bookmark-probe/`, never shipped): a one-file sandboxed SwiftUI app (`Sources/BookmarkProbe.swift`) that keeps a security-scoped bookmark to a file the user picks and reports, after a relaunch, whether it still opens. `build.sh [appstore|appscope]` signs it ad-hoc under its own identifier, `local.istation.bookmark-probe` (the control, `….appscope`, adds `com.apple.security.files.bookmarks.app-scope`), and refuses to build while its `AppStore.entitlements` differs from the app's. Its README holds the user's run and its results table. The Xcode project's `tools` group shows it.
- **Tests**:
  - `tests/data/library/`: `LibraryStoreTests`, `FingerprintTests` and `KeptFileTests` (27, in a `Sandbox`), with two fixtures in `Fixtures/`: `library-v1.json`, the recorded version-1 shape, and `library-v1-no-checked.json`, a version-1 record missing a field. `Package.swift`'s new `testFixtures` table keeps them out of the test target; the tests read them by `#filePath`.
  - `tests/business/session/PowerControlsTests.swift` (6), through the protocol alone.
  - `tests/presentation/bios/`: `BIOSCheckViewModelTests`, `BIOSPaneViewModelTests`, `BIOSTextTests` and `LibraryBIOSStorageTests` (50), over `Fakes.swift`'s scripted `FakePowerSession` (which can hold a power-on or a stop) and in-memory `FakeStorage`; every wait ends after two seconds.
  - `tests/presentation/styles/FiguresTests.swift`.
  - `DataLibraryTests` and `PresentationBIOSTests` join the `macOS Personal` scheme.
- **The design**, in its mirror and published to [the canvas](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) as this item landed:
  - `Mac-Welcome`'s copy and `Mac-BiosPane`'s note take the decided wording: what a BIOS is, and the one sentence of guidance.
  - The no-shell refusal: the `bios-no-shell` preset, a third file in the picker (`bios-copy.bin`), the failed job's summary and Details, and the new board `Mac-BiosNoShell` (66 boards); the First run flow in `tools/check.mjs` runs it to its refusal.
  - `Layout`'s First run row has "No shell in 600 frames" as its Refused cell; `Processes`' "Check a BIOS" runs until `reachedShell`, refused at frame 600.
  - `Contract`: C09 is tagged ready; C01, C02, C05 and C10 name 5c's calls; C11 and C47 stay verify; C38's note is narrowed to Welcome; CALLS drop Audience and BIOS guidance; DECISIONS and EVIDENCE gain 5c's. Of 54 rows, 22 are ready, 10 app, 19 gaps and 3 verify.
- **The docs**: CLAUDE.md (what this is, the UI section, the Codebase Map's `library` and `bios` rows, the products, the checklist), DEVELOPER (the tree, `library`, `session`, `styles`, `player`, `bios`, both apps, the test table, the persisted-format recipe), the Data, Business and Presentation cards and their tests cards, ADR 0002's table, `reference/darwin/README.md`'s note that today's `library.json` is a new format, and the root README's Status.

**Trade-offs.**

- **The App Store build's bookmarks are unproven.** Its entitlements hold `com.apple.security.files.user-selected.read-only` but not `com.apple.security.files.bookmarks.app-scope`. `KeptFile` makes a security-scoped bookmark and, when the sandbox refuses one, a plain one, so the App Store build may lose the BIOS across a relaunch until the probe's run settles C11. The personal build is unsandboxed, where both kinds of bookmark resolve.
- **The check runs on its own console session.** The player follows its session across a stop (5b), so a check on that session would hand the window to the player. The macOS app builds a second `ConsoleSession` for it, released at every ending.
- **A no-shell BIOS keeps the check running for about nine seconds** after frame 60, until frame 600, at 60 frames a second. The design shows a spinner on "Reach the BIOS’s shell" for that time. In the personal build, compiled at `-Onone` (Milestone U), it can take longer.
- **Departures from the boards, at the Today level:**
  - Continue lands on the BIOS pane, not the empty library (`Mac-LibraryEmpty`): the library is 5d's. Until then the pane is the window's one place, so there is no sidebar and no ⌘6, and the Console menu holds only Run the BIOS.
  - The chooser is the system's: it shows the design's message and "Choose", but no title, since SwiftUI's file chooser takes none.
  - Welcome's disc and the pane's chip have no size tokens; they use `Typography.screenSymbol` and `.largeTitle`, so they draw a little larger than the boards'.
  - A wrong-size file is refused before it is read, so its Details are built from the console's own error for that size rather than thrown by a call; a test pins the text to what a real `ConsoleSession` throws.

**Verified** (2026-11-22):

- `lib/scripts/cicd.sh --app darwin --test` in the item's worktree passed (exit 0): the strict build, `swift test` (456 tests in 14 runs, up from 372 in 12; `DataLibraryTests` 27, `PresentationBIOSTests` 50, `BusinessSessionTests` 32, up from 26) and both apps' personal routine, for macOS and the iOS Simulator.
- `swift build -c release --explicit-target-dependency-import-check=error` is clean, and the new suites pass in release (`swift test -c release -Xswiftc -enable-testing`).
- Repeat runs: the new suites passed 12 times in a row, and 6 more with 32 busy loops loading a 16-core machine.
- Two reviews (the item's letter; invariants, concurrency and quality), a fixer, then three independent verifiers (the fixer's changes; each acceptance criterion, guardrail and decision; the invariants). They found no regression. The one Important finding of the last pass, previews that assigned the check's state (ADR 0021 §3), was fixed and checked again by an agent told to refute the fix.
- The bookmark probe: `build.sh` and `build.sh appscope` sign their bundles (exit 0) with the expected identifiers and entitlements, and an unknown variant exits 2. Neither was launched.
- Mutations, each restored, were caught by the tests: the check's releases of its console, the store's refusals, the done sheet's hand-off, the chooser behind a sheet, Stop while reading, while powering on and while the console is released, a check waiting for the stop before it, and the symbolic-link sizing. Not caught, and recorded: the atomic save, the security-scoped access while unsandboxed (the probe's question), a Stop during the fingerprint, and the version stamp while only version 1 exists.
- **The boards, rendered.** A throwaway test, not committed, rendered Welcome, the pane and every state of the check in the light, dark and high-contrast themes. They were compared in the built-in browser with `Mac-Welcome`, `Mac-BiosChecking`, `Mac-BiosWrongSize`, `Mac-BiosNoShell`, `Mac-BiosDone` and `Mac-BiosPane`: the words, their wrapping, the column widths, the steps, the summaries, the Details and the buttons match, with the departures above; Welcome and the pane fit the window's minimum of 800 × 560.
- `node tools/check.mjs` and `--render` pass: 66 presets, eight flows, 29 shortcuts, 73 boards, 139 pages, 54 contract rows (22 ready, 10 app, 19 gaps, 3 verify). The docs validator is clean on a copy of the worktree.
- A search of `source/` and `apps/` finds no networking API (URLSession, URLRequest, NWConnection), as contract row C47 says.

**Decisions consumed.**

- 2026-11-21: the design's Today parts are v0.1.0's, moving BIOS import from v0.2.0 into v0.1.0; each screen's gaps get interface items, and the screens are gated on them (the user's calls).
- 2026-11-22 (the user's calls): the welcome copy is for App Store strangers, as the design has it; the BIOS guidance is one plain sentence (the file comes from your own console, iStation can't provide one, and it expects a 512 KB file), naming no tool, method or link.
- 2026-11-22 (the defaults, confirmed by the user):
  - a bookmark is probed across relaunches under the App Store routine first, and `com.apple.security.files.bookmarks.app-scope` joins the macOS App Store entitlements only if the probe needs it, which closes C11's verify for macOS;
  - the app's fingerprint is SHA-1, shown in groups of four; the gate's reports keep a BIOS's size and SHA-256;
  - a BIOS that hasn't reached its shell by frame 600 is refused with "Your BIOS powered on but didn’t reach its shell in 600 frames. Choose another file." and nothing is kept, and the design gains its preset and board.
- 2026-11-22 (the user's calls, before the group run): the design is published as the item lands; screens are checked against their boards by rendered previews; the bookmark probe is prepared, not run, and the item ships with the app-scope entitlement off, the user's run deciding it.
- 2026-11-22, rulings made building it:
  - **The library file:**
    - Every `BIOSRecord` field decodes with a default (`""`, `0`, `Date.distantPast` for `checked`, empty `Data`); a field of the wrong type is still an error.
    - `version` is required. Missing, not an integer, or below 1 is `notALibrary`; above `currentVersion` is `newerVersion`, and the file is never saved over. `keepBIOS` and `forgetBIOS` load first, so they refuse too; `save` writes unconditionally.
    - A save writes `currentVersion` whatever version was read and drops keys the build doesn't know, so a change that adds a field raises `currentVersion` and a build from before it refuses the file instead of erasing the field (5d's games are the first).
    - Dates are kept to the whole second.
    - The fixtures: `library-v1.json` is the recorded shape, pinned both ways; `library-v1-no-checked.json` is a made-up version-1 record standing in for an older shape, since none exists yet.
  - **Kept files:**
    - On macOS a bookmark is made with the security scope, and plainly when the sandbox refuses that; resolving tries the scope first, then plainly (a plain bookmark fails with the scope as Cocoa error 259, measured). These stay as they are until the probe's run; its README says what follows each outcome.
    - `size(at:)` sizes a file without reading it, a symbolic link as the file it leads to.
  - **The session protocol** has no default `exe:` and no overload, so it never clashes with `ConsoleSession`'s own `powerOn`: callers through it pass `exe: nil`.
  - **The bookmark probe:**
    - The control has its own identifier, `local.istation.bookmark-probe.appscope`, so the two variants' containers never mix.
    - The first attempt is `.withSecurityScope`, as `KeptFile` makes it; the read-only option is tried second, as a diagnostic.
    - If both variants open, C11's macOS verify is dropped; both stay as they are only if the run is inconclusive.
    - Its version is `1.0`, so release sweeps don't take it for a carrier.
  - **The check:**
    - A file of another size is refused before it is read, by comparing `KeptFile.size(at:)` with `PS1Bus.biosSize`, so a disc image picked by mistake is never read whole.
    - "Read the file" shows its detail once the size is known.
    - A shell reached before frame 60 waits for the 60; a shell reached in the snapshot that reaches frame 600 counts; the refusal comes at the first snapshot at or past frame 600.
    - Three failed states the design doesn't draw use the same sheet, with Cancel and Choose Another File…: a file that can't be read ("The BIOS couldn’t be read. Choose another file."), a BIOS the library can't keep, and so an unreadable `library.json`.
    - The record is written at Done, right after the check's console is released with no suspension between, and handed on at Continue; its checked date is rounded down to the second, its folder the file's parent and its name the last path component.
    - Behind the sheet, Choose BIOS File… (⌘O), Welcome's button and Choose Another BIOS… do nothing, as the design's keys do nothing under a sheet; the sheet's own buttons choose again, and choosing from the Done sheet hands the kept BIOS on first.
    - The menus and the presenter read `isShowingJob`, from the state alone, so they aren't redrawn every frame.
    - The sheet keeps its last job while it closes, and the chooser opens only once no sheet is on screen, so a refusal's Choose Another File… and a stop's Check Again open it after their sheet has gone. Whether SwiftUI would have opened it while the sheet closed couldn't be seen without launching the app.
    - The previews reach every state through the view-models' intents over scripted preview fakes, never by setting it (ADR 0021 §3); a fingerprint they show is worked out from the preview's own bytes.
  - **The pane:**
    - Dates are written en-US ("Nov 20"; "Today" on the day; another year's with its year); a check the library didn't date reads "Checked: it reached its shell."; a missing fingerprint "SHA-1 unknown"; a missing folder "In an unknown folder".
    - Folders under the account's home are written from "~"; the app reads home with `getpwuid`, since the sandbox reports its container as home.
    - Run the BIOS sizes the file before reading it. A file that can't be found or read, or is no longer a BIOS's size, opens an alert with OK and powers nothing on. A stale bookmark is made again and the record kept again with the file's name and folder now.
    - Run the BIOS is disabled while a run plays, the chooser or the check's sheet is open, or a start is under way.
    - The previews' Show in Finder reaches nothing.
  - **The window:** Continue lands on the BIOS pane until 5d's library; there is no ⌘6 until 5d's sidebar and 5e's menus; a run's end still leaves full screen, as 5b has it, even when the person put the pane there.
  - **The design:**
    - Welcome keeps "iStation plays PS1 games on your Mac." as its lead, and the guidance is its own paragraph.
    - `iOS-Welcome` keeps its old copy, "a 512 KB file you copy from a console you own", until 5n, whose document already gives it 5c's words.
    - At the Today level a no-shell file is accepted and kept, since the Today backend can't tell.
    - The shell step has no detail and no progress bar; the no-shell Details name `PS1Console.reachedShell`, as the wrong-size Details name `PS1Console.powerOn(bios:)`.
    - The canvas wraps the First run row's seventh board and moves what is below it down 920; the Contract board is 8000 tall.
    - The first-run flow was extended rather than a ninth added.
    - Welcome's and the pane's columns take two new size tokens rather than the sheet's width.
    - C47 stays verify until a `ProjectRulesTests` rule enforces it; a new standing rule needs its own ADR, so none was added here.
  - **What stayed as it was:** `noRealHome` is not widened (ADR 0019 records its four names; the app's `getpwuid` is in `apps/`, which the rule allows); 5b's real-clock floor test is unchanged; ADRs are left as written, so ADR 0024 still names EmuKit as the player and the acknowledgements.

## Milestone W — The library of files

**Goal.** v0.1.0 item 5d: once a BIOS is kept, the design's library is the Mac app's home. Until now the BIOS check's Continue landed on the BIOS pane, the window's one place, and a game could not be added. This item builds the library to the design's Today level: a sidebar (All Games ⌘1, Recently Played ⌘4, BIOS ⌘6), a table and a grid of games, and Game info (⌘I); Add Games… (⌘O) and Add Folder… (⇧⌘O), the latter a job with steps, Stop, and a Scan Again that adds nothing twice; search, rename, Remove from Library… with what it deletes under Details, and Locate… for a file that has gone. Games are kept by bookmark in `library.json`, now at version 2. Disc images (.cue, .iso, .m3u) are listed by name, format and size, with Console and Serial "Unknown" and Play off ("Discs play from v0.2.0."), because the readers of a disc's contents (`iso9660`, `systemcnf`) aren't in a product the app links (G2) and the console has no CD-ROM drive (G9). A PS-EXE plays: a three-step opening job powers the player's session on with the BIOS and the program, then hands the run to the player.

**Built** (5d, 2026-11-23):

- **Data, `library` at version 2** (`lib/src/darwin/source/data/library/`). Its row is now `Module(.data, "Library", uses: ["DataPlaylists"], testSupport: ["SupportSandbox"])`, so `EmuKit` links `DataPlaylists` through it.
  - `Library.swift`:
    - `currentVersion` is 2.
    - `games` decodes to none when absent, so a version-1 file loads with no games.
    - A record whose id repeats an earlier record's gets an id of its own on load (`identified(_:)`).
    - `BIOSRecord.moved(to:bookmark:)` is new.
  - `GameRecord.swift`:
    - `GameFormat`: `.cue`, `.iso`, `.m3u`, `.psexe` (written "exe") and `.unknown(String)`, which is kept rather than refused. It has `fileExtensions`, and `init?(fileName:)` reads the extension in any case.
    - `GameRecord`: id, file name, folder, format, size, added, last played, a library-only `name`, bookmark, a .cue's `tracks` and an .m3u's `discs`. Every field decodes with a default. It also has `shownName`, `path` and `standardizedPath(of:)`.
  - `LibraryGames.swift`: `Library`'s own changes, which the store and the test fakes share: `game(_:)`, `game(at:)`, `add(_:)`, `rename(_:to:)`, `remove(_:)`, `markPlayed(_:at:)`, `relocate(_:to:)`, and `relocate(_:)` for a batch.
  - `LibraryStore.swift`:
    - New calls, each one load and at most one atomic save: `addGames(_:)` (returning `Added`: the library and the games added), `renameGame(_:to:)`, `removeGames(_:)`, `markPlayed(_:at:)`, `relocateGame(_:to:)` and `relocateGames(_:)`.
    - `LibraryStoreError` gains `noSuchGame` and `alreadyKept(path:)`.
  - `KeptFileReading.swift`:
    - The `KeptFileReading` protocol (`resolve`, `size(of:)`, `bytes(of:)`) and `KeptFileReader`.
    - `whereabouts(of:)`: a game's file is `.found`, `.moved` or `.missing`.
    - The BIOS read that the BIOS pane and the opening job share: `readBIOS(_:expectedSize:)` returns a `KeptBIOS` or throws a `KeptBIOSError` (`cannotFind`, `cannotSize`, `wrongSize`, `cannotRead`).
  - `GameFiles.swift`:
    - `find(in:)`: a folder's games in path order, less the files that come with another game (`withoutParts(_:)`, with `ringHeads(of:parts:)` for playlists that list each other). Those are a .cue's tracks, an .m3u's discs and their tracks, matched by file identity.
    - `record(for:added:)`: a file's record, with the game's whole size and its parts' names, read through `Playlists`.
    - `playlistLimit` (1 MiB).
- **Presentation, the new place `library`** (`lib/src/darwin/source/presentation/library/`). Its row is `Module(.presentation, "Library", uses: ["BusinessPS1", "BusinessSession", "DataLibrary", "PresentationStyles"], testSupport: ["SupportSandbox"])`. It is in `EmuKit`, has its own shared scheme `PresentationLibrary`, and its views are macOS-only.
  - `Models/`:
    - `LibraryStorage`, which refines `KeptFileReading` and whose `record(for:added:)` is async, and the app's `LibraryStoreStorage`.
    - `GameRun`, the run the library hands on.
    - `LibraryPlace`: All Games, Recently Played and BIOS, in the Library and Console sections, at ⌘1, ⌘4 and ⌘6.
    - `LibraryAlert`.
    - `LibraryLayout`: the sidebar and the table's columns, from the window's width.
    - `GameRow` and `GameInfo` (`GamePresentation.swift`).
    - `GameFileTypes`: the four imported types, and the choosers' list from `offered(imported:lookUp:)`.
    - `LibraryText`.
  - `ViewModels/LibraryViewModel.swift`: everything else the window does, over `LibraryStorage`. That covers places, selection, search, list or grid, Game info, the sidebar, Add Games…, rename, remove, Locate…, Show in Finder and the check for files that moved or went missing. Other screens' sheets reach it through `isCovered`, and the window switch reads `playerHoldsWindow(whilePlaying:)`. It builds and owns the other two view-models.
  - `ViewModels/ScanViewModel.swift`: Add Folder…'s job through `JobSheet`: Find disc images, then Read each disc, then Add them to your library. It has Stop, Scan Again and the design's tally.
  - `ViewModels/OpeningViewModel.swift`: a PS-EXE's opening job through `JobSheet`: Open the file, then Power on with your BIOS, then Start the program. It runs over 5c's `ConsoleSessionPowerControls`, on the player's session. It has `shellDeadline` (600), `largestProgram` (2,099,200 bytes) and `isStopping`.
  - `Views/`:
    - `LibraryView`: a `NavigationSplitView` of `LibrarySidebar`, then either the games or the BIOS pane, which the app hands in through a view builder. The games have their toolbar, `.searchable` and an `.inspector` holding `GameInfoView`.
    - `GameTable`, `GameGrid` (`LazyVGrid`), `GameInfoView`, `LibraryEmptyView` and `LibrarySheets.swift` (Rename, the alerts, the scan and opening sheets, the choosers).
    - `LibraryCommands`: the File, View and Edit items. `LibraryMenuItem` puts Play in the Game menu and BIOS in the Console menu.
  - `Previews/PreviewLibrary.swift`: a scripted preview session and in-memory storage (`PreviewLibrarySession`, `PreviewLibraryStorage`, with `PreviewGate` to hold a scan on a file), and the states the views' 37 named previews draw: every board state and the opening job, each reached through the view-models' initializers and intents.
- **`styles`**:
  - `Models/`: `Dates.day`, `Folders.shown` and `Details.threw`, promoted from the BIOS pane now that the library uses them too.
  - `Metrics.layout` gains thirteen members from thirteen new size tokens, pinned by `TokensTests`:
    - the Layout page's breakpoints (`formatColumnMinWidth` 880, `lastPlayedColumnMinWidth` 700, `sidebarWithInfoMinWidth` 1,100);
    - the table's six columns;
    - Game info's `infoArtHeight` and `factNameWidth`;
    - the empty library's `emptyWidth`;
    - `gamesMinWidth`.
  - `Components/`:
    - `PresentedJobSheet` moves here from `bios`.
    - `DetailsAlert` never truncates a button title, and gains the "Long titles" preview.
    - `JobSheet` gains a "Presented" preview.
- **`player`**: `PlayerCommands(viewModel:isActive:leading:)` puts the library's Play first in the Game menu. Its own items act only while the player holds the window, and the old initializer is kept. Stop reads "Stop and go back to the library".
- **`bios`**:
  - `BIOSStorage` refines `KeptFileReading`.
  - Run the BIOS reads through `readBIOS(_:expectedSize:)` in one detached task, with its texts unchanged.
  - `BIOSCommands(check:pane:isPlaying:consoleItems:)` carries ⌘6.
  - The check's sheet uses `PresentedJobSheet`.
- **The macOS app** (`apps/macos/Sources/iStationApp.swift`):
  - The app builds one `LibraryStore` for the BIOS screens and the library alike, and the `LibraryViewModel`. It maps the library's `GameRun` to the player's `PlayerRun`, as it maps `BIOSRun`. `isCovered` is wired to the check's chooser and sheet, the pane's alert, and Run the BIOS while it starts.
  - The window shows the player while it holds the window, else the library once a BIOS is kept, else Welcome. The library lands on All Games.
  - `PlayerCommands`, `BIOSCommands` and `LibraryCommands` make the menus.
  - The new `apps/macos/Info.plist` holds only `UTImportedTypeDeclarations`, set as the macOS target's `INFOPLIST_FILE`, with no `DEVELOPMENT_TEAM`. It imports `local.istation.cue-sheet` (.cue), `local.istation.disc-track` (.bin), `local.istation.disc-playlist` (.m3u) and `local.istation.ps-exe` (.exe).
  - The iOS app compiles the new modules through `EmuKit` and mounts none of them. The iPhone's library is 5n's.
- **Tests**:
  - `tests/data/library/` (`DataLibraryTests` 103, up from 27): `GameRecordTests` (11), `LibraryGamesTests` (20), `KeptFileReadingTests` (13) and `GameFilesTests` (28), with `LibraryStoreTests` grown to 18. The new fixture `Fixtures/library-v2.json` is the recorded version-2 shape.
  - `tests/presentation/library/` (`PresentationLibraryTests` 101), over `Fakes.swift`: the in-memory `MemoryStorage`, whose held records wait at `HeldCalls` suspended, holding no thread, and the scripted `FakePowerSession`.
    - `LibraryViewModelTests` (46), `ScanViewModelTests` (17), `OpeningViewModelTests` (21) and `LibraryTextTests` (7).
    - `LibraryStoreStorageTests` (4), which uses real files in a `Sandbox`.
    - `GameFileTypesTests` (2), which uses a scripted type lookup and reads `apps/macos/Info.plist`.
    - `PreviewLibraryTests` (4), debug builds only.
  - `BIOSPaneViewModelTests` gains one test, so `PresentationBIOSTests` has 51; `DatesTests`, `FoldersTests` and `DetailsTests` join `styles`; `TokensTests` checks the thirteen keys.
  - `PresentationLibraryTests` joins the `macOS Personal` scheme.
- **The design**, in its mirror and published to [the canvas](https://claude.ai/artifact/LA2jv631Ar184Dviuju8hu) as this item landed:
  - `json/tokens.json`: the thirteen size tokens for both platforms, and the `size.*` note. `node tools/sync.mjs` wrote them into `main.html` and the TOKENS copies of the Contract, Exploration, Foundations-Color, Foundations-Components, Foundations-Type, Layout and Processes boards.
  - `Contract`:
    - C12, C13, C20, C51, C52 and C53 go from app to ready. C16 and C17 go from gap to ready, keeping their G2 id.
    - C11 stays verify with a new note. C18, C19 and C47 get new notes, and G2's text says Playlists already ships.
    - DECISIONS gains three entries and two confirmations, and the call "Scope before discs play." is retired. EVIDENCE gains 5d's block.
    - Of 54 rows, 30 are ready, 4 app, 17 gaps and 3 verify.
  - `Processes`: "Add a folder" and "Play a PS-EXE" describe 5d, as do the rows for the library file and bookmarks. `Layout`: the library's Error state reads "File missing".
  - `main.html`:
    - Remove has its Today wording.
    - The missing-file Details are the recorded ones.
    - The Today scan adds every file not already kept, with three backups as `SCAN_TODAY_GAMES`, and tallies "Added 7 games. 2 already in your library."
    - `initialState` applies the level before the preset as well as after.
  - `tools/check.mjs`: the today flow also checks the Today removal wording and the Today scan. There are still eight flows.
- **The docs**:
  - CLAUDE.md: what this is, the UI section, the view-model rules' examples, the Codebase Map's Data `library` row and the new Presentation `library` row, the products line and the checklist.
  - DEVELOPER: the tree, the Data `library` entry, `styles`, `player`, `bios`, the new `library` entry, both apps and the test table. Version 2 is now the persisted-format recipe's worked example.
  - The Data and Presentation cards and both tests cards.
  - ADR 0002's rows and its "The table as of" note.
  - `reference/darwin/README.md` (version 1 is 5c's, version 2 is 5d's).
  - The root README's Status.
  - The Seam line for Tools (⌘7) in 5f's `personal-tools.md`.

**Trade-offs.**

- **Discs are listed, not read.** At the Today level a disc has a name, a format and a size, and every file the scan finds that isn't already kept is added, since nothing reads SYSTEM.CNF before 5h. 5h fills in console and serial; 5i plays discs.
- **The App Store build's access is unproven.** As in 5c, the entitlements hold `com.apple.security.files.user-selected.read-only` but not `com.apple.security.files.bookmarks.app-scope`, so contract row C11 stays verify until the bookmark probe's run. 5d adds two questions for that run:
  - Does a game's bookmark, made inside a folder's access, survive a relaunch?
  - Can a .cue chosen alone through Add Games… reach its .bin tracks? If it can't, the game's Size is the cue sheet's own few bytes, because a part that can't be sized counts nothing (the refute pass's P-4).
  - P-4 is left unfixed. Tests don't run sandboxed, and a fix would change what a record's size means or which types the Info.plist declares. 5h and 5i need sandboxed access to a .cue's tracks anyway, so it goes with C11.
- **The scan saves once per added file.** Each save is one load and one atomic save of `library.json` on the main actor. With 1,000 games kept, one such change took 15 ms (the second review's `addGames`) to 26 ms (the refute pass's, with real bookmarks), measured. Batching would change what Stop keeps and when each game shows. The file check is different: it stalled the window for 4 seconds over a moved folder of 400 games (measured), so it now keeps every moved game in one save.
- **Left unfixed, with the reasons:**
  - **Bookmark calls on the main actor (P-2).** Show in Finder resolves its bookmark there, and the opening job makes a moved BIOS's bookmark again there. Each is one call, on a click or once per moved BIOS, as 5c's pane does. Moving them would change Show in Finder's API with nothing here to test it, so they go with the pane's in a Maintenance pass.
  - **Keys with another window key (P-3).** Return and ⌘⌫ may act on the main window's library while the Acknowledgements window is key, since AppKit offers a key equivalent the key window doesn't handle to the main menu. The fix needs the window's key state, which the offscreen harness can't give (its window is never key), and a wrong gate would turn Play off everywhere.
  - **5b's `PreviewPlayer` (invariants F4).** It reaches its states through the player view-model's internal `show(_:)`, against ADR 0021 §3, and ADR 0021's example of it is out of date. It is 5b's code, not 5d's, so it belongs in a Maintenance item.
  - **Reads that can't be cancelled.** The opening job's program and BIOS reads, the BIOS pane's read and Locate…'s record aren't linked to their owner's cancellation: each is one synchronous read that can't notice a cancel.
  - **Two layout effects at small widths.** At 800 × 560 with Game info open, the table's four columns need 519 points against 500, so a horizontal scroller shows. Opening Game info under 1,100 leaves the games' inner split at its old width afterwards. The code before the window fix does both, and a plain split view does the second.
  - **Many hard links to one file.** Choosing among a file's hard links compares a part with each of them, so a playlist listing thousands of names of one file grows quadratically: 10,000 took 7.4 seconds against 3.4 before the fix (measured, release). No real library holds that.
  - **6c's document.** It still proposes a DiscKit product for the readers and scopes C14–C17. With `playlists` already in `EmuKit`, its default and scope need revisiting.
- **Never checked in the real app**, which no one launched, by the user's call to check screens by rendered previews:
  - The real window's title. It should read "All Games": a harness shaped like the app's `Window` scene draws it, and the "Untitled" one harness showed came from how that harness built its window.
  - The window fix in the real window. The harnesses only approximate SwiftUI's scene window: offscreen, never key, and resized in steps rather than live.
  - macOS 14, the deployment target: Search off, and Return and ⌘⌫ in the search field. No machine here runs it.
  - The choosers: whether they gray out a game's file, given that an imported type yields to the system's.
  - Return and ⌘⌫ while another window is key (P-3).
  - The App Store sandbox's sizing of a .cue chosen alone (P-4).
  - The player's frames counting after a PS-EXE's hand-off.
  - The toolbar's order, the window widening as the sidebar comes back, and how ⌘P is routed under a real sheet (inferred from how SwiftUI enables commands).
  - The macOS App Store routine wasn't built.
- **Departures from the boards and the spec** are listed under Decisions consumed, for the user's veto.

**Verified** (2026-11-23):

- **The full run.** `lib/scripts/cicd.sh --app darwin --test` passed (exit 0) on the final tree, after the folder search's last fixes:
  - the strict build;
  - `swift test`: 640 tests in 15 runs, up from 456 in 14. Among them are `DataLibraryTests` 103 (up from 27), the new `PresentationLibraryTests` 101, `PresentationBIOSTests` 51 (up from 50), `PresentationStylesTests` 57 (up from 51) and `ArchitectureTests` 34;
  - both apps' personal routine, for macOS and the iOS Simulator.
  - The only warnings are xcodebuild's, both of which predate 5d: the AppIntents notices and its choice among matching destinations.
- **Where the counts come from.** 640 is the sum of that log's fifteen run counts: the last verify pass's 632 (15 runs, passed twice) plus the eight tests the folder search's last fixes added to `GameFilesTests`. Earlier full runs gave 605 after the views were built, 622 after the first fixer and the window fix, 632 after the second fixer, and 636 and 639 along the last fixes.
- **Builds.** `swift build --build-tests --explicit-target-dependency-import-check=error` and the release build (`swift build -c release --explicit-target-dependency-import-check=error`) are clean on the final tree, with no warnings. `PresentationLibraryTests`, `PresentationStylesTests` and `PresentationBIOSTests` passed in release when the view-models were built (`swift test -c release -Xswiftc -enable-testing`), and weren't run in release again after the fixes; `DataLibraryTests` was never run in release.
- **Repeat runs.**
  - The library and BIOS suites passed 12 times in a row when the view-models were built.
  - The library, data, BIOS and styles suites passed 10 times in a row, then 4 times under 24 busy loops (second review).
  - The library, BIOS and data suites passed 5 times after the first fixer, and the library and data suites 5 more at the last verify pass.
  - The second review saw 5b's real-clock test `withTheContinuousClockFramesKeepToTheClockInsteadOfRacing` fail in 2 of 4 full runs of 5d's tree on a loaded machine. It passed in 4 of 4 full runs of the tree before 5d, 3 of 3 runs on its own, and every later full run. 5d touches neither the session nor its tests.
- **Reviews and verify passes.** The item had two reviews (the item's letter; invariants, concurrency and quality) and a fixer. An agent then took up the AppKit exception, three independent verifiers checked the work (each acceptance criterion, guardrail and decision; the invariants; one told to refute it), and a second fixer followed. A last verifier went over that fix, and its three findings (R1–R3) were fixed.
  - What mattered among their findings:
    - the window's AppKit exception;
    - a file check that stalled the window for seconds;
    - `PresentationLibrary` importing the `PresentationPlayer` feature, against ADR 0023;
    - the Game menu acting under the opening sheet;
    - Return and ⌘⌫ lost after a run when the search field had focus;
    - in the folder search: parts named in another case, playlists that list each other, rings of playlists, and hard-linked games.
  - Each is fixed, or recorded under Trade-offs.
- **Acceptance criteria.**
  - Met: the discs' "Unknown" and Play off; `swift test` and the strict build.
  - Met in the view-models, the renders and the harnesses, with the rest needing the app: adding, search, rename, remove, the grid, Game info and Locate… with their keys; a PS-EXE's opening job and hand-off; the breakpoints.
  - Reset booting the PS-EXE again is the session's, pinned by `ConsoleSessionTests.resetPowersOnAgainAndBootsTheSameEXEAgain`.
- **The AppKit exception.** A review found that the library, hosted as the app hosts it, made AppKit throw "…more Update Constraints in Window passes than there are views in the window".
  - The window agent found that it ends the app. AppKit's update-constraints observer rethrows it, ending in SIGABRT, or SIGTRAP on the layout path (seen under lldb), and the app doesn't set `NSApplicationCrashOnExceptions`.
  - The cause is the least widths. The sidebar (counted twice), Game info and the games' least width summed to 1,080 against an 800-point window. The split view meets that sum for a moment when the window narrows with Game info open, or when Game info closes under 1,100.
  - With `gamesMinWidth` at 60 and the games' height decoupled, the harness ran clean in every scenario: 24 of 24, 10 of 10 again, and the earlier repros. At 340, narrowing with Game info open, and closing it after such a narrowing, threw in 6 of 6 runs.
  - The last verifier's app-like host ran clean at 800 and 1,000, while the tree before the fix crashed in 2 of 2 runs at 800.
  - The least sizes are now 500 × 156 with the sidebar only, 360 × 156 with Game info only, and 800 × 156 with both.
- **Mutations**, each restored, were caught by the tests:
  - 2 on the Data side and 9 on the view-models.
  - The second review ran 21: 14 were caught, and six more once the first fixer's tests were in.
  - The first fixer ran 20: 19 were caught by a test, and under the twentieth, a preview hold on a thread, the code no longer compiles. The second fixer ran 11, all caught.
  - The design's today flow caught a Today scan that read discs.
  - The ones caught included: a hand-off while the boot is pending; discs that play; Remove without asking; a power-on without the EXE; Scan Again re-reading kept games; Stop letting the in-flight file in; the folder's access never ended; Cancel's stop missing or out of order; a cancel while the BIOS is read; a job opened right after a Cancel; the pane's size and read Details; a stale bookmark at its own path; a look that ends after a Locate…; the least-window arithmetic; the breakpoint's hide taken as the person's; another screen's sheet not covering the library; Return and ⌘⌫ in the search field; a second Add Games… choice dropped; the Game menu under a second opening; a file that isn't a game's recorded; the choosers' type list; the previews' Today tallies; a file check saving per game; a Cancel's stop not followed; Return off for a missing game; the look and the preview gate deaf to cancellation; a fake's held record holding its thread; repeated ids kept; parts told apart by spelling; a ring of playlists keeping none.
  - Not caught, and recorded: no `break` on a stopped snapshot in the opening job. It is equivalent under both the real and the fake session, since a stopped snapshot keeps `bootIsPending`.
- **The boards, rendered.** A throwaway test, not committed, rendered two things in the light, dark and high-contrast themes: the 26 library screens' previews, composed from their parts; and the real window, a titled `NSWindow` hosting `LibraryView` and captured offscreen, at 800 × 560 and 1280 × 800.
  - They were compared in the built-in browser with `Mac-LibraryEmpty`, `Mac-TodayLibrary`, `Mac-LibraryGrid`, `Mac-LibraryInspector`, `Mac-LibrarySearchEmpty`, `Mac-LibraryMissing`, `Mac-RemoveConfirm`, `Mac-Rename`, `Mac-LibraryMin`, `Mac-LibraryLight`, `Mac-LibraryContrast`, `Mac-ScanPicker`, `Mac-ScanRunning`, `Mac-ScanStopped`, `Mac-ScanDone`, and the Today flow's opening job.
  - They match at the Today level. At 800 the table keeps Name, Console, Serial and Size; at 1280 with Game info open, Format goes.
  - The departures:
    - Selected rows use the system's selection color, not the boards' amber (a ruling for the user's veto).
    - At 800 the toolbar's search field collapses to a button, as macOS's toolbar does when it runs out of room.
    - The composed light render drew the sidebar's selection black. That is an artifact of offscreen drawing: the real light window draws the system's gray.
  - After the window fix, the window agent rendered the real window again. Against the renders before it, the grid at 800 and the list at 1280 are pixel-identical, and the list and the empty library at 800 differ only in the search button.
- **Design and docs checks.**
  - `node tools/check.mjs` passes: eight flows, 29 shortcuts, 73 boards, and 54 contract rows (30 ready, 4 app, 17 gaps, 3 verify). `--render` passed at 139 pages when the design changed. The plain check passed again after every later token change.
  - The docs validator is clean on a copy of the worktree once the item shipped (23 index rows, 598 links, 94 files).
- **Searches.** A search of `source/` and `apps/` finds no networking API (URLSession, URLRequest, NWConnection), as contract row C47 says. Neither the diff nor the new files hold a Sony name, a disc image, a BIOS or a real path. Tests write only inside a `Sandbox`, and the previews stay in memory.
- **Probes**, all on scratch copies with made-up files:
  - Renaming or moving a file marks its bookmark stale while it still resolves.
  - Resolution spells the temporary folder `/private/var/…`, which `standardizedFileURL` turns into `/var/…`.
  - A deleted file's bookmark fails with "The file doesn’t exist." (macOS 27.0.1).
  - A file nobody may read gets a plain bookmark and a size, but its bytes are refused.
  - An imported type yields to the system's: `.bin`, `.m3u` and `.exe` resolve to the system's own types.
  - `addGames` costs 1.9, 8.0 and 15.3 ms with 100, 500 and 1,000 games kept. With real bookmarks (956 bytes), one relocation costs 12.8 ms on a 500-game file and 25.7 ms on a 1,000-game file.
- **The folder search's last fixes.** The last verifier's R1 (hard-linked games) and R2 (a playlist only a ring lists, kept when its name came first) were fixed, then gone over twice more by agents told to break them:
  - The first found no wrong answer, but a cubic search for ring heads (4,998 files of rings took 67 seconds against 1.9 before, and one ring of 5,000 playlists 449 MB against 37), quadratic path resolution over hard links, and a part that is a symbolic link never matched, a defect from before 5d. All three were fixed: one strongly-connected-components pass, each hard-linked game's path resolved once, and a linked part followed.
  - The second re-ran every probe: no wrong answer. `ringHeads(of:parts:)`, copied out, matched a reference Tarjan and a brute-force reachability check on 400,000 random graphs, ran a 100,000-node chain and ring on a 256 KiB stack, and a ring of 1,000,000 in 0.64 seconds. In release, 4,998 files of rings took 1.8 seconds against 1.7 before the fixes, and a ring of 5,000 playlists 39.5 MB against 36.2. Its two remaining costs: resolving every part slowed folders of cue sheets by 16 to 20 per cent, fixed by resolving only a part that is a link; and the hard-link case above, left as it is.
  - Mutations: R1's revert fails the hard-link tests, R2's the ring tests, and each only those; dropping the link follow fails the linked-disc test, ignoring the rings' outside listers the three ring tests, and reading a linked cue sheet's tracks from the link's folder the linked-sheet test. Not caught: a playlist's linked disc read the same way, which changes nothing `find(in:)` returns unless a sheet's track is itself a game's file; and the case-aside step, which resolving makes unreachable on APFS (twelve lookup orders probed), so it stays only as a guard.

**Decisions consumed.**

- 2026-11-21: the design's Today parts are v0.1.0's, which moves game import from v0.2.0 into v0.1.0 (the user's call). Each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-21, measured by probe: `PSEXE(bytes:)` threw `tooShort` for 10 bytes and `notAnEXE` for 4,096 zero bytes. The names and sizes the design shows are placeholders: nothing is fetched, and there is no artwork.
- 2026-11-22 (the defaults, confirmed by the user):
  - The library is `library.json` in the app's container, through the Data `library` store, with every field defaulted: one versioned file, as save states and cards will be.
  - Add Folder looks for .cue, .iso, .m3u and .exe files, groups an .m3u's discs under it, and skips the .bin tracks a .cue names.
  - There is no artwork and no title from a database. A game is named by its file and can be renamed, and nothing leaves the Mac (contract row C47, verify).
  - Discs are listed today, with Play off and the reason, rather than hidden, so the user sees what they added. 5h fills in console and serial.
- 2026-11-22 (the user's call, before the group run): each screen is checked against its board by rendering its previews and comparing them with the board in the built-in browser. No app is launched for the check.
- 2026-11-22, from 5c's landing (Milestone V), for the user's veto:
  - Continue lands on the empty library, as `Mac-LibraryEmpty` draws it, and the sidebar brings BIOS ⌘6 among its places.
  - Adding the games raises `Library.currentVersion` to 2, with a recorded version-2 fixture beside version 1's.
- **2026-11-22 and 2026-11-23, rulings made building and verifying it, each as it now stands.** The Data side's and the view-models' were made on 2026-11-22. The views', the app's, the design's and the docs' were made on 2026-11-23, as was every fix that followed the reviews and the verify pass.
  - **For the user's veto** (departures from the boards or the spec):
    - The table's and the sidebar's selection are the system's (`Table(selection:)`, `List(selection:)`), not the boards' amber. That is the person's accent while the window is key and gray otherwise, since the app has no AccentColor. The table shows the system's row separators, and the grid draws its own 2-point accent ring.
    - Play is on for a PS-EXE whose file is there, told by its .exe extension as the design's `canPlay` tells it. `PSEXE(bytes:)` checks the bytes at "Open the file", which refuses a file that isn't one. The spec's guardrail and the plan said Play is on only for a PS-EXE recognized by its bytes.
    - A stale bookmark that still finds its file is "moved": `whereabouts(of:)` reports it, and the library keeps the game again quietly where the file now is (measured: macOS marks a renamed or moved file's bookmark stale while still finding it). Only a file that can't be reached shows "File missing" with Locate…. Missing is worked out each time, never stored.
    - The folder search reuses `Playlists`, so `DataLibrary` uses `DataPlaylists` and `EmuKit` ships it in v0.1.0. C16 and C17 are tagged ready and keep their G2 id.
    - `GameRecord` keeps a .cue's `tracks` beside an .m3u's `discs`, so Game info's "Cue sheet with N tracks" needs no file read.
    - At 800 without Game info, the toolbar's search field collapses to a button (macOS's toolbar overflow). `Mac-LibraryMin` draws a field.
    - When the sidebar comes back, AppKit widens the window: 800 → 1,021 by ⌃⌘S, and 1,000 → 1,221 when Game info closes. A plain split view does the same, so this is left as the system does it.
    - The sidebar's Tools place (⌘7, personal builds) comes with 5f, since nothing shows in it before then. Its Seam line is in 5f's document.
    - On macOS 14, the deployment target, Search (⌘F) is off, because SwiftUI can't focus the toolbar's field there. From macOS 15, Play and Remove give way while the search field has focus. On 14, Return and ⌘⌫ typed in the field still play and remove.
    - The choosers have no titles, since SwiftUI's file chooser takes none. The search field has no "Search games" label, since `.searchable` takes none and VoiceOver names the field by its prompt. The unused texts are removed.
    - The grid has no arrow-key navigation. The table's arrow keys are the system's.
    - Recently Played lists the most recently played first, ties in the order added. The prototype keeps library order only because its dates are strings.
    - The sidebar is fixed at the token's 220. The Layout page's 180 to 280 has no tokens.
    - Initials and the empty library's disc use existing type styles, as 5c did for Welcome's disc: `Typography.screenSymbol` (48, against the design's 40), and `.largeTitle` in Game info (26, against 32).
    - The menus: File gets Add Games… ⌘O, Add Folder… ⇧⌘O, Show in Finder and Remove from Library… ⌘⌫, after New. View gets All Games ⌘1, Recently Played ⌘4, as List / as Grid, Show/Hide Sidebar ⌃⌘S and Show/Hide Game Info ⌘I, before the toolbar items. Edit gets Search ⌘F. Game gets Play ↩ first, and Console gets BIOS ⌘6 after Run the BIOS. The Layout page names no menu for ⌘1, ⌘4 or ⌘F.
    - `main.html` changes what it shows only where 5d's code decided otherwise: the Today removal wording, the missing-file Details, and the Today scan. The scan boards still draw the full level. Its `initialState` also applies the level before the preset, so a preset sees its level.
    - Sentences the design doesn't draw:
      - the opening job's "This file isn’t a PS-EXE program, so iStation can’t start it.", "iStation has no BIOS to power on with. Choose your BIOS file first." and "Your BIOS didn’t reach its shell in 600 frames, so the program didn’t start.";
      - the scan's "iStation couldn’t open this folder." and "iStation couldn’t add this game to your library.";
      - Add Games…'s and Locate…'s failure alerts, including "That file is already in your library" and the refusals of a file that isn't a game's;
      - "The library couldn’t be saved".
  - **The library file:**
    - Every `GameRecord` field decodes with a default: `""`, the format the file name says (else `.unknown("")`), `0`, `Date.distantPast`, nil for last played and the library's name, empty `Data`, and no tracks or discs. A field of the wrong type is still an error.
    - A record without an id gets a name-based UUID (version 5's layout) from the SHA-1 of its path and bookmark, so it is the same game on every load until a save writes the id.
    - A record whose id repeats an earlier one's gets a stable id of its own, made the same way with its place in the file. Identical records stay two games and aren't merged, so no name or date is lost.
    - `GameFormat` keeps an unknown value as `.unknown(String)`. A PS-EXE is written "exe", as the design's format key is. The four extensions are recognized in any case.
    - `size` is the whole game: the file, a .cue's tracks, and an .m3u's discs and their tracks. A part that can't be sized counts nothing.
    - `games` is always written, an empty list when there are none. `lastPlayed` and `name` are written only when present.
    - A duplicate is the same standardized path, which folds `/private/var` into `/var` (measured). `add` also skips an id the library already has.
    - A change that changes nothing writes nothing: adding only kept files, removing only ids not kept, or a file check that finds nothing moved.
      - Remove passes over ids not kept.
      - Rename, mark-played and relocate on an id not kept throw `noSuchGame`.
      - Relocating onto another game's file throws `alreadyKept`, keeping one game per file.
      - `relocateGames(_:)` passes over such a move and over a game no longer kept, and makes the rest in one load and one save.
    - Rename trims spaces and newlines. An empty or nil name is stored as nil, so the file's name shows.
    - `Library`'s changes round every date down to the whole second, so what a store call returns equals the next load.
    - Store calls return the library as the file now holds it, in this build's version. So `keepBIOS` and `forgetBIOS` on a version-1 file return version 2.
    - `shownName` is the library's own name when it isn't blank, else the file name without its extension, else the whole file name.
    - The fixture `library-v2.json` holds the BIOS and three made-up games: a .cue with its track, a played .m3u with its discs, and a renamed, played PS-EXE. It is pinned both ways: this build writes the same JSON, every key and value, but not byte for byte, since the fixture ends in a newline the encoder doesn't write. The defaults are tested inline.
    - Version 1's write test became "saved again, it is written in version 2's shape". The later-version test uses version 3, and the empty-library test compares fields. `Package.swift`'s `testFixtures` needed no change.
  - **Kept files and the BIOS read:**
    - The BIOS read is shared as `KeptFileReading.readBIOS(_:expectedSize:)`, which `BIOSStorage` now refines, so the pane's fakes run through it unchanged. The caller passes the size, since Data can't see `PS1Bus.biosSize`.
    - `KeptBIOSError` keeps size and read failures apart, so Details still name `KeptFile.size(at:)` or `KeptFile.bytes(at:)`.
      - Each failed call's case carries the `KeptFileError` that was thrown, and `wrongSize` the size found.
      - An error of another type, which only a fake could throw, is made one from its description.
    - `readBIOS` doesn't keep a stale bookmark again. It returns `isStale`, and the caller keeps it again with `moved(to:bookmark:)`.
    - The BIOS pane reads in one detached task instead of three. Its calls, their order and its texts are unchanged.
  - **Finding games:**
    - A game's parts are matched by the file system's resource identifier, and by the standardized path for a file that isn't there. So a part spelled in another case is still a part, and a part a sheet or playlist names by a symbolic link is the game it leads to. Only a part that is itself a link is resolved, since resolving every part slowed a folder of cue sheets by about a fifth (measured).
    - A cue sheet reached by a symbolic link, alone or as a playlist's disc, names its tracks from the folder of the sheet it leads to, so they count toward the game's size.
    - Of games that are one file by hard links, a part is the one whose path its sheet or playlist spells, symbolic links resolved; resolving gives the file's own spelling, so a part named in another case still spells one. Failing that, it is the one spelled the same but for case, a step kept in case resolving doesn't give the file's spelling; failing both, it is all of them. Each such game's resolved path is worked out once.
    - Whatever a game that stays lists goes, and so does whatever that lists in turn. A playlist that lists itself stays.
    - What is left after that is listed only from among itself: rings of playlists, and what they list. One pass finds its strongly connected components (Tarjan's, without recursion), and the first game in path order of each component nothing else left lists is kept. So a ring's head is never a playlist the ring lists, nor a ring that another ring lists, and the pass takes linear time.
    - Hidden files, package contents, symbolic links and subfolders that can't be read are passed over. Results come in case-insensitive, numeric path order, and a cancelled search ends early with what it has found.
    - A .cue or .m3u over 1 MiB isn't read for its parts.
    - A record's file name and folder come from the file's standardized URL, and its bookmark from the URL given.
    - `record(for:added:)` keeps an unrecognized extension as `.unknown(ext)`. The view-models refuse such a file before recording it.
  - **Wiring and storage:**
    - The library owns its scan and opening jobs, which report each change back through a weak relay. So the app builds one view-model.
    - The library hands a run on as its own `GameRun`: the BIOS file's name and size, and the program's name and file. The app maps it to the player's `PlayerRun`, so `PresentationLibrary` doesn't use `PresentationPlayer`, as ADR 0023 requires.
    - `playerHoldsWindow(whilePlaying:)` stays in the library's view-model, where it is tested. The player holds the window while a run plays, no opening job shows, and no stop a Cancel sent is still under way. The window switch and the Game menu both read it through `MainWindow.playerShows`.
    - Writes to `library.json` run on the main actor, one at a time. The user's files are found, recorded, resolved and read in detached tasks.
    - `LibraryStorage.record(for:added:)` is async, so a stand-in can hold a record without a thread. Every other call stays synchronous.
    - One `LibraryStore` serves both `LibraryBIOSStorage` and `LibraryStoreStorage`, and the opening job's `onBIOSMoved` goes to the pane's `kept(_:)`.
    - `isCovered` covers the library while any of these is open: the BIOS check's chooser or sheet, the BIOS pane's alert, or Run the BIOS starting. `canAct` hears it, so nothing in the library powers the session on meanwhile, and Run the BIOS is off under the pane's alert.
    - File checks and Add Games… stop when the library goes away. They are linked to their task with `withTaskCancellationHandler` and check `Task.isCancelled` between files. A scan's record is linked to the scan.
  - **The window and its layout:**
    - The window is a `NavigationSplitView`. The BIOS pane comes in through a view builder, so `library` doesn't import `bios`. `.inspector` stays inside the detail column: with the window fix, moving it onto the split view isn't needed.
    - The library's views are macOS-only. The iOS app mounts none of them.
    - `LibraryLayout` follows the design's arithmetic: the content is the window less the sidebar and Game info where they show. So 800 leaves 580, which keeps Name, Console, Serial and Size.
    - A dropped column is drawn by choosing among three tables, since conditional `TableColumn`s need macOS 14.4.
    - The split view's sidebar follows the layout worked out for that draw. `splitViewShowsSidebar(_:)` takes a hide while Game info shows as the breakpoint's, never the person's; any other change is the person's. So with Game info open, the sidebar hides only by ⌃⌘S or the toolbar's button, not by dragging.
    - The split view's own sidebar toggle is removed from the sidebar column, leaving the view-model's one button, "Hide the sidebar" or "Show the sidebar" (⌃⌘S).
    - `gamesMinWidth` is 60 on the Mac (320 on iOS): the least window less the sidebar, counted twice, and Game info.
    - The games' frame doesn't follow their content's height (`minHeight` zero, `maxHeight` infinity, top-aligned), so the narrow least width asks the window for no height.
    - Each chooser and sheet hangs on its own background view. Locate…'s chooser waits until the missing-file alert's sheet has gone.
    - Library alerts are `DetailsAlert`s in `.sheet(item:)`. Closing one without a button, or Escape, answers Cancel.
    - `DetailsAlert` never truncates a button title. A longer title takes more of the row, and titles that don't fit side by side stack, the default on top. No existing alert changes, and the "Long titles" preview draws the stack.
    - The library looks for its games' files at launch and whenever the app becomes active.
    - The view-model's search-focus flag is cleared when the games view disappears: when the player takes the window, or at the BIOS place. A hosting probe checked this, since no test hosts a view.
  - **Menus and keys:**
    - The library's File, Edit and View items show while a BIOS is kept; Game › Play and Console › BIOS always show. Every library menu item, the View menu's included, acts only while the library holds the window and nothing is open over it, whether the library's own sheet or one `isCovered` reports. Play, Show in Finder and Remove are off at the BIOS place.
    - The Game menu's own items act only while the player holds the window. `PlayerCommands` and `BIOSCommands` gain slots for the library's `LibraryMenuItem`s and keep their old initializers.
    - Run the BIOS is off while a library sheet, chooser or alert is open.
    - Play's key is a plain Return, as the design writes it. Play is on for a selected game whose file is missing, whatever its format, so Return opens the missing-file dialog as the design's Return does.
    - The window shows the player while it holds the window. Otherwise it shows the library once a BIOS is kept, landing on All Games, so the check's Continue reaches `Mac-LibraryEmpty`; otherwise it shows Welcome.
    - The player's Stop reads "Stop and go back to the library" (⌘.), as the design has it.
  - **The library's behavior:**
    - Missing files are looked for at launch, when the app becomes active, and on `checkFiles()`. Every moved game is kept again quietly at its new place, in one store change.
    - A game whose file Show in Finder can't resolve is flagged missing. A missing game's Size reads "Unknown", as `Mac-LibraryMissing` draws it.
    - Playing a missing game opens the missing-file dialog whatever its format. Its Details name the call that failed: `KeptFile.resolve(_:)` or `KeptFile.size(at:)`.
    - At the Today level, Remove's message leaves out save states and memory cards. It says "The program stays on your Mac. You can add it again any time." for a PS-EXE, and the same of "The disc image" for a disc. After a remove, the first game shown is selected.
    - Search matches the shown name, ignoring case, with the words trimmed.
    - The first game is selected at launch. A place selects its first game when the selection isn't among them, and the BIOS place closes Game info.
    - Rename trims the name and does nothing when it is unchanged. Renaming to the file's own name clears the library's name.
    - Add Games… records the files off the main actor and adds the new ones in one store call.
      - Files already kept are skipped silently, and the last file chosen is selected.
      - Failures open one alert, "“x” couldn’t be added" or "N files couldn’t be added", with each call under Details.
      - A choice made while another is still being recorded is added after it; `isAdding` counts the choices pending.
    - A file whose extension isn't a game's is refused before it is recorded, since the choosers' system types also carry other extensions.
      - Add Games… says "iStation’s library keeps .cue, .iso, .m3u and .exe files.", with `GameFormat(fileName:)` returning nil under Details. A mix of failures keeps "iStation couldn’t open these files."
      - Locate… says "“x” isn’t a game’s file", then that sentence, then "Choose “y” where it is now."
    - Locate… keeps the game's id, name and dates.
      - A file another game keeps is refused with "That file is already in your library".
      - A file that can't be read is refused with "“x” couldn’t be opened".
      - A game removed meanwhile is skipped, and a look that ends after a Locate… leaves the game as located.
    - A change `library.json` can't save says "The library couldn’t be saved" / "iStation couldn’t write the change to its library. Your files are as they were.", with OK.
    - Keys and buttons do nothing while a sheet, chooser or alert is open (`canAct`). The view-model's sidebar and Game info toggles and its view mode don't check it, but their menu items do.
    - `select(_:)`, `search(for:)` and `showGames(as:)` are intents for the selection, the search's words and the view mode. The previews and the grid's click use them.
  - **The scan:**
    - Each file is added as it is read, one `addGames` per file, so the library shows it at once and Stop keeps what was added. "Add them to your library" passes with the last file.
    - The read step keeps the design's name, its "n of N" detail and its "Reading n of N · file" bar. Its detail about SYSTEM.CNF waits for 5h.
    - An added file reads "Added · .cue" (or .iso, .m3u), and a PS-EXE "Added · PS-EXE · no serial".
    - A file that can't be recorded reads "iStation couldn’t open this file.", with `KeptFileError`'s case. A game the library can't keep reads "iStation couldn’t add this game to your library."
    - Stop drops the file being read when it lands. Scan Again rescans the same folder and checks `Library.game(at:)` before making any bookmark.
    - A folder that can't be searched fails the scan at its first step, with the call under Details, and Done and Scan Again.
    - The tally uses the design's words, including "Nothing added yet.", with numbers grouped.
    - The folder's security-scoped access is held from before the search until the last file is recorded.
  - **The opening job:**
    - The run is handed on at the first running snapshot whose `bootIsPending` is false. At frame 600 the job gives up and stops the session.
    - Cancel closes the sheet at once, and stops the session only if this job may have powered it on. The library keeps the window until that stop lands (`isStopping`), which includes the job's own stop after a power-on that a Cancel interrupted.
    - A file over 2,099,200 bytes is refused, unread, as not a PS-EXE.
    - Failures show on the job sheet with a danger summary, the call under Details and Close. The BIOS failures reuse the BIOS pane's sentences.
    - A stale BIOS bookmark is kept again where the file now is and reported to `onBIOSMoved`.
    - The game is marked played after the hand-off. A library that can't record it doesn't stop the run.
    - A session stopped by something else before the hand-off ends the job quietly.
  - **Words and figures:**
    - "Playlist of 1 disc" is singular, and counts are grouped.
    - Sizes follow the design's `fmtBytes`, halves rounding up as JavaScript's `toFixed` does.
    - Played dates read "Today, 9:41" and "Yesterday, 21:10" (24-hour), then the day. An added date the record didn't keep reads "Unknown".
  - **Shared code and tokens:**
    - `Dates.day`, `Folders.shown`, `Details.threw` and `PresentedJobSheet` move into `styles`, now that two modules use them.
    - The thirteen size tokens go into `tokens.json` first, for both platforms, and are synced, then added to `Metrics.layout` and `TokensTests`. iOS takes the Mac's values where they never apply; its `emptyWidth` is 390 and its `gamesMinWidth` 320. `main.html` keeps its own numbers, as 5c left 460 and 720.
    - The no-results view's 60-point top inset is `Metrics.space10 + Metrics.space5`.
    - Alerts are the module's own `LibraryAlert`, answered through `answer(_:)`, so the view-models use no type defined in a SwiftUI file.
  - **Imported types:**
    - The four types are imported, not exported, in a merged `apps/macos/Info.plist`, since no `INFOPLIST_KEY_*` setting can declare a type.
    - The choosers offer them, plus every type the system gives .cue, .iso, .m3u and .exe. The .bin type is declared but never offered.
    - `GameFileTypes.offered(imported:lookUp:)` is pure. Tests run it over a scripted lookup, never the type database, and read `Info.plist` to pin the declarations.
  - **Previews:**
    - Previews reach every state through the initializers and intents, including the selection, the search and the view mode (ADR 0021 §3).
    - Scanning holds its fifth file's record at a `PreviewGate`, suspended without a thread for as long as the preview lasts, and released when its task is cancelled. Scan Stopped presses Stop after five files.
    - Scan Done adds every backup ("Added 7 games. 2 already in your library."), as the design's Today scan does.
    - The missing file's reason is "The file doesn’t exist.", as recorded on macOS 27.0.1.
    - The "High contrast" preview draws dark in Xcode's canvas, since an app can't put AppKit into high contrast. The renders set `Theme.applied`.
  - **Tests:**
    - The fakes print short summaries, so a failing expectation can't stall other tests, and every wait ends within two seconds. They can hold a search, records, resolves, reads, power-ons and stops, as test support only.
    - `PreviewLibraryTests` runs in debug builds only, where the previews are. It pins them to the Today level, and checks that a held scan holds no thread and ends when stopped.
    - `MemoryStorage` holds records suspended at `HeldCalls`, without a thread. Its synchronous calls wait on their own threads, since the view-models run them in detached tasks.
    - Each `@unchecked Sendable` in 5d's fakes carries a one-line reason. 5c's BIOS fakes are unchanged.
    - Every design sentence is checked against `main.html`, and the new sentences in the view-model tests.
    - No unit test hosts a view. The least size is pinned by the token arithmetic. The window, the search focus and the app's wiring were checked in throwaway harnesses.
  - **The design:**
    - A contract row becomes ready when 5d's code and tests back it. C20 and C53 are ready while naming what they still lack: console and serial, and the PS1 and PS2 filters, both of which need G2.
    - C11 stays verify. The probe hasn't been run, and 5d adds its two questions.
    - C19's note says the app wasn't launched, and C47 stays verify until a rule test enforces it.
    - The answered call "Scope before discs play." is retired.
    - The Contract board's content now stands 10,151 points tall, but the canvas's frames go up to 8,000, so its frame and preview stay at 8,000 and the canvas shows its top 8,000 (for the user's veto).
    - Left as they are:
      - the `Mac-LibraryMissing` board's title, which still says "file moved";
      - C49's note;
      - the prototype's Recently Played order;
      - the Today Format column's ".cue" and ".m3u", in the prototype and the code alike.
  - **The docs:**
    - ADR 0002's "The table as of" note is updated, as 5b and 5c did; its decision is unchanged.
    - "Closing the window leaves the session as it is" now says 5d left it as 5c had it.
    - The checklist's `library.json` line carries the rule to raise the version with a fixture, linking to DEVELOPER's recipe.
    - The doc comments of `BIOSPaneViewModel`, `LibraryMenuItem`, `PlayerViewModel.started(_:)` and `LibraryView`'s `sidebarVisibility`, and DEVELOPER's player entry, now say what the code does.
