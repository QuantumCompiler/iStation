# The Presentation layer

**Position.** Fourth of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): EmuKit, the SwiftUI views the macOS and iOS apps share — the player and the acknowledgements screen, and the tokens they draw with. The apps themselves are targets in `iStation.xcodeproj` (`src/istation/apps/`), the composition roots.

**Modules:** `styles` (tokens: palette, symbols, metrics, typography), `player` (the player's screen), `acknowledgements` (every notice the app carries)

**Shape** ([ADR 0005](../../../../documentation/istation/adrs/presentation-mvvm.md)): every module but `styles` is `Views/` + `ViewModels/`, with `Components/`, `Models/`, `Previews/` or `Debug/` only as real files need them. A view binds to its view-model, the view-model consumes Business, and no file under `ViewModels/` or `Models/` imports SwiftUI, AppKit, UIKit or Cocoa. `styles` leans on no sibling; every other module may use it, and every color, font and size comes from it. Debug views live in `Debug/`, inside `#if PERSONAL_BUILD` ([ADR 0016](../../../../documentation/istation/adrs/two-build-routines-and-a-fresh-start.md)).

**Seen on its own** ([ADR 0006](../../../../documentation/istation/adrs/presentation-previews.md)): every module is its own SwiftPM target with its own test target; every view has named `#Preview`s per visible state, over the module's own fakes in `Previews/`, inside `#if DEBUG`.

**May depend on:** all four layers. Views and components import no Business module.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:** a new place is a module `source/presentation/<place>/` with `Views/` and `ViewModels/`, its `Module(.presentation, "<Name>", uses: […])` row in `Package.swift` and its place in the `EmuKit` product, its tests in `tests/presentation/<place>/` (and in the `macOS Personal` scheme), its view-model built by the apps, a preview for every view it draws, and its name on this card's Modules line and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table.

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
