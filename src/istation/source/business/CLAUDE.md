# The Business layer

**Position.** Third of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): what iStation does — decide what a disc is, find the games in a folder, find the installed emulators, launch one game at a time, and keep the library with its play history. The one place behavior lives.

**Modules:** `identification` (what one disc image or folder is: console, serial, title), `scanning` (library folders into games), `discovery` (find installed emulator apps), `launching` (start a game in its emulator and time the session), `library` (the library's state and rules: folders, rescans, play history, the one running game)

**May depend on:** Business, Data and Infrastructure — and no UI framework. `library`'s services are protocols (`LibraryPersisting`, `LibraryScanning`, `EmulatorDetecting`, `GameStarting`); the live conformances sit beside them in `Services.swift`, and only PresentationApp constructs them.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:**
- A new module: its directory `source/business/<module>/`, its `Module(.business, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/business/<module>/` (and in the `iStation` scheme of `iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table — in the same change.
- One implementation per decision: a rule the views need (which games a place shows, which emulator runs a console) lives here once, never in a view-model.
- Installed emulators are reached only through `launching` → `InfrastructureProcess`, by command line and process exit — the retiring library app's rule, until v0.0.1's item 3b removes it.
- Cores (from v0.0.1) live here: one module per CPU family, generic over its bus, and one per console; no UI or Apple frameworks; ported only from ProjectPSX or Play!, each file naming its source and keeping its notice; hot paths use concrete types ([ADR 0013](../../../../documentation/istation/adrs/shipped-code-derives-only-from-permissive-references.md), [ADR 0015](../../../../documentation/istation/adrs/a-core-is-a-cpu-module-and-a-console-module.md)).

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
