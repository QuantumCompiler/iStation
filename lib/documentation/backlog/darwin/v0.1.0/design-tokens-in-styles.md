# The design's tokens in the styles module

**What / why.** The app design draws every color, font, size, space, radius and duration from one file, `json/tokens.json` in [the design](../../../design/darwin/README.md): 42 color roles in three themes (dark, light, high contrast), the macOS and iOS text styles with four text-size multipliers, spacing, radii, motion and layout sizes. The `styles` module today has three colors (`Palette.screen`, `onScreen`, `secondaryText`), two symbols, five metrics and three fonts (`source/presentation/styles/*.swift`), so no screen in track 5 can be built to the design until `styles` carries the tokens. This item brings `styles` up to `tokens.json`, and adds the shared components the design draws in two or more places: the job sheet (BIOS check, adding a folder, opening a game, recording a trace), the alert with a Details disclosure showing the exact call, chips, banners and keycaps. Measured, not guessed: on 2026-11-21 `tools/check.mjs` computed all 138 text and edge pairs across the three themes at or above their minimum (4.5:1 for text, 3:1 for focus rings and control edges).

**Core constraint(s).**
- Presentation only, and `styles` stays the one source of colors, symbols, sizes and fonts ([ADR 0020](../../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)); no feature view gains a literal.
- `styles` leans on no sibling module; SwiftUI, AppKit and UIKit are allowed here (views and shared components), never in a `ViewModels/` or `Models/` folder.
- Existing names keep working: `Palette.screen`, `Palette.onScreen`, `Palette.secondaryText`, `Metrics.screenAspectRatio`, `Metrics.playerMinWidth/Height` (the player and acknowledgements views use them today).
- Every shared component has a named `#Preview` per visible state, inside `#if DEBUG` ([ADR 0021](../../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)).

**Seam + files.** Presentation, `styles` (`PresentationStyles`):
- `Palette.swift`: one static member per color role in `tokens.json`, each a dynamic `NSColor`/`UIColor` provider that resolves at draw time to its dark, light or high-contrast value, written in Swift as `tokens.json` gives it — no asset catalog, and no system color or material in the place of a role the app draws; the `swiftui` map in `tokens.json` names each role's member. Its notes that point at the AccentColor asset or at system colors and materials (`accent`, `bg-window`, `bg-sidebar`, `bg-content`, `bg-toolbar`, `bg-control`, `bg-selected`, `line`, `fg`, `fg-muted`, `fg-faint`, `fg-on-screen`) are brought in line, `focus` (the system's focus ring) and `bg-overlay` (the system's sheet and alert dimming) say they stay system-drawn and why, and the roles it lacks gain entries, in the same change (`json/tokens.json`, then `node tools/sync.mjs`, published to the canvas by the design's sync rule).
- `Theme.swift` (new): the theme setting's values — Match the system (the default: dark or light as the system is, and High contrast while Increase Contrast is on), Dark, Light, High contrast — and the resolution the providers read; 5e's Settings sets it.
- `Typography.swift`: the text styles (`largeTitle` … `caption`), monospaced, scaled by the text-size setting and Dynamic Type.
- `Metrics.swift`: `space1` to `space10`, the radii, and the layout sizes (`size.mac`, `size.ios`: sidebar 220, inspector 300, toolbar 52, row 30, tile 168, window minimum 800 × 560).
- `Motion.swift` (new): fast 120 ms, base 200 ms, slow 320 ms, none under Reduce Motion.
- `Symbols.swift`: an SF Symbol per icon the design draws (its `ICON` set in `html/main.html`).
- `Components/` (new): `JobSheet` over a `JobPresentation` value (steps, progress, summary, buttons), `DetailsAlert`, `Chip`, `Banner`, `Keycap`.
- Tests in `tests/presentation/styles/`: the tokens test below.
- A new ADR superseding [ADR 0020](../../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md): its rule restated with `Palette` carrying the design's own colors from `tokens.json` as dynamic providers and `Theme` holding the theme setting, in place of its "There is no custom theme: `Palette` names SwiftUI's own colors"; ADR 0020's Status line and the ADR index say so.
- [DEVELOPER.md](../../../assistant/darwin/DEVELOPER.md)'s "Adding a token" recipe: a color or size goes into the design's `json/tokens.json` first (with a `contrastPairs` entry for a new text pair), then `node tools/sync.mjs` and the design's checks, then its `styles` member; the tokens test fails while the two differ.
- The design, in the same change: `Layout.dc.html` (its module list, and its Jobs row's `.sheet { JobView }`) and `Processes.dc.html` (its main-actor row) list a "Jobs" Presentation module; they name the job sheet, Details alert, chips, banners and keycaps as `styles`' shared components instead. The `Contract` board's Branding call drops the accent and the look (answered 2026-11-22), keeping the on-screen pad's outline shapes, 5o's open call.

**Reference.** The design's Foundations page: boards `Foundations-Color`, `Foundations-Type` and `Foundations-Components`, which draw these tokens and every component in every state; `json/tokens.json` is the source, embedded verbatim in the prototype. In-house precedent: the three tokens `styles` has today and `AcknowledgementsView`'s mapping of a view-model `State` to tokens.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, moving BIOS and file import from v0.2.0 into v0.1.0 (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: the look is the design's "graphite and amber" palette, amber its accent, as `tokens.json` gives it (the user's call).
- 2026-11-22: colors resolve in code through dynamic `NSColor`/`UIColor` providers, not an asset catalog, so each role maps one to one to `tokens.json` and the test can compare them (the default, confirmed by the user).
- 2026-11-22: the theme setting's default is "Match the system", resolving to dark or light; "High contrast" is also chosen when macOS's or iOS's Increase Contrast is on (the default, confirmed by the user).
- 2026-11-22: the shared components live in `styles` from the start: the design shows each in at least two modules, ADR 0020's bar for promotion (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** A test reads `lib/documentation/design/darwin/json/tokens.json` by its repository path and fails when a color role, text style, space, radius or duration has no `styles` member or a different value; it also recomputes every `contrastPairs` entry from the Swift values. `ArchitectureTests` keep `styles` free of sibling imports.

**Acceptance criteria:**
- [ ] Every color role in `tokens.json` has a `Palette` member giving its dark, light and high-contrast values, and the test above passes.
- [ ] With the theme on Match the system, the app follows the system's appearance and turns high contrast with Increase Contrast; a test covers each resolution.
- [ ] `Typography`, `Metrics` and `Motion` carry the type ramps, text-size multipliers, spacing, radii, layout sizes and durations.
- [ ] `JobSheet`, `DetailsAlert`, `Chip`, `Banner` and `Keycap` exist with a preview per state that matches `Foundations-Components` (running, stopped, done and failed steps; Details open and closed; each chip and banner kind).
- [ ] The new ADR supersedes ADR 0020 with the design's palette and the theme setting; ADR 0020's Status and the index say so.
- [ ] The player and acknowledgements views build unchanged; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, first: every other track 5 item draws from it. No screen changes here.
