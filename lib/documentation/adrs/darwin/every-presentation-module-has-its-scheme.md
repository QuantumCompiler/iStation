# ADR 0017 — Every Presentation module has its own shared Xcode scheme

**Status:** Accepted · **Date:** 2026-11-14

## Context

The Xcode project had four shared schemes, one per app per routine (ADR 0016); the package's modules took only the schemes Xcode creates by itself, per user and uncommitted. ADR 0006 makes every Presentation module stand alone — it builds and tests alone, and its views preview over its own fakes — but working on one in Xcode meant the whole app's scheme, and a preview builds the active scheme. The user's Apogee repository gives each Presentation module a scheme of its own (its darwin ADR 0004), and the user's call for iStation, 2026-11-14 (v0.0.1 item 4b, vetoing the default to wait for more modules), is the same.

## Decision

- **Every Presentation module in the module map has a shared scheme**, `lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/<Target>.xcscheme`, named exactly as its target (`PresentationPlayer.xcscheme`): committed under `xcshareddata`, never left to Xcode's automatic schemes.
- **Its Build action builds the module's target**, its dependencies with it; **its Test action runs the module's own bundle**, `<Target>Tests`, in Debug, so ⌘U there tests that module alone. A library has no Run action executable.
- **The app schemes stay the whole**: `macOS Personal` still tests every bundle (ADR 0019's scheme check), and the build scripts and CI build only the app schemes. A module's scheme is for working on that module — its previews, its tests — never a second way to build or ship.
- Lower layers take no scheme by this record: they draw nothing.

## Consequences

- Each Presentation module can be built, previewed and tested alone in Xcode.
- A new Presentation module comes with its scheme file, in the same change as its `Module` row (the layer law's list).

## Enforcement

`ArchitectureTests/LayerContextTests.swift` (`everyPresentationModuleHasItsScheme`): for every Presentation module in `Package.swift`, its scheme file exists, builds its target and tests its bundle.
