# The iPhone app: first run, library and settings

**What / why.** ROADMAP v0.4.0 is the iOS app playing PS1. The design recomposes the Mac app's places for an iPhone held in portrait:
- **Welcome:** Choose BIOS File through the Files picker.
- **Library:** a large-title list with search. Each row has the game's initials, name, console, serial and size; a moved file shows as "Can't find the file", and PS2 discs as "plays in a later version".
- **Toolbar:** Add (+) and Settings (the gear).
- **Opening a game:** a bottom sheet with the job's steps.
- **Settings:** a grouped list (BIOS, controllers, memory cards, display, appearance, version, Acknowledgements).

Today the iOS app is one screen: the player with an Acknowledgements button (`apps/ios/Sources/iStationApp.swift`). The view-models are the Mac app's (5c, 5d, 5h, 5e); this item is the iPhone's views and composition. Measured, not guessed, 2026-11-21 (probe): the iOS app carries two acknowledgements, iStation and ProjectPSX.

**Core constraint(s).**
- View-models are shared and import no UI toolkit; only views differ by platform ([ADR 0020](../../../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)).
- The iOS App Store app generates no code at run time: interpreter only (SPEC, Apple constraints).
- Touch targets at least 44 points; text follows Dynamic Type (the iOS type ramp in `tokens.json`).
- Files chosen through the Files picker are read only, through security-scoped bookmarks.

**Seam + files.**
- Presentation `bios`, `library` and `settings`: iPhone views (`#if os(iOS)`) over the same view-models, with previews per state.
- The iOS app target: `NavigationStack` with the library as its root, `.fileImporter`, `.sheet` for Settings, Acknowledgements and the opening job.
- Tests: the view-models' tests already cover behavior; the iPhone adds previews per state and an iOS build in CI's pipeline.

**Reference.** The design: boards `iOS-Welcome`, `iOS-Library`, `iOS-Opening` and `iOS-Settings`; contract rows C01, C11, C13, C14 and C37–C39; the iOS type ramp and sizes in `tokens.json`. In-house: today's `RootView` in the iOS app.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the iPhone library plays a game on a tap, and Game info is a swipe action's sheet] The design shows tap to play.
- [default: on the iPhone a memory card's delete says it can't be undone, since there is no Trash]
- [default: contract row C11's bookmark probe is repeated on iOS under its App Store routine]

**Guardrail(s).** A preview per board's state; the shared view-models' tests; the iOS App Store archive still builds clean.

**Acceptance criteria:**
- [ ] Welcome, the BIOS check, the library, the opening sheet and Settings match their iPhone boards in the iOS Simulator.
- [ ] A BIOS and games chosen through Files stay readable after a relaunch.
- [ ] `swift test`, the strict build and both iOS routines' builds pass.

**Scope note.** v0.4.0, track 5, iOS only, gated on 5c, 5e and 5h. The player is 5o's.
