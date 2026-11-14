# ADR 0005 — Presentation modules are MVVM, and share one styles module

**Status:** Accepted · **Date:** 2026-10-31

## Context

[ADR 0001](layer-enforcement.md) fixes the layers but says nothing about a Presentation module's inside, and that is where a UI codebase drifts first. The scaffold's `LibraryModel` was the app's one state object: it held the queries, the play-history rules and the one-game-at-a-time rule, and it imported AppKit for `NSOpenPanel`, `NSWorkspace` and `NSApp.activate`, so none of it could be tested without a running app. Its views hard-coded every color and size. The user chose MVVM for this project on 2026-10-31 (the construction, with the `mvvm-architecture` conventions).

## Decision

**iStation's Presentation layer is organized by MVVM**, in SwiftUI's idiom: views are `View` structs; view-models are `@MainActor @Observable` classes importing Foundation, Observation and the lower layers only.

### The modules

- **One feature module per user-facing place**: `library` (the game grid) and `settings` (the Settings window) today.
- **`styles`** — the shared visual vocabulary: `Palette` (roles, including each console's placeholder tint), `Symbols`, `Metrics` (every size and spacing), `Typography`, and the components more than one module uses (none yet). It depends on no sibling Presentation module; every other module may use it. Light and dark appearance come from the system colors it names; there is no custom theme yet.
- **`shell`** — the chrome around every screen: the sidebar and its route (`SidebarItem`, a value in `ShellViewModel`), the search field, the toolbar, the File-menu commands (⌘O, ⌘R), the folder chooser and the error alert. Other places read the route through `shell`.
- **`app`** — the composition root: `AppViewModel` builds the real services over one `Locations`, the `Library` on top, and every place's view-model; its views are the scenes (`AppScenes`, `MainWindow`) and the `AppDelegate`. The only module that knows concrete implementations.
- **The entry point** (`source/main/iStationApp.swift`) is not a module: it builds `AppViewModel(locations: .user())`, starts `AppScenes`, and holds no logic.

### Inside a feature module

- **`Views/`** — views: layout, binding and purely visual concerns, including AppKit calls that are purely visual (`NSWorkspace.activateFileViewerSelecting` for Show in Finder; `NSApplication.activate` when a game ends). No business logic, no service calls, no Business imports; every color, font and size from `styles`.
- **`ViewModels/`** — the module's state and intents. **No file here imports SwiftUI, AppKit, UIKit or Cocoa.** Intents are methods named for what the person does (`play`, `chooseFolders`, `useApp`); a chooser's visibility is a plain `Bool` the view binds `.fileImporter` to. A view-model reads the `Library` (Business's one source of truth, whose services are injected protocols) and shows its state as last read; it never mirrors it.
- **Further directories only when real files need them**: `Components/` (`library/Components/GameTile`), `Models/` (`library/Models/GameTileModel`, a tile's display values — UI-free like a view-model), `Previews/` (preview fakes, [ADR 0006](presentation-previews.md)).

### The edges

- A view binds to its view-model; the view-model consumes Business; a view never reaches Business, and a view-model never references a view.
- Every module may use `styles`; `styles` uses no sibling. `app` composes every module; nothing depends on `app`.
- Features do not depend on each other: the grid learns the shell's place and search through a query closure `app` wires, and asks the shell for its folder chooser the same way.

### Components

A component is presentational — plain values in (`GameTile` takes a `GameTileModel`), events out; it never takes a feature's view-model. A component born in one module is **promoted to `styles/Components/` the moment a second module wants it** — moved, never copied. The couch-mode library (ROADMAP v0.4.0) is the expected first promotion of `GameTile`.

## Consequences

- A new place starts as a module with `Views/` and `ViewModels/`; its behavior lives in its view-model and in `Library`, so its tests are scripted-input tests over fakes, not UI automation.
- The scaffold's AppKit dependencies were resolved downward or into views: `NSOpenPanel` became SwiftUI's `.fileImporter`; Launch Services replaced `NSWorkspace.urlForApplication(withBundleIdentifier:)` in Infrastructure. One behavior changed: the emulator chooser no longer opens in /Applications (Maintenance item M2).
- Shared visual changes land once, in `styles`; a duplicated component or a literal color in a feature view is rejected by citing this record.
- Chosen trade-off: more files and modules than a view-does-everything layout, accepted because the seam is what makes every screen testable headlessly and every visual decision single-sourced.

## Enforcement

`ArchitectureTests/LayeringTests.swift` fails on: a Presentation module without `Views/` and `ViewModels/`, with a directory outside `Views/ ViewModels/ Components/ Models/ Previews/`, an empty one, or a file at its root; a file under `ViewModels/` or `Models/` importing SwiftUI, AppKit, UIKit or Cocoa; `styles` depending on a sibling; a file under `Views/` or `Components/` importing a Business module; and a literal color, font size, padding, spacing, radius, width, height or opacity in a feature view (`Color(red:`, `.padding(12)`, …). Feature cycles are refused by the map's cycle check. Each verified against a planted violation, 2026-10-31.
