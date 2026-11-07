# The skeleton and both build routines — the packages, the macOS and iOS apps, App Store and personal routines; the library app removed

**What / why.** The brief's second task (2026-11-07): the package skeleton and both build routines, producing empty macOS and iOS apps — and, by the user's call the same day, the retirement of today's library app ([ADR 0016](../../adrs/two-build-routines-and-a-fresh-start.md)). The repository today (2026-11-07): one Swift package of 21 modules (folder scanning, disc identification, launching DuckStation, PCSX2 and RPCS3; 111 tests in 22 test targets), `ArchitectureTests`, a thin `iStation.xcodeproj` with no targets of its own and one shared scheme, and `scripts/build-app.sh` making an ad-hoc-signed `build/iStation.app`.

**Core constraint(s).** The layer law over every new module (row, directories, card line, ADR 0002 row, scheme entry). Release builds carry no tools: TraceKit and every debug view under `#if PERSONAL_BUILD`; the App Store entitlements never carry `allow-unsigned-executable-memory` or `get-task-allow` ([ADR 0016](../../adrs/two-build-routines-and-a-fresh-start.md)). Cores import no UI or Apple framework ([ADR 0015](../../adrs/a-core-is-a-cpu-module-and-a-console-module.md)). The real home untouched by tests. The user's signing identity and App Store Connect are the user's.

**Seam + files.**
- **Retire** the library app: its modules except the four format readers that stay (`bytes`, `iso9660`, `playlists`, `systemcnf`, with their tests and `SupportDiscFixtures`), its tests, previews and fakes, the entry point `source/main/iStationApp.swift`, `scripts/build-app.sh`, and the two contracts (`reference/emulator-launch-contract.md`, `reference/library-file.md`) with their ADR 0002 rows, layer-card lines, Codebase Map rows and DEVELOPER.md sections.
- **Package** (`src/istation/Package.swift`): platforms macOS 14 and iOS 17; the products `PS1Core` and `EmuKit` (and `TraceKit` when 3c lands) over new modules — a placeholder Business module for the PS1 console and a Presentation module for EmuKit's player view — in the module map.
- **Apps** in `iStation.xcodeproj`: a macOS target and an iOS target (SwiftUI shells: an empty player and an acknowledgements placeholder), each depending on the package's products, with placeholder bundle identifiers.
- **Routines**: `Config/AppStore.xcconfig` and `Config/Personal.xcconfig` (`PERSONAL_BUILD` in the personal one's active compilation conditions); entitlements per app per routine (macOS App Store: App Sandbox, user-selected file access, `allow-jit` per 3a; personal: `get-task-allow`, JIT on); one scheme per app per routine; `scripts/archive-appstore.sh` (`xcodebuild archive` with an export-options plist) and `scripts/build-personal.sh`.
- **Checks** (`ArchitectureTests`): TraceKit imports and debug views only under `#if PERSONAL_BUILD`; the App Store entitlements free of the two forbidden keys; the scheme check updated to the new schemes and test targets.
- **CI** (`.github/workflows/ci.yml`): also builds both apps' personal routine without signing.
- **Docs**: CLAUDE.md (stack, Codebase Map, release), DEVELOPER.md (tree, commands, recipes), the layer cards, ADR 0002's table, the root README.

**Reference.** Apple's App Sandbox, hardened runtime and `xcodebuild archive` / `-exportArchive` documentation. In-house: Milestone B's thin project and its scheme check; ADR 0016.

**Decisions made** (dated):
- 2026-11-07: start the apps fresh; the library app and its launcher retire (the user's call).
- 2026-11-07: two routines per app, `PERSONAL_BUILD`, xcconfig and entitlements per routine, one scheme or script per routine (the user's brief).
- 2026-11-07: the brief's packages are products of the one layered package; the apps are targets in `iStation.xcodeproj` (the re-vision's default, taken).
- 2026-11-07: the four format readers written for iStation — `bytes`, `iso9660`, `playlists`, `systemcnf` — stay, with their tests and `SupportDiscFixtures`, as shared modules for v0.2.0's disc images; everything else of the library app retires (the default, confirmed by the user).
- 2026-11-07: iOS 17 is the minimum deployment target (the default, confirmed by the user).
- 2026-11-07: `PS2Core` is created with the PS2 work (v2.x), not as an empty product now (the default, confirmed by the user).
- 2026-11-07: placeholder bundle identifiers until the user's App Store Connect identifiers exist (v1.0.0); the identifiers and team are the user's (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-07.

**Guardrail(s).** The two new checks fail on a planted violation (a TraceKit import outside `#if PERSONAL_BUILD`; `get-task-allow` in an App Store entitlements file) and pass once it is removed; `swift test` and both apps' builds pass in CI.

**Acceptance criteria:**
- [ ] The library app's code, tests, script and contracts are gone; `swift test` and the strict build pass with what remains.
- [ ] The macOS and iOS apps build in both routines; the App Store routine produces an archive (uploading is the user's); the personal build shows that it is one.
- [ ] Release builds contain no TraceKit or debug UI, and their entitlements carry neither forbidden key — checked.
- [ ] Every new module is in the module map, its layer card, ADR 0002's table and the scheme.

**Scope note.** v0.0.1, track 3; gated on 3a (its result decides the macOS App Store entitlements). 3c adds TraceKit; 3e and 3f fill PS1Core. Out of scope: anything the apps play (from 3e on), the acknowledgements screen's content (v1.0.0), App Store submission (v1.0.0).
