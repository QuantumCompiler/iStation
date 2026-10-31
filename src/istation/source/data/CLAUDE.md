# The Data layer

**Position.** Second of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): the shapes of the outside world — the library's record types, the disc and metadata file formats, each emulator's launch contract, and `library.json`. It knows the shapes, not the rules.

**Modules:** `catalog` (Platform, Game, BootTarget, LibraryFolder), `iso9660` (2048/2352-byte sectors and the ISO 9660 directory tree), `systemcnf` (SYSTEM.CNF: boot key to console and serial), `paramsfo` (PARAM.SFO key/value metadata), `playlists` (.cue tracks and .m3u discs), `emulators` (each emulator's identity and command line), `store` (library.json persistence)

**May depend on:** Data and Infrastructure. Each format reader stays one format; a type two modules need sinks to `catalog`.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:**
- A new module: its directory `source/data/<module>/`, its `Module(.data, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/data/<module>/` (and in the `iStation` scheme of `iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table — in the same change.
- Readers tolerate the unknown: a truncated or foreign file is `nil` or a thrown error, never a trap.
- `library.json` is read compatibly ([ADR 0007](../../../../documentation/istation/adrs/backwards-compatibility.md)): a new persisted field decodes with `decodeIfPresent` and a default, and a changed shape adds a recorded fixture to `RecordedLibraryFileTests`.
- The emulators' flags change only against their own sources ([reference/emulator-launch-contract.md](../../../../documentation/istation/reference/emulator-launch-contract.md)), pinned by `LaunchContractTests`.

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
