# The design's tokens in the styles module

**What / why.** The app design draws every color, font, size, space, radius and duration from one file, `json/tokens.json` in [the design](../../../design/darwin/README.md): 42 color roles in three themes (dark, light, high contrast), the macOS and iOS text styles with four text-size multipliers, spacing, radii, motion and layout sizes. The `styles` module today has three colors (`Palette.screen`, `onScreen`, `secondaryText`), two symbols, five metrics and three fonts (`source/presentation/styles/*.swift`), so no screen in track 5 can be built to the design until `styles` carries the tokens. This item brings `styles` up to `tokens.json`, and adds the shared components the design draws in two or more places: the job sheet (BIOS check, adding a folder, opening a game, recording a trace), the alert with a Details disclosure showing the exact call, chips, banners and keycaps. Measured, not guessed: on 2026-11-21 `tools/check.mjs` computed all 138 text and edge pairs across the three themes at or above their minimum (4.5:1 for text, 3:1 for focus rings and control edges).

**Core constraint(s).**
- Presentation only, and `styles` stays the one source of colors, symbols, sizes and fonts ([ADR 0020](../../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)); no feature view gains a literal.
- `styles` leans on no sibling module; SwiftUI, AppKit and UIKit are allowed here (views and shared components), never in a `ViewModels/` or `Models/` folder.
- Existing names keep working: `Palette.screen`, `Palette.onScreen`, `Palette.secondaryText`, `Metrics.screenAspectRatio`, `Metrics.playerMinWidth/Height` (the player and acknowledgements views use them today).
- Every shared component has a named `#Preview` per visible state, inside `#if DEBUG` ([ADR 0021](../../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)).

**Seam + files.** Presentation, `styles` (`PresentationStyles`):
- `Palette.swift`: one static member per color role in `tokens.json`, each resolving its dark, light and high-contrast value at draw time; the `swiftui` map in `tokens.json` names each role's member.
- `Typography.swift`: the text styles (`largeTitle` … `caption`), monospaced, scaled by the text-size setting and Dynamic Type.
- `Metrics.swift`: `space1` to `space10`, the radii, and the layout sizes (`size.mac`, `size.ios`: sidebar 220, inspector 300, toolbar 52, row 30, tile 168, window minimum 800 × 560).
- `Motion.swift` (new): fast 120 ms, base 200 ms, slow 320 ms, none under Reduce Motion.
- `Symbols.swift`: an SF Symbol per icon the design draws (its `ICON` set in `html/main.html`).
- `Components/` (new): `JobSheet` over a `JobPresentation` value (steps, progress, summary, buttons), `DetailsAlert`, `Chip`, `Banner`, `Keycap`.
- Tests in `tests/presentation/styles/`: the tokens test below.

**Reference.** The design's Foundations page: boards `Foundations-Color`, `Foundations-Type` and `Foundations-Components`, which draw these tokens and every component in every state; `json/tokens.json` is the source, embedded verbatim in the prototype. In-house precedent: the three tokens `styles` has today and `AcknowledgementsView`'s mapping of a view-model `State` to tokens.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, moving BIOS and file import from v0.2.0 into v0.1.0 (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [user] The look: the "graphite and amber" palette and its amber accent are the design's proposal. Keep it, or name another accent before the tokens become code?
- [default: colors resolve in code through dynamic `NSColor`/`UIColor` providers, not an asset catalog, so each role maps one to one to `tokens.json` and the test can compare them] An asset catalog would need a generator to stay in step.
- [default: the theme setting's default is "Match the system", resolving to dark or light; "High contrast" is also chosen when macOS's or iOS's Increase Contrast is on] The design's Settings board shows the three explicit themes.
- [default: the shared components live in `styles` from the start] The design shows each in at least two modules, which is ADR 0020's bar for promotion.

**Guardrail(s).** A test reads `lib/documentation/design/darwin/json/tokens.json` by its repository path and fails when a color role, text style, space, radius or duration has no `styles` member or a different value; it also recomputes every `contrastPairs` entry from the Swift values. `ArchitectureTests` keep `styles` free of sibling imports.

**Acceptance criteria:**
- [ ] Every color role in `tokens.json` has a `Palette` member giving its dark, light and high-contrast values, and the test above passes.
- [ ] `Typography`, `Metrics` and `Motion` carry the type ramps, text-size multipliers, spacing, radii, layout sizes and durations.
- [ ] `JobSheet`, `DetailsAlert`, `Chip`, `Banner` and `Keycap` exist with a preview per state that matches `Foundations-Components` (running, stopped, done and failed steps; Details open and closed; each chip and banner kind).
- [ ] The player and acknowledgements views build unchanged; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, first: every other track 5 item draws from it. No screen changes here.
