# Controllers

**What / why.** With pads crossing the interface (6e), the design adds a Controllers tab to Settings:
- **Connected controllers:** each with its battery where it reports one, and a port picker.
- **Port 1's mapping:** 14 console buttons, each against a controller element and a keyboard key, with Restore Defaults.
- **No controller:** the keyboard plays on port 1.
- **The player's HUD:** says what is on each port ("Port 1: Wireless Controller · Port 2: Keyboard").

Pad buttons are named in words (Cross, Circle, Square, Triangle), never drawn as shapes on the Mac.

**Core constraint(s).**
- View-models import no UI toolkit: GameController state reaches them through an injected input service, with fakes in previews and tests.
- Settings persist with defaults, so an older install keeps loading.
- No Sony marks: buttons in words, no logo or colored shapes.

**Seam + files.**
- Presentation `settings`: the Controllers tab and its view-model over the input service (6e).
- Presentation `player`: the HUD's ports line.
- Tests: `tests/presentation/settings/` (connect, disconnect, port change, restore defaults, the no-controller state).

**Reference.** The design: boards `Mac-SettingsControllers`, `Mac-SettingsNoControllers` and `Mac-PlayerRunning` (the HUD); contract rows C27–C29 and C54. Its default keys: arrows for the direction pad, X Cross, C Circle, Z Square, S Triangle, Q L1, E R1, 1 L2, 3 R2, Space Select, Return Start.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the design's default keys and element mapping, as above]
- [default: a controller's battery shows only when GameController reports one] Contract row C27 is tagged verify: reporting varies by controller.
- [default: ⌘ shortcuts never reach the game; plain keys do while the player has focus]

**Guardrail(s).** View-model tests for every state over a fake input service; a preview per state matching its board.

**Acceptance criteria:**
- [ ] Settings › Controllers matches `Mac-SettingsControllers` and `Mac-SettingsNoControllers`; remapping and Restore Defaults work.
- [ ] A connected controller and the keyboard both play; the HUD names each port's device.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 5, gated on 6e and 5e.
