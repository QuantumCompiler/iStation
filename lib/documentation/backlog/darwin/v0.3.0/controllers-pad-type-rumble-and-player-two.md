# Controllers: the pad type, rumble and player 2

**What / why.** 5j builds Settings › Controllers for one player on a digital pad: connected controllers with a port picker, port 1's mapping, the keyboard, the HUD's ports line. The controller spike (2026-11-22) added a second port (6e), an analog pad (7a) and rumble (7b), and nothing lets a person choose them. This item adds, per port:
- **Its own mapping**: port 2 gets the table port 1 has, with Restore Defaults.
- **The pad type**: Digital or Analog (DualShock), contract row C54, which today shows "Digital pad".
- **Rumble**: on or off, shown for an analog pad on a controller that reports haptics.
- **The analog pad's extra elements**: L3, R3 and the Analog button in the mapping.
- **The player number on the controller**: `GCController.playerIndex` set to the controller's port, so a DualSense's player lights show 1 or 2.

**Core constraint(s).**
- View-models import no UI toolkit: GameController reaches them through 6e's injected input service, with fakes in previews and tests.
- Settings persist with defaults, so an install from before this item keeps loading: port 2's mapping, the pad type (digital) and rumble (on) decode with their defaults.
- No Sony marks: buttons in words, no logo or coloured shapes.

**Seam + files.**
- Presentation `settings`: 5j's Controllers tab and its view-model gain the per-port rows above.
- Presentation `player`: the HUD's ports line names the pad type ("Port 1: Wireless Controller · Analog").
- The input service (6e): `playerIndex` set per port; the pad type and rumble setting passed to the session and the console (7a, 7b).
- The design: the canvas has no boards for these states, so they're added first, on the canvas, and mirrored into `lib/documentation/design/darwin/` with its tools (`mirror.mjs`, then `check.mjs`).
- Tests: `tests/presentation/settings/` (port 2's mapping, the pad type, rumble's row shown and hidden, the defaults an older settings file decodes to).

**Reference.** The design: `Mac-SettingsControllers`, `Mac-SettingsNoControllers` and `Mac-PlayerRunning`; contract rows C27–C29 and C54. 5j's document, which this extends. The spike's evidence: the DualSense reported a light, haptics with left and right grips, and a battery (7a, 7b and 6e carry the measurements).

**Decisions made** (dated):
- 2026-11-22: both ports carry a pad, and a second controller plays on port 2 (the user's call).
- 2026-11-22: the analog pad, rumble and their settings are v0.3.0's, track 7 (the user's call).

**Open calls:**
- [default: a new port's pad type is Digital, and rumble is on] The safe choice for games that know nothing of analog (7a's default).
- [default: port 2's default mapping is port 1's for controllers; for the keyboard, port 2 has no default keys and is mapped by hand]
- [default: the iPhone's settings (5n's Controllers row) use the same view-model, built with 5n]

**Guardrail(s).** View-model tests for every new state over a fake input service; a preview per state matching its new board; a settings file from before this item decodes to the defaults above.

**Acceptance criteria:**
- [ ] Each port's mapping, pad type and rumble can be set and restored, matching the new boards.
- [ ] A DualSense's player lights show its port.
- [ ] The HUD names each port's device and pad type.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 7, gated on 7a, 7b and 5j. Out of scope: a dead-zone setting (7a's default leaves it for later), the iPhone's views (5n, v0.4.0).
