# The Infrastructure layer

**Position.** First of the four ([ADR 0001](../../../../documentation/adrs/darwin/layer-enforcement.md)): the mechanisms everything stands on, behind one small interface each. Today only byte decoding; the cores' hosts (memory, clocks, audio and video sinks) arrive as the cores need them.

**Modules:** `bytes` (little-endian reads over byte buffers)

**May depend on:** Infrastructure only, and system frameworks that draw nothing (Foundation) — never SwiftUI, AppKit or UIKit. Nothing in the package starts a process or loads code at runtime ([ADR 0013](../../../../documentation/adrs/darwin/shipped-code-derives-only-from-permissive-references.md)), and nothing reaches the real home folder ([ADR 0004](../../../../documentation/adrs/darwin/tests-mirror-architecture.md)).

**Enforced by:** one SwiftPM target per module, generated from the module map in `lib/src/darwin/Package.swift` (an undeclared import fails `swift build --explicit-target-dependency-import-check=error`), and `ArchitectureTests` (`lib/src/darwin/tests/architecture/`), which runs inside `swift test`.

**Changing this layer:**
- A new module: its directory `source/infrastructure/<module>/`, its `Module(.infrastructure, "<Name>")` row in `Package.swift`, its tests in `tests/infrastructure/<module>/` (and in the `macOS Personal` scheme of `lib/src/darwin/iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/adrs/darwin/module-map.md)'s table — in the same change.
- A new OS mechanism enters behind a protocol, so the layers above test over fakes and never touch the real system.

**Depth:** [the ADRs](../../../../documentation/adrs/darwin/README.md) · [CLAUDE.md](../../../../documentation/assistant/darwin/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/assistant/darwin/DEVELOPER.md).
