# ADR 0004 — Tests live in the layer of what they test

**Status:** Accepted · **Date:** 2026-10-31

## Context

A test tree with its own geography answers "where is this tested?" with a search instead of a path, and a test that reaches across layers freely is an undeclared dependency. The scaffold's one test file covered five concerns; its fixtures (`makeISO`, `makeSFO`) were needed by the format tests and the scanner tests alike.

## Decision

**The test tree follows the architecture, and a test is written in the layer of the thing it tests.**

- `src/istation/tests/<layer>/<module>/` mirrors `src/istation/source/<layer>/<module>/`; a new module brings its test directory in the same change.
- A test obeys the same dependency law as its subject: it imports its module, that module's declared edges and its declared test support, nothing more — a Data test does not reach into Business for its fixtures.
- A behavior spanning layers is tested **in the highest layer involved** (scanning a folder of fixture discs is a Business test).
- Shared fixtures and fakes sink like shared code: `SupportSandbox` (infrastructure), `SupportDiscFixtures` (data), `SupportLibraryFakes` (business).
- Tests are hermetic: no network; nothing written outside the test's own `Sandbox` (a uniquely named temporary folder, removed afterwards); never the real home folder, real Application Support, real emulators, real games or Launch Services. Previews follow the same rule ([ADR 0006](presentation-previews.md)).

## Consequences

- The test tree is a map of coverage: an empty `tests/<layer>/<module>/` is a visible hole and fails the check.
- Moving a module moves its tests in the same change.
- A test that cannot be written without an upward dependency is exposing a design fault in its subject.
- The real home is reached in exactly one place, `Locations.user()`, called only by the entry point — so the whole app can be pointed at a sandbox, and is, in every test.

## Enforcement

`ArchitectureTests/LayerContextTests.swift` checks the mirrored shape (every module has tests, no orphan test directories, every support directory has its row). `ArchitectureTests/LayeringTests.swift` applies the dependency law to test and support targets exactly as to the source. `ArchitectureTests/ProjectRulesTests.swift` fails on any reach for the real home (`homeDirectoryForCurrentUser`, `NSHomeDirectory`, `applicationSupportDirectory`, `FileManager.default.urls(for:`) outside `InfrastructureLocations`, and on `.user()` outside the entry point. Each verified against a planted violation, 2026-10-31.
