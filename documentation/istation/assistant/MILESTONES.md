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
