# The Infrastructure layer

**Position.** First of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): the macOS mechanisms iStation stands on, each behind one small interface — reading bytes, the user's folders, app bundles, child processes. It knows nothing about games or emulators.

**Modules:** `bytes` (little-endian reads over byte buffers), `locations` (the user's standard folders, as one injectable value), `bundles` (.app bundles: their binary, an app by bundle identifier), `process` (start a child process, report its exit and duration)

**May depend on:** Infrastructure only, and system frameworks that draw nothing (Foundation, CoreServices) — never SwiftUI or AppKit. Two finer rules ([ADR 0013](../../../../documentation/istation/adrs/shipped-code-derives-only-from-permissive-references.md), [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)): `process` is the only module in the app that starts a process, and `locations` is the only one that reaches the real home folder — through `Locations.user()`, which only the entry point calls.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift` (an undeclared import fails `swift build --explicit-target-dependency-import-check=error`), and `ArchitectureTests` (`src/istation/tests/architecture/`), which runs inside `swift test`.

**Changing this layer:**
- A new module: its directory `source/infrastructure/<module>/`, its `Module(.infrastructure, "<Name>")` row in `Package.swift`, its tests in `tests/infrastructure/<module>/` (and in the `iStation` scheme of `iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table — in the same change.
- A new OS mechanism enters behind a protocol (as `ProcessRunning` and `AppLookup` do), so the layers above test over fakes and never touch the real system.

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
