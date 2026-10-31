# The Presentation layer

**Position.** Fourth of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): the SwiftUI app — the main window's chrome, the game grid, the Settings window, and the composition that wires them to the `Library`.

**Modules:** `styles` (tokens: palette, symbols, metrics, typography), `shell` (the chrome: sidebar route, search, toolbar, menu commands, error alert), `library` (the game grid, its tiles and empty state), `settings` (the Settings window), `app` (the composition root of view-models; the scenes)

**Shape** ([ADR 0005](../../../../documentation/istation/adrs/presentation-mvvm.md)): every module but `styles` is `Views/` + `ViewModels/`, with `Components/`, `Models/` or `Previews/` only as real files need them. A view binds to its view-model, the view-model consumes Business through the injected `Library`, and no file under `ViewModels/` or `Models/` imports SwiftUI, AppKit, UIKit or Cocoa. `styles` leans on no sibling; every other module may use it, and every color, font and size comes from it. A component a second module wants is promoted to `styles`, never copied.

**Seen on its own** ([ADR 0006](../../../../documentation/istation/adrs/presentation-previews.md)): every module is its own SwiftPM target with its own test target; every view has named `#Preview`s per visible state, over the module's own fakes in `Previews/`, inside `#if DEBUG`, never touching disk, processes or the real home folder.

**May depend on:** all four layers. Views and components import no Business module; only `app` knows the concrete services.

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:** a new place is a module `source/presentation/<place>/` with `Views/` and `ViewModels/`, its `Module(.presentation, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/presentation/<place>/` (and in the `iStation` scheme of `iStation.xcodeproj`), a `SidebarItem` case in `shell` if the sidebar reaches it, its view-model built in `app`, a preview for every view it draws, and its name on this card's Modules line and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table.

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
