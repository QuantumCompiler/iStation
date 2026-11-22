# The analog pad: the DualShock

**What / why.** Wall W3 of the controller spike (2026-11-22): the console has no analog pad, so games that need a DualShock can't be played and a modern controller's sticks go unused. ProjectPSX's only pad is the digital one: its type is 0x5A41 (`ProjectPSX/Devices/Input/DigitalController.cs:4`), it answers only the poll (`0x01`, then `0x42`), and it has no analog mode, no configuration commands and no sticks. 6e ports that pad and leaves "the pad type (digital, analog) and sticks" for later; the design's contract row C54, "Digital or analog pad", shows "Digital pad" until the core has a pad type, and gap G4's note names the same later member. This item is that later.

Measured, not guessed (2026-11-22, the spike's second live run: the user's DualSense over Bluetooth, under the App Store routine's sandbox): both sticks reported their full range — the left stick from x −1.00 to 1.00 and y −1.00 to 1.00, the right to x 1.00 — and both stick clicks (`Left Thumbstick Button`, `Right Thumbstick Button`) arrived, which on a DualShock are L3 and R3. GameController's y axis is positive up (the direction pad read y = 1 for up, and the sticks the same), so the pad's stick bytes, which psx-spx gives as 00h for up and left, are inverted on y.

**Core constraint(s).**
- **The clean room** ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)): ProjectPSX has no analog pad to port, so the DualShock is **iStation's own code, written from psx-spx's controllers chapter**, beside 6e's ported digital pad. Its file carries iStation's MIT header and no provenance line ([ADR 0014](../../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)); never from a GPL emulator's source.
- Business imports no Apple framework: the core takes stick bytes, and the mapping from GameController's floats lives above it, with 6e's input service.
- The interface stays narrow ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)): one pad state per port per frame.
- Recorded comparisons keep both ports empty, as 6e's do (`tools/projectpsx-trace/README.md`).

**Seam + files.**
- Business, `ps1`: an analog pad beside 6e's digital pad, under the same `Controller` shape ProjectPSX uses. From psx-spx: the ID byte (41h in digital mode, 73h in analog mode, F3h in configuration mode), the four stick bytes after the two button bytes (right X, right Y, left X, left Y; 00h–FFh, 80h centred), L3 and R3 in button bits 1 and 2, the configuration commands (43h to enter and leave configuration, 44h to set analog or digital and lock the mode, 45h and the constant queries), and the mode the pad starts in. 4Dh, the rumble mapping, is 7b's.
- `PS1Console`: `setPad(port: Int, state: PS1PadState)` beside 6e's `setPad(port:buttons:)`, with `PS1PadState` the buttons plus both sticks' bytes; `setPadType(port: Int, _ type: PS1PadType)` (`.digital`, `.analog`), contract row C54.
- 6e's input service and the session: both sticks and both stick clicks mapped to `PS1PadState` (floats to bytes, y inverted).
- Tests: `tests/business/ps1/` (programs built in code drive the protocol); the mapping over snapshot controllers.

**Reference.** psx-spx, controllers and memory cards: the analog controller's ID bytes, stick bytes and configuration commands. ProjectPSX: `Controller.cs` and `DigitalController.cs`, the shape the analog pad joins (and their absence of any analog mode, the reason this is iStation's own). The design: contract row C54 and gap G4. The spike's evidence above. A PS2's DualShock 2 (pressure-sensitive buttons) belongs to v2.x and Play!.

**Decisions made** (dated):
- 2026-11-22: the analog pad, rumble and their settings are v0.3.0's, a new track 7 from the controller spike (the user's call).
- 2026-11-22: both ports carry a pad (the user's call; 6e builds the second slot).

**Open calls:**
- [default: an analog pad powers on in digital mode, as the hardware does; a game switches it with 44h, and a lock it sets holds] Games that know nothing of analog then see the digital pad they expect.
- [default: no dead zone in the core; the input service passes the stick's value unchanged, and a dead zone, if one is needed, is a setting later]
- [default: the DualShock's Analog button has no default element (the DualSense, Xbox and MFi controllers have none); 7c offers it in the mapping]
- [default: the left stick doesn't drive the direction pad in digital mode]

**Guardrail(s).** Hermetic tests with programs built in code: in digital mode a poll returns ID 41h and two button bytes; after 43h, 44h (analog) and 43h, it returns 73h and six bytes, the sticks as set through `setPad(port:state:)`; a locked mode refuses the Analog button; a port set to `.digital` behaves exactly as 6e's pad. The mapping's tests: full deflection in each direction gives 00h or FFh, centre 80h, up 00h.

**Acceptance criteria:**
- [ ] Each port can carry an analog pad; its protocol passes the tests above.
- [ ] A controller's sticks and stick clicks reach the console as a DualShock's.
- [ ] A game that needs a DualShock reads the analog pad (the user's run, with their own game).
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 7, gated on 6e. Unblocks 7b and 7c. Out of scope: rumble (7b), the pad type's setting and port 2's mapping (7c), the PS2's DualShock 2 (v2.x).
