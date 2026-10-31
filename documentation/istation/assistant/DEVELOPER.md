# iStation — Developer Reference

The module-by-module reference: the tree, each module's files and interfaces, the build/test commands, and the recipes for every extension point. The rules and their reasons are in [CLAUDE.md](CLAUDE.md) and the [ADRs](../adrs/README.md); this file says *where things are and how to work with them*.

## Directory tree

```
CLAUDE.md                      root pointer → documentation/CLAUDE.md
README.md                      public overview
iStation.xcodeproj/            opens the package in Xcode: no targets of its own, one shared scheme `iStation`
.github/workflows/ci.yml       strict build, swift test, docs validator
scripts/validate_docs.py       the docs validator (backlog index ↔ documents, links)
documentation/                 the router and this docs home
src/istation/
  Package.swift                the module map (ADR 0002) and the targets generated from it
  scripts/build-app.sh         release build wrapped as build/iStation.app, ad-hoc signed
  source/
    infrastructure/            CLAUDE.md · bytes/ locations/ bundles/ process/
    data/                      CLAUDE.md · catalog/ iso9660/ systemcnf/ paramsfo/ playlists/ emulators/ store/
    business/                  CLAUDE.md · identification/ scanning/ discovery/ launching/ library/
    presentation/              CLAUDE.md · styles/ shell/ library/ settings/ app/
    main/iStationApp.swift     the @main entry point (not a module)
  tests/
    infrastructure/ data/ business/ presentation/   CLAUDE.md each · one directory per module
    support/                   sandbox/ (infrastructure) · discfixtures/ (data) · libraryfakes/ (business)
    architecture/              the layering, layer-context and project-rule checks
```

## Build, test, run

All from `src/istation/` unless noted.

| Task | Command |
|---|---|
| Build | `swift build` |
| Strict build (CI) | `swift build --explicit-target-dependency-import-check=error` |
| Test (includes the layering and layer-context checks) | `swift test` |
| One module's tests | `swift test --filter DataStoreTests` |
| Only the architecture checks | `swift test --filter ArchitectureTests` |
| Build one module alone | `swift build --target PresentationSettings` |
| Run | `swift run iStation` |
| App bundle | `./scripts/build-app.sh` → `build/iStation.app` |
| Xcode (repo root) | `open iStation.xcodeproj`, scheme `iStation`: ⌘R runs, ⌘U runs every test |
| All tests through Xcode (repo root) | `xcodebuild test -project iStation.xcodeproj -scheme iStation -destination 'platform=macOS'` |
| Docs validator (repo root) | `python3 scripts/validate_docs.py documentation` |
| Lint / format | _TODO:_ none chosen |

## The test table

Every test target is Swift Testing, named `<Layer><Module>Tests`, at `tests/<layer>/<module>/`.

| Suite | Layer | What it covers |
|---|---|---|
| `InfrastructureBytesTests` | Infrastructure | little-endian reads; out-of-range reads are 0 |
| `InfrastructureLocationsTests` | Infrastructure | a sandbox home's layout |
| `InfrastructureBundlesTests` | Infrastructure | an app's binary; first app by folder then name |
| `InfrastructureProcessTests` | Infrastructure | exit status and duration of `/bin/sh`; a missing binary throws |
| `DataCatalogTests` | Data | game IDs by path and by title ID |
| `DataISO9660Tests` | Data | find and read a file in cooked and raw images; reject non-ISO |
| `DataSystemCNFTests` | Data | PS1/PS2 boot keys, serials, PSX.EXE, no boot key |
| `DataParamSFOTests` | Data | strings, title line breaks, garbage rejected |
| `DataPlaylistsTests` | Data | cue files quoted and unquoted; m3u comments; unreadable files |
| `DataEmulatorsTests` | Data | each emulator's flags (the launch contract), the RPCS3 folder |
| `DataStoreTests` | Data | save/load round trip; missing sections and fields; the recorded v0.0.1 file |
| `BusinessIdentificationTests` | Business | disc beats hint beats extension/size; PS3 folders; folder hints; title cleaning |
| `BusinessScanningTests` | Business | cue/bin and m3u folding, PS3 folders, duplicates, RPCS3 installed titles |
| `BusinessDiscoveryTests` | Business | usual app names first, bundle ID fallback |
| `BusinessLaunchingTests` | Business | the command, not set up, a process that won't start, the error text |
| `BusinessLibraryTests` | Business | load and detection, rescans keep history, folders, one game at a time, play time, save failures, queries |
| `PresentationStylesTests` | Presentation | each console has its own symbol and tint |
| `PresentationShellTests` | Presentation | titles and queries per place, counts, the folder chooser, the error alert |
| `PresentationLibraryTests` | Presentation | tiles follow the query, playing marks a tile, detail text, the empty state |
| `PresentationSettingsTests` | Presentation | emulator rows, choosing an app, toggles saved, folder hints and removal |
| `PresentationAppTests` | Presentation | the composition over a sandbox home: file location, discovery, the grid follows the shell |
| `ArchitectureTests` | — | `LayeringTests`, `LayerContextTests`, `ProjectRulesTests` (ADRs 0001–0008) |

## Modules

### Infrastructure

- **`bytes`** (`InfrastructureBytes`) — `LittleEndian.swift`: `[UInt8].u16le(_:)`, `.u32le(_:)`; a read past either end is 0. Used by `iso9660`, `paramsfo`.
- **`locations`** (`InfrastructureLocations`) — `Locations.swift`: `Locations { home, applicationSupport, applications }`, `Locations.user()` (the real folders; the entry point only), `Locations.sandbox(root:)`.
- **`bundles`** (`InfrastructureBundles`) — `AppBundles.swift`: `AppBundles.executable(inAppBundle:)`, `AppBundles.firstApp(named:in:)`; `protocol AppLookup` and `LaunchServicesLookup` (bundle ID → app URL via `LSCopyApplicationURLsForBundleIdentifier`).
- **`process`** (`InfrastructureProcess`) — `ProcessRunner.swift`: `Command`, `ProcessExit { status, duration }`, `protocol ProcessRunning`, `ProcessRunner` (Foundation `Process`; `onExit` on an arbitrary thread). The only module that starts a process.

### Data

- **`catalog`** (`DataCatalog`) — `Platform.swift` (`ps1`/`ps2`/`ps3`, display and short names), `Game.swift` (`BootTarget`, `Game` with its derived `id`, `LibraryFolder`).
- **`iso9660`** (`DataISO9660`) — `ISO9660.swift`: `SectorReader` (internal; detects raw 2352-byte sectors by the sync pattern), `ISO9660(url:)`, `entries(in:)`, `find(_:)`, `read(_:maxBytes:)`, `close()`, `DiscError`.
- **`systemcnf`** (`DataSystemCNF`) — `SystemCNF.swift`: `SystemCNF(text:)` → `platform`, `serial`; `BOOT2` means PS2, `BOOT` PS1.
- **`paramsfo`** (`DataParamSFO`) — `ParamSFO.swift`: `ParamSFO(bytes:)`, `ParamSFO(url:)`, `title`, `titleID`, `category`, `ParamSFOError`.
- **`playlists`** (`DataPlaylists`) — `Playlists.swift`: `Playlists.cueTracks(_:)`, `Playlists.m3uEntries(_:)`.
- **`emulators`** (`DataEmulators`) — `EmulatorKind.swift` (names, console, bundle identifier, app names); `LaunchContract.swift` (`LaunchOptions`, `LaunchContract.arguments(for:booting:options:)`, `RPCS3Layout.installedGamesFolder(applicationSupport:)`).
- **`store`** (`DataStore`) — `LibraryStore.swift`: `AppSettings` (tolerant decoding), `LibraryState`, `LibraryStore(fileURL:)`, `LibraryStore.file(inApplicationSupport:)`, `load()`, `save(_:)`.

### Business

- **`identification`** (`BusinessIdentification`) — `DiscIdentifier.swift`: `DiscInfo`, `DiscIdentifier.identify(image:)`, `identify(ps3DiscFolder:)`, `identify(file:hint:)` (the fallbacks), `platformHint(fromPath:)`, the game-file extension sets; `TitleCleaner.swift`.
- **`scanning`** (`BusinessScanning`) — `LibraryScanner.swift`: `scan(folders:)` (deduplicated, sorted by title), `scan(folder:hint:)`, `scanRPCS3Installed(gameFolder:)`.
- **`discovery`** (`BusinessDiscovery`) — `EmulatorDiscovery.swift`: `EmulatorDiscovery(locations:lookup:)`, `installedApp(for:)`.
- **`launching`** (`BusinessLaunching`) — `GameLauncher.swift`: `EmulatorChoice.emulator(for:)`, `LaunchError`, `GameLauncher(runner:)` with `command(for:appBundle:options:)` and `start(_:appBundle:options:onExit:)`.
- **`library`** (`BusinessLibrary`) — `Library.swift`: `LibraryFilter`, `@MainActor @Observable Library` (state: `games`, `folders`, `settings`, `isScanning`, `runningGameID`, `lastError`; intents: `addFolders`, `removeFolder`, `setPlatformHint`, `rescan`, `updateSettings`, `detectEmulators`, `launch`, `dismissError`; queries: `games(for:matching:)`, `count(of:)`, `rpcs3GameFolder`). `PlayHistory.swift`: `merge(scanned:previous:)`. `Services.swift`: the protocols `LibraryPersisting`, `LibraryScanning`, `EmulatorDetecting`, `GameStarting`, and the live conformances of `LibraryStore`, `LibraryScanner`, `EmulatorDiscovery`, `GameLauncher`.

### Presentation

```
source/presentation/
  styles/        Palette.swift  Symbols.swift  Metrics.swift  Typography.swift
  shell/         Views/ (ShellView, SidebarView, ShellCommands)  ViewModels/ (ShellViewModel, SidebarItem)  Previews/
  library/       Views/ (LibraryGridView)  ViewModels/ (LibraryGridViewModel)  Components/ (GameTile)  Models/ (GameTileModel)  Previews/
  settings/      Views/ (SettingsView)  ViewModels/ (SettingsViewModel, EmulatorRow)  Previews/
  app/           Views/ (AppScenes, MainWindow, AppDelegate)  ViewModels/ (AppViewModel)  Previews/
```

- **`styles`** (`PresentationStyles`) — `Palette` (role colors, `tint(for:)` per console), `Symbols`, `Metrics`, `Typography`. No components yet.
- **`shell`** (`PresentationShell`) — `ShellViewModel` (`route: SidebarItem?`, `search`, `isChoosingFolders`, `title`, `filter`, counts, `errorMessage`; `chooseFolders`, `addFolders`, `rescan`, `dismissError`); `ShellView<Detail>` (split view, search, toolbar, folder importer, alert); `SidebarView`; `ShellCommands` (⌘O, ⌘R).
- **`library`** (`PresentationLibrary`) — `LibraryGridViewModel(library:query:requestFolders:)` (`tiles`, `play`, `chooseFolders`); `GameTileModel`; `LibraryGridView`; `GameTile`.
- **`settings`** (`PresentationSettings`) — `SettingsViewModel` (`emulators`, `chooseApp`/`useApp`, `detectEmulators`, `startsFullscreen`, `skipsBIOSIntro`, folders, `includesRPCS3InstalledGames`, `rpcs3GameFolderPath`); `SettingsView`.
- **`app`** (`PresentationApp`) — `AppViewModel(locations:runner:lookup:)` (builds `LibraryStore`, `LibraryScanner`, `GameLauncher`, `EmulatorDiscovery`, the `Library`, and the three view-models; `isPlaying`); `AppScenes` (window + commands + Settings); `MainWindow` (activates the app when a game ends); `AppDelegate`.

## Recipes

### Adding a module

1. Decide its layer (the lowest one that can hold it) and its one-phrase concern.
2. Create `src/istation/source/<layer>/<module>/` and `src/istation/tests/<layer>/<module>/`, each with at least one Swift file.
3. Add its row to `modules` in `Package.swift`: `Module(.<layer>, "<Name>", uses: [<targets>], testSupport: [<support targets>]),` — on one line; its target is `<Layer><Name>`.
4. Add its name to its layer card's **Modules** line and a row to [ADR 0002](../adrs/module-map.md)'s table (`| <layer> | \`<module>\` | <uses> |`), and a `<TestableReference>` for its `<Layer><Name>Tests` target to `iStation.xcodeproj/xcshareddata/xcschemes/iStation.xcscheme` (copy a neighbour's block, change the three names).
5. Add it to the Codebase Map in CLAUDE.md and a section above.
6. Run `swift test` — the layering and layer-context checks must pass.

### Adding a place (a Presentation feature module)

1. Create `source/presentation/<place>/Views/` and `ViewModels/`, and `tests/presentation/<place>/`; add its `Module(.presentation, …)` row, usually `uses: ["BusinessLibrary", "DataCatalog", "PresentationStyles"]` plus what its previews' fakes name.
2. Write the view-model first: `@MainActor @Observable`, intents named for what the person does, reading `Library`; test it over `LibraryHarness`.
3. Write the views bound to it, every visual from `styles`, each with a named `#Preview` per visible state inside `#if DEBUG`, over a copy of `Previews/PreviewLibrary.swift`.
4. If the sidebar reaches it: a `SidebarItem` case and its row in `SidebarView`. Build its view-model in `AppViewModel` and mount its view in `MainWindow` or `AppScenes`.
5. Add it to the Presentation card, ADR 0002's table, the Xcode scheme's tests and the Codebase Map. Run `swift test`.

### Adding a view

In its module's `Views/`, one top-level view per file, bound to that module's view-model, visuals from `styles`, with a named `#Preview` per visible state in the same file, inside `#if DEBUG`.

### Adding or promoting a shared component

A component a second module wants moves to `source/presentation/styles/Components/` (never copied): make its inputs plain values and callbacks (no feature view-model), move its previews with it, update both users, delete the original. `styles` may then need `Previews/`.

### Adding a token

Add it to `Palette`, `Symbols`, `Metrics` or `Typography`, named for its role (`badgeInset`, `secondaryText`), and replace the literal that prompted it. `ArchitectureTests` rejects literal colors, sizes and paddings in feature views.

### Changing an emulator's flags

Read the flag in the emulator's own argument parser (the source files in [the launch contract](../reference/emulator-launch-contract.md)); change `LaunchContract.arguments(for:booting:options:)`; update `LaunchContractTests` and the reference document in the same change.

### Adding a persisted field

Add it with a default, decode it with `decodeIfPresent` (give `Game` or `LibraryFolder` a custom `init(from:)` on its first new field), and add a new `v<x.y.z>` recording to `RecordedLibraryFileTests` from the real encoder; never edit an old recording. Update [reference/library-file.md](../reference/library-file.md).

### Adding a disc format

A new Data module per format (e.g. `chd`), read by `DiscIdentifier.identify(file:hint:)` in Business; its fixtures are built in memory in `SupportDiscFixtures` — never a real image.

### Proving an architecture rule

Plant the violation (an import, a directory, a row), run `swift test --filter ArchitectureTests`, confirm the failure names the rule in brackets and the file, then remove the plant. A rule SwiftPM itself refuses to load (a cycle, `styles` using a sibling) is planted in a copy of `Package.swift` and checked with `ISTATION_ARCHITECTURE_MANIFEST=<copy> swift test --filter ArchitectureTests`: the checks parse the copy while the build uses the real manifest. An import that would not compile is planted inside `#if false`, which the compiler skips and the check still reads.
