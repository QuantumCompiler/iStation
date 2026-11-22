# Rumble

**What / why.** Wall W4 of the controller spike (2026-11-22): the DualShock has two vibration motors, a small one that is on or off and a large one with a level, which a game drives through the pad once it has mapped them (psx-spx, the 4Dh command). With 7a's analog pad nothing renders them. A modern controller can: measured, not guessed (2026-11-22, the spike's first live run under the App Store routine's sandbox), the user's DualSense reported `GCDeviceHaptics` with the localities All, Default, Handles, Left Handle and Right Handle, which lets each motor play in its own grip — the DualShock's large motor sits in the left grip, its small one in the right.

**Core constraint(s).**
- **The clean room** ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)): ProjectPSX has no rumble, so the motors are **iStation's own code from psx-spx**, in 7a's analog pad; MIT header, no provenance line ([ADR 0014](../../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)).
- Business imports no Apple framework: CoreHaptics and `GCDeviceHaptics` stay in 6e's input service (the `Gamepads` module, 6e's default); the core reports levels.
- The interface stays narrow ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)): one rumble value per port per frame, read after `runFrame()`.
- Hot paths stay concrete: the pad records the motors' bytes as it receives them, with no allocation and no callback.

**Seam + files.**
- Business, `ps1`: 7a's analog pad keeps the 4Dh mapping and the motors' bytes from each poll. `PS1Console.rumble(port: Int) -> PS1Rumble`, with `PS1Rumble` the small motor's on-or-off and the large motor's level (0–255).
- Business `session`: reads each port's rumble after each frame and hands changes to the input service.
- 6e's input service: a `CHHapticEngine` per grip from `GCDeviceHaptics.createEngine(withLocality:)`, a continuous haptic event per motor, its intensity updated when the level changes, stopped on pause, stop and disconnect.
- Tests: `tests/business/ps1/` (a program built in code maps the motors with 4Dh and sends their bytes; `rumble(port:)` reports them); the input service's tests over a fake haptics sink.

**Reference.** psx-spx, controllers: the analog controller's 4Dh command and the motor bytes in the poll. Apple's SDK: `GCDeviceHaptics.h` (`supportedLocalities`, `createEngineWithLocality:`) and CoreHaptics. The spike's evidence above. ProjectPSX: none.

**Decisions made** (dated):
- 2026-11-22: the analog pad, rumble and their settings are v0.3.0's, track 7 (the user's call).

**Open calls:**
- [default: the large motor plays in the left grip at its level ÷ 255, the small motor in the right grip at full intensity; a controller with one locality plays both through it; one without haptics plays nothing]
- [default: rumble is on by default; 7c's setting turns it off per port]
- [default: every motor stops when the session pauses or stops, when the controller disconnects and when iStation loses focus]

**Guardrail(s).** Hermetic tests: the program above, and a pad with no 4Dh mapping reports no rumble; the input service starts, changes and stops a fake sink's events as the levels change and on pause, stop and disconnect. A live check is the user's run with a DualSense and a game that rumbles.

**Acceptance criteria:**
- [ ] `rumble(port:)` reports the motors a program drives, tested as above.
- [ ] A rumbling game shakes a DualSense's grips (the user's run).
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 7, gated on 7a. Unblocks 7c. Out of scope: the DualSense's adaptive triggers and light bar colours, and haptics on the iPhone itself.
