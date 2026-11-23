# The Data layer

**Position.** Second of the four ([ADR 0024](../../../../documentation/adrs/darwin/four-layers-and-business-holds-the-session.md)): the shapes of the outside world. The disc-image readers kept for v0.2.0's discs, TraceKit's trace formats ([reference/trace-formats.md](../../../../documentation/reference/darwin/trace-formats.md)), and the app's own stored records: `library.json`, which keeps the user's BIOS (and from 5d the games) by bookmark, never a copy. It knows the shapes, not the rules.

**Modules:** `iso9660` (2048/2352-byte sectors and the ISO 9660 directory tree), `systemcnf` (SYSTEM.CNF: boot key to console and serial), `playlists` (.cue tracks and .m3u discs), `library` (the app's own records: the store's versioned library.json at a URL the app hands in, the kept BIOS's record, its SHA-1 fingerprint, and the kept files' bookmarks — security-scoped on macOS — and reads), `tracing` (TraceKit: trace records, files, diff and checkpoints — personal builds only)

**May depend on:** Data and Infrastructure. Each format reader stays one format.

**Enforced by:** one SwiftPM target per module, generated from the module map in `lib/src/darwin/Package.swift`, and `ArchitectureTests` (`lib/src/darwin/tests/architecture/`), run by `swift test`.

**Changing this layer:**
- A new module: its directory `source/data/<module>/`, its `Module(.data, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/data/<module>/` (and in the `macOS Personal` scheme of `lib/src/darwin/iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/adrs/darwin/module-map.md)'s table — in the same change.
- Readers tolerate the unknown: a truncated or foreign file is `nil` or a thrown error, never a trap.
- `tracing` is a tool: nothing shipped imports it outside `#if PERSONAL_BUILD`, and no app links `TraceKit` in its App Store routine; a change to its bytes changes the reference document and the pinning tests, and bumps the format's version.
- A persisted format the apps write (settings, memory cards, save states) reads compatibly or names its migration; a save state carries its version ([ADR 0016](../../../../documentation/adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- `library` (`LibraryStore`, `Library`, `BIOSRecord`, `Fingerprint`, `KeptFile`) names no place: the app's target hands `LibraryStore` its URL (in its container, or on the macOS personal build its own Application Support folder), and tests hand it one inside a `Sandbox`. Every field a later version adds to `library.json` decodes with a default, and a library from a later version is refused, never saved over. A save writes `Library.currentVersion` and drops every key the build doesn't know, so a change that adds a field raises `currentVersion`: a build from before it then refuses the file instead of erasing the field. It uses Foundation and CryptoKit only, and compiles for iOS too.

**Depth:** [the ADRs](../../../../documentation/adrs/darwin/README.md) · [CLAUDE.md](../../../../documentation/assistant/darwin/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/assistant/darwin/DEVELOPER.md).
