# Settings, Acknowledgements, About, the menus and every shortcut

**What / why.** The design's other windows and its keyboard:
- **Settings** (⌘,): a window of tabs. v0.1.0 has Appearance (theme and text size) and, in personal builds, Personal. Later items add Controllers (5j), Video (5g), Audio (5m) and Memory Cards (5k).
- **Acknowledgements** (⌥⌘A), restyled: each notice the app carries, its licence, and a link that says it opens the browser.
- **About:** the version, 0.1.0 (2), and which build routine made the app.
- **Keyboard Shortcuts** (⌘/): a sheet listing every key.
- **Menus:** the menu bar carries every shortcut: iStation, File, View, Game, Console, Tools (personal) and Help.

Today the app has an "Acknowledgements…" item after About (`apps/macos/Sources/iStationApp.swift:46`) opening a plain list window (`:24`), and no Settings. Measured, not guessed, 2026-11-21 (probe): `Acknowledgement.list(from:for:)` gives the macOS app six entries (iStation, ProjectPSX, Play!, Play! Framework, Play! CodeGen, Nuanceur) and the iOS app two. `MARKETING_VERSION` is 0.1.0 and `CURRENT_PROJECT_VERSION` 2 (`apps/Config/Version.xcconfig`).

**Core constraint(s).**
- The acknowledgements come only from `apps/Acknowledgements.json` through `Acknowledgement.bundled(for:)`; nothing is typed in by hand ([ADR 0014](../../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)).
- The Personal tab exists only under `#if PERSONAL_BUILD` ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).
- View-models import no UI toolkit; settings persist with defaults, so an older install keeps loading.
- Keys never collide: ⌘ shortcuts go to the app, plain keys to the game (once 6e exists).

**Seam + files.**
- Presentation, new place `settings`: `SettingsViewModel` (theme, text size, personal options) over `UserDefaults` through a small injected store; one view per tab; previews per tab.
- Presentation `acknowledgements`: the listed state restyled to the design (name, licence chip, copyright line, source link), its previews kept.
- Presentation `styles`: the Keyboard Shortcuts list as data shared by the sheet and the menus.
- The macOS app target: a `Settings` scene; `CommandMenu`s for Game, Console and Tools; `CommandGroup`s for File, View and Help; About through the standard panel with the version and routine.
- Tests: `tests/presentation/settings/` (defaults, persistence), and a test that every listed shortcut has a menu item and no two items share a key.

**Reference.** The design: boards `Mac-SettingsAppearance`, `Mac-SettingsPersonal`, `Mac-Acknowledgements`, `Mac-About` and `Mac-Shortcuts`; the `Layout` board's shortcuts and menus; contract rows C37–C39; `tools/check.mjs`' check that each of the 29 shortcuts acts where it applies. In-house: `AcknowledgementsCommand` and `AcknowledgementsViewModel` today.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, Settings and Acknowledgements among them (the user's call).

**Open calls:**
- (consumed decision) The theme setting's default and its high-contrast behaviour are 5a's.
- [default: About uses the standard About panel, with the build routine in its credits] Not a custom window; the design's About board is the panel's content.
- [default: the acknowledgements stay as the list gives them, Play!'s notices included before PS2 code ships] The design shows what the backend says.
- [default: Settings remembers the last tab]

**Guardrail(s).** View-model tests for every setting's default and persistence; the shortcut test above; a preview per tab and per acknowledgements state matching its board; `ArchitectureTests` keep the Personal tab out of App Store builds.

**Acceptance criteria:**
- [ ] ⌘, opens Settings with Appearance (and Personal in personal builds); changing the theme or text size restyles the app at once.
- [ ] Acknowledgements, About and Keyboard Shortcuts match their boards; ⌥⌘A and ⌘/ open them.
- [ ] Every shortcut on the `Layout` board is a menu item with its key, and the test above passes.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5a. v1.0.0's acknowledgements line stays: it is the final check of both apps' notices before submission.
