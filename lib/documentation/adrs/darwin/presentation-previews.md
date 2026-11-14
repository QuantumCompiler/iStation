# ADR 0006 — Every Presentation module stands alone, and every view has its previews

**Status:** Accepted, with the preview-data plan in §3 superseded by [ADR 0009](previews-never-carry-the-users-library.md) · **Date:** 2026-10-31

## Context

A screen's look is otherwise checked only by running the whole app against a real library and real emulators — slow, unrepeatable, and, for iStation, impossible without the user's own games. And working on one place should not mean building all of them.

## Decision

### 1. Each Presentation module builds and tests on its own

Every Presentation module, `styles` and `app` included, is its own SwiftPM library target with its own test target, generated from its module-map row: `swift build --target PresentationSettings` builds it alone and `swift test --filter PresentationSettingsTests` runs its tests alone. The whole-app build (`swift build`, the `iStation` executable) stays the one way to build and ship.

### 2. Every view has named previews, one per visible state

- Every top-level view in `Views/` and `Components/` has at least one `#Preview("<State>")` in its own file, named for the state it shows ("Empty library", "Library", "Scanning", "Playing", "Error", "Nothing set up").
- A view whose look changes with its view-model's state previews each state a person sees differently. A composite view previews the composition's default state; its parts' states are previewed in their own modules (`MainWindow` previews "First launch").

### 3. Previews are hermetic, as tests are

- A preview never touches disk, real user data, real processes, Launch Services or the network.
- It builds the view's **real view-model over in-module fakes** (`Previews/PreviewLibrary.swift`: an in-memory store, a scanner that returns fixed games or never finishes, a starter that starts nothing, a detector that finds nothing) and drives it **through its public intents** — "Playing" calls `play`, "Error" launches a second game while one runs.
- **Its data is real-shaped data**: the games are those `LibraryScanner` reports for the disc fixtures in `tests/support/discfixtures` (same titles, serials and boot targets). A recorded `library.json` from a real library replaces them once the phase-1 gate has run (item 1a).
- Preview support is **debug-only** (`#if DEBUG`) and per module: a fake a second module wants is copied, since preview code is not shipped code and never justifies a shared module. `shell`, `library` and `settings` each carry their copy of `PreviewLibrary`.

## Consequences

- Any place can be built, previewed and tested alone, with no library, no emulator and no games.
- The cost: a new view comes with its previews; a new module with its targets; a re-recorded fixture with its previews' updates in the same change.
- **Previews show; tests decide.** A preview never substitutes for a view-model test.

## Enforcement

The module map generates every module's target and test target ([ADR 0002](module-map.md)). `ArchitectureTests/LayeringTests.swift` fails on a view (`struct …: View` in `Views/` or `Components/`) whose file has no named `#Preview("…")`, on `#Preview` outside `#if DEBUG`, and on a `Previews/` file that does not open with `#if DEBUG`. That a preview fake names no real runner or store is held by review. Each mechanical rule verified against a planted violation, 2026-10-31.
