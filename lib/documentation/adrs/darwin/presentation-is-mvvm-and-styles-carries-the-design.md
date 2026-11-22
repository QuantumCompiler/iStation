# ADR 0023 — Presentation modules are MVVM and share one styles module, which carries the design's tokens; the apps are the composition roots

**Status:** Accepted · **Date:** 2026-11-22 · Supersedes [ADR 0020](presentation-is-mvvm-with-one-styles-module.md)

## Context

[ADR 0020](presentation-is-mvvm-with-one-styles-module.md) (2026-11-14) restated [ADR 0005](presentation-mvvm.md)'s MVVM rule for today's modules, and gave `styles` the tokens the player and the acknowledgements screen needed then: three colors, two symbols, five metrics and three fonts. It said "There is no custom theme: `Palette` names SwiftUI's own colors" — `Palette.screen` was `Color.black`, `onScreen` `Color.white` and `secondaryText` `.secondary` — and no component was shared yet.

On 2026-11-21 the app's design came into the repository: [`lib/documentation/design/darwin/`](../../design/darwin/README.md), mirrored from its Claude Design canvas, a prototype of both apps with a board per screen and state, its contract with the code, and `json/tokens.json`, every color, font, size, space, radius and duration the apps draw with, named for its role. Its 42 color roles come in three themes (dark, light and high contrast); its macOS and iOS text styles come with four text-size multipliers; and spacing, radii, motion and the layout sizes follow. Its `tools/check.mjs` computed all 138 text and edge pairs across the three themes at or above their minimum that day (4.5:1 for text, 3:1 for focus rings and control edges). Its `swiftui` map, written before anything was built, still pointed the window, sidebar, content, toolbar, control and selection backgrounds, the lines, the text and the accent at system colors and materials and at an `AccentColor` asset: built that way the app would draw the system's look, not the design's, and the contrast the design measured would not be the contrast of what the app draws. The design also draws the job sheet (the BIOS check, adding a folder, opening a game, recording a trace), the alert with a Details disclosure showing the exact call, chips, banners and keycaps, each in two or more of its places, so ADR 0020's bar for promoting a component to `styles` is met before the first is written.

v0.1.0's item 5a, which brings `styles` up to `tokens.json` ([MILESTONES](../../assistant/darwin/MILESTONES.md)), had its calls answered on 2026-11-22:

- The look is the design's "graphite and amber" palette, amber its accent, as `tokens.json` gives it (the user's call).
- Colors resolve in code through dynamic `NSColor`/`UIColor` providers, not an asset catalog, so each role maps one to one to `tokens.json` and a test can compare the two (the default, confirmed by the user).
- The theme setting's default is Match the system, resolving to dark or light as the system is; High contrast is also chosen while macOS's or iOS's Increase Contrast is on (the default, confirmed by the user). Settings, v0.1.0's item 5e, sets it, with the text size beside it.
- The shared components live in `styles` from the start, since the design shows each in at least two modules (the default, confirmed by the user).

ADR 0020's "no custom theme" no longer holds, and ADRs are append-only, so this record restates its whole rule for today, changed only where those calls change it.

## Decision

**iStation's Presentation layer is organized by MVVM**, in SwiftUI's idiom: views are `View` structs; view-models are `@MainActor @Observable` classes importing Foundation, Observation, the lower layers and `styles` (for its UI-free `Models/` values: `JobPresentation`, `Tone`) only.

### The modules

The Presentation modules are the `EmuKit` product's three, in `lib/src/darwin/source/presentation/`:

- **One feature module per user-facing place**: `player` (the player's screen: `PlayerView` over `PlayerViewModel`) and `acknowledgements` (every notice the app carries: `AcknowledgementsView` over `AcknowledgementsViewModel` and its `Acknowledgement` entries) today.
- **`styles`** — the shared visual vocabulary, which carries the design: every token in the design's `json/tokens.json`, and the components more than one module uses. It depends on no sibling Presentation module; every other module may use it.
- **The apps are the composition roots**, not modules. Each entry point — `lib/src/darwin/apps/macos/Sources/iStationApp.swift`, `lib/src/darwin/apps/ios/Sources/iStationApp.swift` — builds the `PS1Console` and every place's view-model, lays out the scenes and their chrome (on macOS the player's window and an Acknowledgements window opened from the app menu by `AcknowledgementsCommand`; on iOS `RootView`, the player in a navigation stack with a toolbar button for the acknowledgements sheet), and holds no logic. Outside tests and previews, nothing else constructs the console or a view-model.

### What `styles` carries

`json/tokens.json` in [the design](../../design/darwin/README.md) is the source of every token; its `swiftui` map names each role's `styles` member, and each member is named for its role.

- **`Palette`** — one static member per color role, each a dynamic `NSColor` (macOS) or `UIColor` (iOS) provider that resolves at draw time, from the appearance it is drawn in, to the role's dark, light or high-contrast value, written in Swift as `tokens.json` gives it. There is no asset catalog, and no system color or material stands in the place of a role the app draws: the window, sidebar, toolbar, control and selection backgrounds, the lines, the text and the accent are the design's own. Two roles stay the system's, because macOS and iOS draw them and the app does not: `focus`, the focus ring around the focused control, and `bg-overlay`'s dimming behind a sheet or an alert (its other use, the scrim over a paused picture and behind the iPhone's on-screen buttons, is the app's).
- **`Theme`** — the theme setting's values and the resolution the providers read: **Match the system**, the default — dark or light as the system's appearance is, and High contrast while Increase Contrast is on — then **Dark**, **Light** and **High contrast**, each fixed whatever the system does. Every provider resolves through `Theme.applied`, the choice Settings (item 5e) sets: the one process-wide value in `styles`, as `NSApplication.appearance` is, since AppKit and UIKit hand a dynamic color only the appearance or traits it is drawn in, so the choice can reach it no other way. Beside it Settings asks the system for the choice's scheme — dark whenever it resolves to the dark-based high-contrast theme, Match the system under Increase Contrast included — so the system's own controls draw for the surfaces the palette gives them; macOS can't be put into high contrast by an app, so there they draw it only while Increase Contrast is on.
- **`Typography`** — the text styles (`largeTitle` to `caption`) in the macOS and iOS ramps, their weights and the monospaced face, scaled on macOS by the text-size setting's multiplier and on iOS by Dynamic Type.
- **`Metrics`** — the spaces (`space1` to `space10`), the radii, the macOS and iOS layout sizes (sidebar, inspector, toolbar, row, tile, the window's minimum), and the player's own: the 4:3 screen and the player's minimum size.
- **`Motion`** — the durations (fast, base, slow) and the design's curve, and no motion while Reduce Motion is on.
- **`Symbols`** — an SF Symbol name for each icon the design draws.
- **The shared components** — the job sheet (`JobSheet`, over a `JobPresentation` value of steps, progress, summary and buttons), the alert with a Details disclosure (`DetailsAlert`), `Chip`, `Banner` and `Keycap`: presentational, as below, and drawn with `styles`' own tokens in every state the design's `Foundations-Components` board shows.

**A token changes in `tokens.json` first.** A new or changed color, size, font, space, radius or duration goes into `json/tokens.json` — a new text pair with its `contrastPairs` entry — then through the design's `node tools/sync.mjs` and its checks, out to the canvas by [the design's sync rule](../../design/darwin/CLAUDE.md#the-sync-rule), and into its `styles` member in the same change; the tokens test fails while the two differ.

### Inside a feature module

- **`Views/`** — views: layout, binding and purely visual concerns, toolkit calls that are purely visual included. No business logic, no service calls, no Business imports; every color, font and size from `styles`.
- **`ViewModels/`** — the module's state and intents. **No file here imports SwiftUI, AppKit, UIKit or Cocoa.** Intents are methods named for what the person does; a chooser's visibility is a plain `Bool` the view binds `.fileImporter` to. A view-model is given what it reads through its initializer (`PlayerViewModel(console:)` takes the console the app built), consumes Business through it, and never mirrors state Business owns.
- **Further directories only when real files need them**: `Components/` (presentational pieces a single module uses, below; none yet), `Models/` (plain values the views show, UI-free like a view-model: `acknowledgements/Models/Acknowledgement`), `Previews/` (preview support, [ADR 0021](presentation-modules-stand-alone-and-preview-sample-data.md): `player/Previews/PreviewPlayer`, the player's view-model over a powered-off console), `Debug/` (debug views, each opening with `#if PERSONAL_BUILD` ([ADR 0016](two-build-routines-and-a-fresh-start.md)) and held to the rules of `Views/`; none yet). No file sits at the module's root.

### Inside `styles`

`styles` draws no place of its own, so it has no `Views/` or `ViewModels/`: its tokens sit at its root (`Palette.swift`, `Theme.swift`, `Typography.swift`, `Metrics.swift`, `Motion.swift`, `Symbols.swift`), and the only directories it may have are `Components/` (the shared components), `Models/` (the plain values they show, UI-free like a view-model: `JobPresentation`, `Tone`) and `Previews/`. A feature's view-model may build those values, the one thing of `styles` it imports. A debug view lives in a feature module, never in `styles`.

### The edges

- A view binds to its view-model; the view-model consumes Business; a view never reaches Business, and a view-model never references a view.
- Every module may use `styles`; `styles` uses no sibling. The apps compose every module; nothing in the package can import an app, since the apps are targets of `lib/src/darwin/iStation.xcodeproj`, not of the package.
- Features do not depend on each other: `player` and `acknowledgements` each use `styles` alone among their siblings, and only the apps put them together. A place that needs another's state or action gets it through a closure an app wires, never an import.

### Components

A component is presentational — plain values in, events out; it never takes a feature's view-model. A component born in one module is **promoted to `styles/Components/` the moment a second module wants it** — moved, never copied. A component the design already draws in two or more places starts in `styles`, as the job sheet, the Details alert, chips, banners and keycaps do.

## Consequences

- A new place starts as a module with `Views/` and `ViewModels/`, its own shared scheme ([ADR 0017](every-presentation-module-has-its-scheme.md)), and its view-model built by each app that shows it. Its behaviour lives in its view-model and in Business, so its tests are scripted-input tests over its view-models (`PlayerViewModelTests`, `AcknowledgementsViewModelTests`), not UI automation.
- Shared visual changes land once, in `styles`, and before that in the design; a duplicated component, a literal color in a feature view or a token changed in `styles` and not in `tokens.json` is rejected by citing this record.
- The names ADR 0020's `styles` had keep working, now with the design's values: `Palette.screen` is `bg-screen`, `Palette.onScreen` `fg-on-screen` and `Palette.secondaryText` `fg-muted`, and `Metrics`' screen ratio and player minimum stay.
- Every text and edge pair's contrast is computed twice: by the design's `tools/check.mjs` over `tokens.json`, and by the tokens test over the Swift values the app draws.
- A view-model that shows a color or a symbol still says it as a case of its `State`, which the view maps to `Palette` and `Symbols`; the theme reaches no view-model.
- Composition is per app: the two entry points build the same view-models and lay out their own chrome — two windows and a menu command on macOS, a navigation stack and a sheet on iOS.
- Chosen trade-offs: more files and modules than a view-does-everything layout, accepted because the seam is what makes every screen testable headlessly and every visual decision single-sourced. The design's colors are written out in Swift beside `tokens.json`, not generated or kept in an asset catalog, accepted because the test compares the two and a reader sees each role's three values in one place. The app gives up the system's materials and the person's own accent color for the design's surfaces and amber, accepted because the design's look and its measured contrast are what the user chose; the focus ring and the sheet dimming stay the system's.

## Enforcement

`ArchitectureTests/LayeringTests.swift`, carried from ADR 0020:

- `presentationModulesHaveTheMVVMShape` fails on a Presentation module other than `styles` with a directory outside `Views/ ViewModels/ Components/ Models/ Previews/ Debug/`, without `Views/` or `ViewModels/`, or with a Swift file at its root; on `styles` with a directory outside `Components/ Models/ Previews/`; and on any Presentation module's directory with no Swift file under it.
- `viewModelsImportNoUIFramework` fails on a file in a Presentation module's `ViewModels/` or `Models/` that imports SwiftUI, AppKit, UIKit or Cocoa — `styles/Models/` included.
- `stylesDependsOnNoSibling` fails on a Presentation module in `styles`' `uses:`; since `importsAreDeclared` fails on any import a module's row doesn't declare, `styles` can import no sibling either.
- `viewsDoNotReachBusiness` fails on a file under `Views/` or `Components/` that imports a Business module.
- `tokensComeFromStyles` fails on a line, in a file under `Views/` or `Components/` of a module other than `styles`, that writes a color (`Color(red:`, `Color(white:`, `Color(hue:`, `Color(#…`), a font size (`.system(size:`), a number straight after `.padding(`, `spacing:`, `cornerRadius:`, `lineWidth:` or a width or height label (`width:`, `minHeight:`, …), or a fractional opacity (`.opacity(0.5)`).
- `theModuleGraphHasNoCycles` refuses a cycle between features, as anywhere in the map.

Each was seen to fail on a planted violation on 2026-10-31 ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)), over the retired modules. Their code is unchanged since, except that on 2026-11-07 ([Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)) `presentationModulesHaveTheMVVMShape` admitted `Debug/` and `importsAreDeclared` lost its entry-point rule, and on 2026-11-22 it admitted `Models/` in `styles`. `Debug/`'s own guard is `ProjectRulesTests`' `toolsArePersonalOnly` ([ADR 0016](two-build-routines-and-a-fresh-start.md)): it fails on a file under `Debug/`, in the package or the apps, that doesn't open with `#if PERSONAL_BUILD`, and was seen to fail on an unguarded `Debug/` view on 2026-11-07.

`PresentationStylesTests` (`lib/src/darwin/tests/presentation/styles/`), new with this record:

- `TokensTests` reads `lib/documentation/design/darwin/json/tokens.json` by its repository path: `everyColorRoleHasItsPaletteRow`, `everyTextStyleHasItsSizes`, `everyTextSizeHasItsMultiplier`, `everyWeightHasItsValue`, `everySpaceHasItsMember`, `everyRadiusHasItsMember`, `everyLayoutSizeHasItsMember` and `everyDurationHasItsMember` fail when a role, style, space, radius, duration or size has no `styles` member or a different value; `theSwiftUIMapNamesEachRolesMember` when the file's `swiftui` map names no member for a role, or another one; and `everyContrastPairMeetsItsMinimum` recomputes every `contrastPairs` entry from the Swift values, failing on a pair below its minimum. `PaletteProviderTests`' `everyMemberResolvesToItsRow` resolves each member in each theme and compares the color it gets, so a system color in a role's place fails it too; `ToneTests`' `eachToneIsAContrastPair` holds each status tone to one of the file's pairs.
- The theme tests resolve the setting and the providers under each choice and under the system's light, dark and high-contrast appearances: `ThemeTests`' `matchTheSystemFollowsTheSystem`, `anExplicitChoiceWins`, `highContrastAsksForDark` and `matchTheSystemOverridesNothing`, and `PaletteProviderTests`' `anExplicitChoiceIsWhatIsDrawn`, `explicitChoicesApplyThroughTheAppearance` and `matchTheSystemDrawsHighContrastUnderIncreaseContrast` fail when Match the system or an explicit choice draws otherwise than above, or when a choice that resolves to high contrast doesn't ask the system for dark. `highContrastCannotBeNamed` pins what AppKit does today with the high-contrast appearance names, so a change in it is seen.

Both were seen to fail on planted violations on 2026-11-22: `fg-muted`'s dark value darkened in `Palette` failed `everyColorRoleHasItsPaletteRow`, `everyContrastPairMeetsItsMinimum` and `eachToneIsAContrastPair`, and Light resolved to the dark theme failed `anExplicitChoiceWins`, `anExplicitChoiceIsWhatIsDrawn` and `explicitChoicesApplyThroughTheAppearance` ([Milestone S](../../assistant/darwin/MILESTONES.md#milestone-s--the-designs-tokens-in-styles)).

Review holds the rest, which no check reads: that view-models are `@MainActor @Observable` and import nothing but Foundation, Observation, the lower layers and `styles`' `Models/` values (the check refuses only the four UI frameworks); that a view-model never references a view; that features don't depend on each other at all (only a cycle fails); that a component is promoted, not copied, and that one the design draws in two places starts in `styles`; that a feature view takes even a named color or font, and every size, from `styles` (`Color.black`, `.font(.title)` and `.padding(.horizontal, 12)` pass the token check, which catches only the literals listed above); that `styles`' own components draw with its tokens, since the token check skips `styles`; that a token changed in `styles` was changed in `tokens.json` and published to the canvas first, which the tokens test sees only as the two differing; that a `Debug/` view keeps the Business and token rules, since both checks read only `Views/` and `Components/`; that nothing but the apps, tests and previews constructs the console or a view-model; and that each app's entry point holds no logic and draws with `styles`, since `LayeringTests` reads only the module map's source directories, never `lib/src/darwin/apps/`.
