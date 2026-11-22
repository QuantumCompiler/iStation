# The iPhone player

**What / why.** The design's iPhone player turns the phone to landscape and fills the screen:
- **The picture:** fitted to the height, 520 × 390 on a 844 × 390 screen.
- **The on-screen pad:** the direction pad on the left; four face buttons drawn as plain outlines in one color, each named in words for VoiceOver; L1, L2, R1 and R2 in the corners; Select and Start below.
- **Pause:** a button at the top centre that opens a bottom sheet with Resume, Save State, Load State, Reset… and Quit Game….
- **Save and Load State:** the same eight slots as the Mac, in a bottom sheet.

The on-screen pad feeds the same input the controllers do (6e); a connected controller hides it.

**A controller on the iPhone** (the controller spike, 2026-11-22, wall W10, from the iOS 27.2 SDK's headers; nothing was run on a device). On iOS a controller's presses can also reach the app's views and gesture recognizers unless a view claims them with `GCEventInteraction` (iOS 18 and later; its `receivesEventsInView`, iOS 26 and later, keeps both): without it, Cross could also press a focused SwiftUI control under the player. The app's target is iOS 17, so the interaction is added behind `#available`. 6e claims the PS button during play (the user's call, 2026-11-22); on the iPhone, where there is no keyboard, its press opening the pause sheet is the most useful thing it could do, if the press reaches the app (6e's open call).

**Core constraint(s).**
- No Sony marks: no logo and no colored shapes; the face buttons are outlines, named in words.
- View-models are shared with the Mac (5b, 5l); only views differ.
- Interpreter only on iOS; nothing generates code at run time.
- Touch targets at least 44 points.

**Seam + files.**
- Presentation `player`: an iPhone `PlayerView` (`#if os(iOS)`): `FrameView` (6b) in a `UIViewRepresentable`, with a `GCEventInteraction` (`handledEventTypes = .gamepad`) on it behind `#available(iOS 18, *)`; the on-screen pad as SwiftUI buttons feeding the input service; the pause sheet with `.presentationDetents`.
- Presentation `savestates` (5l): the bottom-sheet presentation.
- The iOS app target: `.fullScreenCover` for the player, landscape only.
- Tests: the shared view-models' tests; previews per state; a test that the on-screen pad produces the same `PS1PadButtons` as the mapped controller.

**Reference.** The design: boards `iOS-Player`, `iOS-Pause` and `iOS-States`; contract rows C21, C28 and C31; the iOS sizes in `tokens.json`. Apple's SDK: `GCEventInteraction.h` (iOS 27.2).

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: iStation claims the PS button while a game runs (the user's call; 6e builds it).

**Open calls:**
- [user] The on-screen face buttons: plain outline shapes (designed), or words only, until the trademark check before v1.0.0?
- [default: SwiftUI buttons for the pad rather than GameController's virtual controller] The virtual controller labels its buttons A, B, X and Y, which don't match the PS1's.
- [default: the pad's opacity is a setting, 85% by default, and hides while a controller is connected]
- [default: on iOS 17, without `GCEventInteraction`, the player takes no SwiftUI focus while a controller is connected, so a press reaches nothing under it]
- [default: the PS button opens the pause sheet when its press reaches the app (6e's live check); otherwise the pause button is the only way in]
- (consumed decision) A controller connecting and disconnecting is 6e's input service, which starts from `GCControllerDidConnect` (6e, W5); hiding the pad follows it.

**Guardrail(s).** The pad test above; a preview per board's state; a test that the pad's visibility follows the input service's connect and disconnect.

**Acceptance criteria:**
- [ ] The player, the pause sheet and the save-state sheet match their iPhone boards in the iOS Simulator.
- [ ] A PS1 game plays on an iPhone or iPad with the on-screen pad (v0.4.0's gate: the user's run).
- [ ] With a Bluetooth controller connected, the on-screen pad hides, the game plays, and no press reaches a control under the player (the user's run on a device).
- [ ] `swift test`, the strict build and both iOS routines' builds pass.

**Scope note.** v0.4.0, track 5, iOS only, gated on 5n, 5g, 6e and 5l.
