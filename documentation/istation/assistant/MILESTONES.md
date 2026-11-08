# iStation — Milestones

The detailed record of finished work: what shipped, how it was built, the trade-offs taken and how it was verified. Pending work lives in [`backlog/`](../backlog/README.md); this file holds finished work only.

## Milestone A — The construction

**Goal.** Make iStation buildable over many sessions without the chat as memory: the user's Code Scaffold (2026-10-26) carved into a four-layer architecture with mechanically enforced dependencies, compiling and green; a network of `CLAUDE.md` files; this docs home; and the project-local lifecycle skills. It also delivers the first two lines of the v0.0.1 roadmap: the scaffold compiles, and its tests are green.

**Built** (construction, 2026-10-31):

- **The package** (`src/istation/Package.swift`, swift-tools-version 6.0, Swift 6 language mode, macOS 14): the `modules` table — the layer law's one declaration ([ADR 0002](../adrs/module-map.md)) — generating 21 library targets and 21 Swift Testing targets; 3 test-support targets (`SupportSandbox`, `SupportDiscFixtures`, `SupportLibraryFakes`); the `iStation` executable (`source/main/iStationApp.swift`); and `ArchitectureTests`.
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

- 21 modules for about 1,700 lines of scaffold, over two targets: more targets and directories, accepted because every edge is now a declared, checked fact ([ADR 0003](../adrs/granular-modules.md)).
- The module map lives in `Package.swift` as one-line rows that a test parses, rather than in a separate map file: the declaration *is* the build and cannot drift from it. The cost: the rows must keep their one-line shape.
- The checks are a Swift test target, not a separate script, so a routine `swift test` runs them. SwiftPM's `--explicit-target-dependency-import-check=error` catches only imports of modules a target does not depend on at all (measured: a dependency's dependency passes), so the test's own import scan is the line that requires direct declaration.
- Preview fakes are copied into each module (`shell`, `library`, `settings`), per [ADR 0006](../adrs/presentation-previews.md); preview games are real-shaped (the disc fixtures' titles and serials), not yet recorded from a real library.
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
- Three records: [ADR 0010](../adrs/cores-are-ports-of-open-references.md) (the cores are ports of open references; installed emulators cover the rest; no Sony files; supersedes [ADR 0008](../adrs/emulators-are-separate-programs.md), whose status line now says so), [ADR 0011](../adrs/each-module-carries-its-licence.md) (each module carries its licence) and [ADR 0012](../adrs/cores-shape-and-hot-paths.md) (a CPU module and a console module behind one narrow interface; concrete types in hot paths).
- [CLAUDE.md](CLAUDE.md): what this is, stack and licences, a section on the cores, the ported-code invariant in place of the emulators-are-separate one, open fixtures in the no-Sony-files invariant, versioning, the checklist and release. [ROADMAP.md](ROADMAP.md) re-planned (v0.0.1 the R3000A boots OpenBIOS … v2.x PS2).
- The backlog: 1a retired and deleted; Architecture A1 and v0.0.1's track 2 (2a–2e) written from the spike.
- The root README and CLAUDE.md, the router, this home's README, the Business and Infrastructure cards, the launch contract's introduction, DEVELOPER's test table, five skills that named ADR 0008 or the launcher-only non-goals, and the comments citing ADR 0008 in `GameLauncher.swift`, `ProcessRunner.swift`, `ProjectRulesTests.swift` and `Package.swift`.

**The spike behind it** (measured 2026-11-07 in a scratch folder; nothing vendored).

*Redacted 2026-11-07 under [ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md), when the App Store brief made GPL emulators' source off limits: what this spike learned about GPL emulators' internals is removed; licence and provenance facts, the build, and iStation's own measurements remain.*

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
- Four records: [ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md) (shipped code only from permissive sources; GPL emulators black boxes; supersedes 0010), [ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md) (iStation's own code MIT; notices kept; supersedes 0011), [ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md) (core shape and hot paths; supersedes 0012) and [ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md) (two build routines; the library app retired; supersedes 0007 for its file).
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

**Built** (3c, 2026-11-07): `DataTracing` (Data layer, product `TraceKit`, personal builds only; iStation's own code, MIT) in `src/istation/source/data/tracing/` — `Checksum.swift` (`FNV1a64`; `RegisterChecksum` over the 32 general registers, HI, LO and COP0 SR, CAUSE, EPC), `InstructionRecord.swift` (24 bytes, and `FullStateRecord`, 160), `FrameRecord.swift` (32), `TraceFile.swift` (the 16-byte `ISTR` header, `TraceWriter` with a 1 MB buffer, the streaming `TraceReader`, `TraceError`), `TraceDiff.swift` (the first divergence with its differing fields by name; a cycles-off flag no gate uses), `Checkpoints.swift` (an `ISCK` file of one FNV-1a checksum per window). Its contract, byte by byte: [reference/trace-formats.md](../reference/trace-formats.md). Tests in `tests/data/tracing/`; the `macOS Personal` scheme tests them.

**Trade-offs.** FNV-1a 64 over little-endian bytes, chosen because ProjectPSX's C# patch and SwanStation's C frontend (3d) can write it identically in a few lines, not for strength. Tagged, fixed-size records keep the reader simple and let full-state records interleave with instruction records; the tag costs one byte in 25. The image and audio checksums are carried now and compared only once v0.1.0 and v0.2.0 fix their sample formats; RAM is the gate's measure. No app links `TraceKit` yet; a core will reach it only through a generic tracer that release builds specialize to nothing (3e).

**Verified** (2026-11-07, M3 Max, macOS 27.0.1):

- Both encodings pinned byte for byte against hand-written bytes; FNV-1a 64's published vectors (`""`, `"a"`, `"foobar"`) and two register checksums computed independently in Python; round trips across the buffer boundary (100,000 records); truncated, empty, foreign, newer-version and unknown-tag input each a named error; the first divergence by index and field, the end of a shorter trace, ignored cycles; checkpoint reduction (one changed record changes exactly its window) and its file round trip — 22 tests.
- **Throughput** (`ISTATION_BENCHMARK=1 swift test -c release --filter ThroughputTests`): 100 million instruction records, 2,500,000,016 bytes, **written in 3.96 s (25 M records/s) and read in 1.90 s (53 M records/s)**.
- `swift test` — 66 tests in 10 test runs, green; `xcodebuild test -scheme "macOS Personal"` — TEST SUCCEEDED; the strict build clean; `toolsArePersonalOnly` already guards `DataTracing` (Milestone F).

**Decisions consumed.**

- 2026-11-07: TraceKit is the trace format, recorder and diff, personal builds only (the user's brief); the records and the diff's fields as specified (the defaults, confirmed by the user).


## Milestone H — Provenance headers and notices

**Goal.** [ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md): iStation's own code is MIT; code ported from ProjectPSX keeps its MIT notice and code from Play! its BSD notices; every app shows every notice it carries — with a check, before the first ported module (Architecture item A2, which gated 3e).

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

**Goal.** The first ported code: the PS1's CPU as an interpreter, ported from ProjectPSX's `ProjectPSX/Core/CPU.cs` (MIT, pinned at `f4dc13aea42d`) — the only CPU path that works on iOS and the accuracy baseline for everything after — and generic over its bus, so the PS2's I/O processor can reuse it (v0.0.1 item 3e; [ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md)).

**Built** (3e, 2026-11-07, by a session that has never read a GPL emulator's source):

- **`BusinessR3000A`** (Business layer, product `PS1Core`; `Module(.business, "R3000A", …, derivedFrom: .projectPSX)`), in `src/istation/source/business/r3000a/` — every file with ProjectPSX's notice and its provenance line:
  - `R3000A.swift`: `R3000A<Bus: R3000ABus, Cop2: Coprocessor2, Tracer: R3000ATracer>`, a final class. Its state is ProjectPSX's (`pc` and `nextPC`, the branch and delay-slot flags, HI/LO, the write-back and the two-stage load delay, COP0 with PRID 2). `step()` runs fetch, execute, memory access and write-back and returns the fetch's cycles; `handleInterrupts()` is called by the console between instructions, as ProjectPSX's run loop does; `raise` pushes SR's mode stack and records CAUSE, EPC, BD, BT and the jump destination.
  - `Instructions.swift`: ProjectPSX's main and SPECIAL opcode tables as two switches, with the COP0 moves and RFE, and the COP2 transfers.
  - `Bus.swift`: `R3000ABus` (fetch with its cycles; 8-, 16- and 32-bit loads and stores that `throw(BusError)`; `interruptPending`).
  - `Coprocessor2.swift`: `Coprocessor2`, and `NoCoprocessor2` for the IOP.
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
- SWL and SWR are held back while the cache is isolated, like the other stores.

**ProjectPSX's quirks kept until SwanStation's trace (3d) decides:**

- BLTZAL/BGEZAL write r31 directly rather than through write-back.
- Enabling interrupts by MTC0 with a software interrupt pending sets EPC to the instruction after the next one, which never runs.
- An interrupt waits while the next instruction is a COP2 one.
- LWL and LWR ignore cache isolation.
- COP1, COP3 and the LWC0/1/3 and SWC0/1/3 encodings are NOPs.

**Trade-offs.**

- **No runtime exclusivity checks.** Every stored `var` of the CPU is `@exclusivity(unchecked)`. Swift checks each access to a class's stored property at run time, even in optimized builds and wherever the inlined hot path lands, and on the spike's loop those checks held the interpreter to **18 M instructions/s**. Holding the state behind unsafe pointers instead also avoids the checks but measured 213 M; the attribute measured 238–267 M, with simpler code. ADR 0015 §4 now says so, and the card and the checklist carry the rule.
- **Real access widths.** Byte and halfword loads use the bus's 8- and 16-bit reads, where ProjectPSX reads 32 bits and truncates: the same result from RAM, and the right width for 3f's devices.
- **Peeking the next instruction.** The COP2 postponement looks at the next instruction through `bus.fetch`, as ProjectPSX reads RAM or BIOS directly, so a console's fetch must have no side effects.
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
- **Still to come with 3d**: the same program on ProjectPSX's traced build, trace against trace. 3d carries that guardrail.

**Decisions consumed.**

- 2026-11-07: PS1 from ProjectPSX; the IOP reuses this CPU (the user's brief). One CPU module generic over its bus, concrete types in the hot path (ADR 0015).
- 2026-11-07: where ProjectPSX and psx-spx disagree, psx-spx and SwanStation's recorded behaviour (3d) decide, and the difference is noted beside the code; no disassembler — TraceKit's diff prints raw instruction words (the defaults, confirmed by the user).

## Milestone J — The PS1 console

**Goal.** A PS1 around the R3000A, so a BIOS can boot (3g): the memory map, the interrupt controller, the timers, DMA, the GPU's timing, the TTY, and enough of the other devices to answer the BIOS, ported from ProjectPSX (`Core/BUS.cs`, `Core/ProjectPSX.cs`, `Devices/InterruptController.cs`, `Devices/TIMERS.cs`, `Devices/DMA/`, `Devices/Expansion/Exp2.cs` and the timing of `Devices/GPU/GPU.cs`, at `f4dc13aea42d`), with PS-EXE loading for test programs (v0.0.1 item 3f; [ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md) §3).

**Built** (3f, 2026-11-07, by a session that has never read a GPL emulator's source). `BusinessPS1` (`Module(.business, "PS1", uses: ["BusinessR3000A"], …, derivedFrom: .projectPSX)`), in `src/istation/source/business/ps1/`, every file with ProjectPSX's notice and its provenance line:

- **`PS1Machine<Tracer>`**: the R3000A specialized over `PS1Bus`, and ProjectPSX's run loop — about 100 cycles of CPU, then the devices for what they took, then the interrupt check. `runFrame()` runs to the next vertical blank. `load(_:)` starts a PS-EXE now; `boot(_:)` starts one when the BIOS reaches its shell at 0x80030000. `tty` is expansion 2's output, plus the BIOS's putchar (A(3Ch), B(3Dh)) when `capturesBIOSPutchar` is on, as ProjectPSX's `TTY()` hears it.
- **`PS1Console`**: what the apps hold. It is powered off until `powerOn(bios:)` gets a 512 KB image.
- **`PS1Bus`**: the memory map. The 2 MB of RAM is mirrored through the BIOS's 8 MB window; then the scratchpad (KUSEG and KSEG0), the I/O ports, expansions 1–3, the read-only BIOS and the cache control register. RAM and BIOS fetches and RAM loads and stores take an `@inlinable` fast path.
- **`MemoryControl`**: the delay/size registers, COM_DELAY, RAM_SIZE and cache control, and each region's load time.
- **`InterruptController`**, **`Timers`** and **`DMA`**: the seven channels with DPCR and DICR. OTC writes real tables; the device channels feed the stubs.
- **`GPU`**: NTSC timing (263 lines of 3413 video cycles), GPUSTAT and the GP1 display commands; no drawing.
- **The stubs**: `CDROMStub`, `SPUStub` (SPUSTAT follows SPUCNT, which the BIOS waits on), `MDECStub` and `PortsStub`. Each answers with psx-spx's power-on state.
- **`Expansion2`**: the TTY and the POST display. **`PSEXE`**: reads, writes and loads the format.
- **Two shared changes**: `R3000ABus`'s narrow stores now pass the whole source register (3e's interface, changed with its tests), and the tests' assembler moved to `SupportMIPS` (`tests/support/mips/`), shared by both cores' tests.
- **Tests** in `tests/business/ps1/`, the `macOS Personal` scheme already running them.

**Where it departs from ProjectPSX** (psx-spx and the hardware decide; each is a comment beside the code):

- **Wait states.** A load costs its region's access time, charged to the devices' clock, so the devices run at the real rate. ProjectPSX charges loads nothing and ticks its devices three times faster to compensate (`MIPS_UNDERCLOCK`). The times come from psx-spx's formula over the delay registers for expansions 1–3, the BIOS, the SPU and the CD-ROM, and from ps1-tests' `access-time` log, recorded on hardware, for RAM (5), the scratchpad (1), the I/O ports (3) and cache control. Fetches keep ProjectPSX's 1 and 20 cycles, so cycle counts stay comparable with its traces. Stores cost nothing (the write buffer).
- **Bus errors** where psx-spx maps nothing: past the RAM window, between the regions, beyond the BIOS, KSEG2 outside the control registers, and the scratchpad through KSEG1 or as code. ProjectPSX logs these and reads all ones.
- **Widths, from the `io-access-bitwidth` log on hardware.**
  - A narrow store reaches a 32-bit port as the whole source register.
  - The 8-bit CD-ROM port is read again for each byte of a wider load.
  - The 16-bit SPU and controller registers take a narrow store's low halfword.
  - The empty expansions read all ones at every width.
  - DICR keeps its bits 0–5, and timer targets are 16 bits.
- **Smaller fixes.** The memory control registers are initialized, with the values the BIOS writes; ProjectPSX leaves them as uninitialized memory. The video clock's 11/7 is kept exactly; ProjectPSX drops the remainder on every tick. OTC entries are 24 bits.
- **Loading.** A PS-EXE's fill region is zeroed, and the EXE starts when the PC reaches the shell, which holds for any BIOS. ProjectPSX skips the fill and patches SCPH-1001's image at 0xBFC06FF0.

**Trade-offs.** psx-spx calls its access-time formula approximate, and against the hardware log it misses for expansion 2 (15/29/57 cycles against 11/26/56), the CD-ROM (7/13/25 against 8/14/26) and the SPU (21/41 against 18/39). It is kept, since it responds to the registers the BIOS writes, and 3g settles the differences against SwanStation's output; the BIOS and expansions 1 and 3 match. The log's open-bus upper halves (I_MASK reading 0x1234_0678, for one) aren't modelled. GP0 is consumed unread until v0.1.0 draws, so GPUSTAT's drawing bits stay 0. The CD-ROM never answers, so a real BIOS's boot may wait on it; which registers it needs is read from 3d's traces before any stub does more.

**Verified** (2026-11-07, M3 Max, macOS 27.0.1, Xcode 27.1):

- **The console's tests**: 41 hermetic tests in 10 suites, over BIOS images and programs built in code, plus the benchmark, off by default. They cover:
  - the memory map's mirrors, segments, read-only BIOS, empty expansions and bus errors;
  - the I/O widths, each against a row of the hardware log;
  - the CPU taking the vertical blank every frame through a handler and RFE;
  - the timers' clocks, targets, IRQ and flags; OTC's table, DPCR and DICR;
  - the NTSC frame, within 200 cycles over 10 frames, and GPUSTAT;
  - PS-EXE round trips and loading;
  - the TTY through expansion 2, the BIOS's putchar and the boot hook;
  - each region's load cost, measured as cycles per loop; the console powering on.
- **Planted bugs, 4 of 4 caught, then restored**: a narrow store truncated; the video clock at 10/7; RAM loads free; the CD-ROM port not repeated.
- **Speed** (`ISTATION_BENCHMARK=1 swift test -c release --filter BusinessPS1Tests.BenchmarkTests`): the spike's loop on the whole console — CPU, bus, wait states and devices, 600 frames — runs at **209–210 M instructions/s, 10.3× the PS1's 33.8688 MHz**, two runs.
- **The full suite**: `swift test` — 173 tests in 11 test runs, green (the architecture checks included); the strict build and the release build clean; the docs validator clean; `xcodebuild test -scheme "macOS Personal"` — TEST SUCCEEDED; both apps' personal routines build (`./scripts/build-personal.sh macOS`, `iOS`).
- **For 3g**: the per-frame comparison with ProjectPSX, carried into 3g's document.

**Decisions consumed.**

- 2026-11-07: one console module, devices carved out only behind the trace harness (ADR 0015).
- 2026-11-07: the stubs answer as psx-spx documents each device's power-on state; NTSC only; what `access-time` and `io-access-bitwidth` need — wait states, register widths — ported here (the defaults, confirmed by the user).
