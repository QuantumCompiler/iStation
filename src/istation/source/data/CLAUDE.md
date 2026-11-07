# The Data layer

**Position.** Second of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): the shapes of the outside world. The disc-image readers kept for v0.2.0's discs, and TraceKit's trace formats ([reference/trace-formats.md](../../../../documentation/istation/reference/trace-formats.md)). It knows the shapes, not the rules.

**Modules:** `iso9660` (2048/2352-byte sectors and the ISO 9660 directory tree), `systemcnf` (SYSTEM.CNF: boot key to console and serial), `playlists` (.cue tracks and .m3u discs), `tracing` (TraceKit: trace records, files, diff and checkpoints — personal builds only)

**May depend on:** Data and Infrastructure. Each format reader stays one format.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:**
- A new module: its directory `source/data/<module>/`, its `Module(.data, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/data/<module>/` (and in the `macOS Personal` scheme of `iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table — in the same change.
- Readers tolerate the unknown: a truncated or foreign file is `nil` or a thrown error, never a trap.
- `tracing` is a tool: nothing shipped imports it outside `#if PERSONAL_BUILD`, and no app links `TraceKit` in its App Store routine; a change to its bytes changes the reference document and the pinning tests, and bumps the format's version.
- A persisted format the apps write (settings, memory cards, save states) reads compatibly or names its migration; a save state carries its version ([ADR 0016](../../../../documentation/istation/adrs/two-build-routines-and-a-fresh-start.md) §5).

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
