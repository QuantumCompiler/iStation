# ADR 0020 — Presentation modules are MVVM and share one styles module; the apps are the composition roots

**Status:** Superseded by [ADR 0023](presentation-is-mvvm-and-styles-carries-the-design.md) (2026-11-22): `Palette` carries the design's own colors from its `tokens.json` in three themes and `Theme` the theme setting, where it named SwiftUI's own; the rule otherwise carries · **Date:** 2026-11-14 · Supersedes [ADR 0005](presentation-mvvm.md)

## Context

The layers ([ADR 0001](layer-enforcement.md), restated as [ADR 0018](four-layers-dependencies-point-down.md)) say nothing about a Presentation module's inside, and that is where a UI codebase drifts first. The scaffold's `LibraryModel` was the app's one state object: it held the queries, the play-history rules and the one-game-at-a-time rule, and it imported AppKit for `NSOpenPanel`, `NSWorkspace` and `NSApp.activate`, so none of it could be tested without a running app. Its views hard-coded every color and size. The user chose MVVM for this project on 2026-10-31 (the construction, with the `mvvm-architecture` conventions), and [ADR 0005](presentation-mvvm.md) recorded it.

The library app's retirement ([ADR 0016](two-build-routines-and-a-fresh-start.md), 2026-11-07, [Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)) retired every Presentation module ADR 0005 named — `library`, `settings`, `shell`, `app` and the old `styles`, whose name a new tokens module took — with the examples it gave: `GameTile` and `GameTileModel`, the File-menu commands, `AppViewModel`, `AppScenes`, `MainWindow` and the entry point `source/main/`. The same change moved composition into the apps, Xcode targets outside the package, removed the entry-point checks, and admitted `Debug/` in a Presentation module. ADR 0016's Consequences kept the rule over the new modules, but ADR 0005 was left describing modules that no longer exist, and its Enforcement lists the admitted directories without `Debug/` and never said that `styles` is held to a narrower shape than the other modules, as the check has done since 2026-10-31. Found at v0.0.1's pre-merge docs pass, 2026-11-14. The rule stands; this record restates it for today's tree.

## Decision

**iStation's Presentation layer is organized by MVVM**, in SwiftUI's idiom: views are `View` structs; view-models are `@MainActor @Observable` classes importing Foundation, Observation and the lower layers only.

### The modules

The Presentation modules are the `EmuKit` product's three, in `lib/src/darwin/source/presentation/`:

- **One feature module per user-facing place**: `player` (the player's screen: `PlayerView` over `PlayerViewModel`) and `acknowledgements` (every notice the app carries: `AcknowledgementsView` over `AcknowledgementsViewModel` and its `Acknowledgement` entries) today.
- **`styles`** — the shared visual vocabulary: `Palette` (every color, by role: the screen, text on it, secondary text), `Symbols` (SF Symbol names), `Metrics` (every size and spacing: the 4:3 screen, the player's minimum size, padding, stack spacing), `Typography` (every font, by role), and the components more than one module uses (none yet). It depends on no sibling Presentation module; every other module may use it. There is no custom theme: `Palette` names SwiftUI's own colors.
- **The apps are the composition roots**, not modules. Each entry point — `lib/src/darwin/apps/macos/Sources/iStationApp.swift`, `lib/src/darwin/apps/ios/Sources/iStationApp.swift` — builds the `PS1Console` and every place's view-model, lays out the scenes and their chrome (on macOS the player's window and an Acknowledgements window opened from the app menu by `AcknowledgementsCommand`; on iOS `RootView`, the player in a navigation stack with a toolbar button for the acknowledgements sheet), and holds no logic. Outside tests and previews, nothing else constructs the console or a view-model.

### Inside a feature module

- **`Views/`** — views: layout, binding and purely visual concerns, toolkit calls that are purely visual included. No business logic, no service calls, no Business imports; every color, font and size from `styles`.
- **`ViewModels/`** — the module's state and intents. **No file here imports SwiftUI, AppKit, UIKit or Cocoa.** Intents are methods named for what the person does; a chooser's visibility is a plain `Bool` the view binds `.fileImporter` to. A view-model is given what it reads through its initializer (`PlayerViewModel(console:)` takes the console the app built), consumes Business through it, and never mirrors state Business owns.
- **Further directories only when real files need them**: `Components/` (presentational pieces, below; none yet), `Models/` (plain values the views show, UI-free like a view-model: `acknowledgements/Models/Acknowledgement`), `Previews/` (preview support, [ADR 0021](presentation-modules-stand-alone-and-preview-sample-data.md): `player/Previews/PreviewPlayer`, the player's view-model over a powered-off console), `Debug/` (debug views, each opening with `#if PERSONAL_BUILD` ([ADR 0016](two-build-routines-and-a-fresh-start.md)) and held to the rules of `Views/`; none yet). No file sits at the module's root.

### Inside `styles`

`styles` draws no place of its own, so it has no `Views/` or `ViewModels/`: its tokens sit at its root (`Palette.swift`, `Symbols.swift`, `Metrics.swift`, `Typography.swift`), and the only directories it may have are `Components/` (the shared components) and `Previews/`; it has neither yet. A debug view lives in a feature module, never in `styles`.

### The edges

- A view binds to its view-model; the view-model consumes Business; a view never reaches Business, and a view-model never references a view.
- Every module may use `styles`; `styles` uses no sibling. The apps compose every module; nothing in the package can import an app, since the apps are targets of `lib/src/darwin/iStation.xcodeproj`, not of the package.
- Features do not depend on each other: `player` and `acknowledgements` each use `styles` alone among their siblings, and only the apps put them together. A place that needs another's state or action gets it through a closure an app wires, never an import.

### Components

A component is presentational — plain values in, events out; it never takes a feature's view-model. A component born in one module is **promoted to `styles/Components/` the moment a second module wants it** — moved, never copied.

## Consequences

- A new place starts as a module with `Views/` and `ViewModels/`, its own shared scheme ([ADR 0017](every-presentation-module-has-its-scheme.md)), and its view-model built by each app that shows it. Its behavior lives in its view-model and in Business, so its tests are scripted-input tests over its view-models (`PlayerViewModelTests`, `AcknowledgementsViewModelTests`), not UI automation.
- Shared visual changes land once, in `styles`; a duplicated component or a literal color in a feature view is rejected by citing this record.
- Composition is per app: the two entry points build the same view-models and lay out their own chrome — two windows and a menu command on macOS, a navigation stack and a sheet on iOS.
- Chosen trade-off: more files and modules than a view-does-everything layout, accepted because the seam is what makes every screen testable headlessly and every visual decision single-sourced.

## Enforcement

`ArchitectureTests/LayeringTests.swift`:

- `presentationModulesHaveTheMVVMShape` fails on a Presentation module other than `styles` with a directory outside `Views/ ViewModels/ Components/ Models/ Previews/ Debug/`, without `Views/` or `ViewModels/`, or with a Swift file at its root; on `styles` with a directory outside `Components/ Previews/`; and on any Presentation module's directory with no Swift file under it.
- `viewModelsImportNoUIFramework` fails on a file in a Presentation module's `ViewModels/` or `Models/` that imports SwiftUI, AppKit, UIKit or Cocoa.
- `stylesDependsOnNoSibling` fails on a Presentation module in `styles`' `uses:`; since `importsAreDeclared` fails on any import a module's row doesn't declare, `styles` can import no sibling either.
- `viewsDoNotReachBusiness` fails on a file under `Views/` or `Components/` that imports a Business module.
- `tokensComeFromStyles` fails on a line, in a file under `Views/` or `Components/` of a module other than `styles`, that writes a color (`Color(red:`, `Color(white:`, `Color(hue:`, `Color(#…`), a font size (`.system(size:`), a number straight after `.padding(`, `spacing:`, `cornerRadius:`, `lineWidth:` or a width or height label (`width:`, `minHeight:`, …), or a fractional opacity (`.opacity(0.5)`).
- `theModuleGraphHasNoCycles` refuses a cycle between features, as anywhere in the map.

Each was seen to fail on a planted violation on 2026-10-31 ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)), over the retired modules. Their code is unchanged since, except that on 2026-11-07 ([Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)) `presentationModulesHaveTheMVVMShape` admitted `Debug/` and `importsAreDeclared` lost its entry-point rule. `Debug/`'s own guard is `ProjectRulesTests`' `toolsArePersonalOnly` ([ADR 0016](two-build-routines-and-a-fresh-start.md)): it fails on a file under `Debug/`, in the package or the apps, that doesn't open with `#if PERSONAL_BUILD`, and was seen to fail on an unguarded `Debug/` view on 2026-11-07.

Review holds the rest, which no check reads: that view-models are `@MainActor @Observable` and import nothing but Foundation, Observation and the lower layers (the check refuses only the four UI frameworks); that a view-model never references a view; that features don't depend on each other at all (only a cycle fails); that a component is promoted, not copied; that a feature view takes even a named color or font, and every size, from `styles` (`Color.black`, `.font(.title)` and `.padding(.horizontal, 12)` pass the token check, which catches only the literals listed above); that a `Debug/` view keeps the Business and token rules, since both checks read only `Views/` and `Components/`; that nothing but the apps, tests and previews constructs the console or a view-model; and that each app's entry point holds no logic and draws with `styles`, since `LayeringTests` reads only the module map's source directories, never `lib/src/darwin/apps/`.
