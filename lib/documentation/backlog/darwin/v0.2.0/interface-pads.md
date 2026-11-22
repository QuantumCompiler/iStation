# The narrow interface: pads

**What / why.** Gap G4 of the design: buttons reach the console (contract rows C28, C29, C54). Today the console's controller ports are a stub (`source/business/ps1/DeviceStubs.swift:77`, `PortsStub`) answering every byte with 0xFF and no acknowledge, so no button reaches a game. ProjectPSX's ports are `Devices/Input/JOYPAD.cs` with a digital pad, `Controller.cs` and `DigitalController.cs`. The host presses and releases buttons through `JoyPadDown`/`JoyPadUp(GamepadInputsEnum)` (`ProjectPSX/Core/ProjectPSX.cs:66–68`, `Devices/Input/GamepadInputsEnum.cs`). ROADMAP v0.2.0's line "Pads and memory cards, through the GameController framework" owns this; the memory-card half is 6f. On the app side, GameController delivers each controller's and the keyboard's state, which reaches the console as one value per port.

**The controller spike (2026-11-22)** checked this against real hardware. Measured, not guessed: a probe app signed ad-hoc with the App Store routine's macOS entitlements (App Sandbox, read-only user-selected files, `allow-jit`), macOS 27.0.1, SDK 27.2, the user's DualSense over Bluetooth in three runs.
- **No new permission.** GameController worked inside the sandbox with no Bluetooth or USB entitlement, no usage string and no CoreBluetooth: the DualSense connected as `GCDualSenseGamepad` (category "DualSense"), battery 0.95. Pairing is System Settings' job, and GameController treats Bluetooth and USB controllers alike, so "Bluetooth controllers" is this item plus 5j.
- **The design's mapping is right on hardware.** Faces by position (Button A Cross, B Circle, X Square, Y Triangle), the shoulders and triggers, the direction pad, Select on the Options (Create) button and Start on the Menu (Options) button: all 14 digital buttons arrived as the right PS1 bit across two runs.
- **Six things this document didn't say**, each now below: port 2 has no reference to port (W2); controllers and the keyboard appear only after launch (W5); `isPressed` is no threshold (W6); two buttons belong to the system (W7); the handoff to the session's thread (W8); and focus (W9). The iOS app's declarations (W10's half) are here too; the analog pad (W3) is 7a and rumble (W4) is 7b.

**Core constraint(s).**
- **The clean room**: the port and pad come only from ProjectPSX, iStation's own code and psx-spx ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)). Port 2 is iStation's own (below), and its file says so.
- Business imports no Apple framework: GameController stays out of `ps1` and `session`; the core takes plain button bits.
- The interface stays narrow: one value per port per frame, not callbacks ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)).
- Tests and previews never touch the real home folder: the input code is tested over GameController's snapshot controllers, never a live device.
- Recorded comparisons keep both ports empty: the ProjectPSX trace host empties them so the three consoles agree (`tools/projectpsx-trace/README.md`), and a pad plugged in changes the boot's traces.

**Seam + files.**
- Business, `ps1`: the ports device replacing `PortsStub`, ported from ProjectPSX's `JOYPAD.cs` and `DigitalController.cs`, with **both slots**. ProjectPSX answers the second slot with 0xFF every time (`JOYPAD.cs:93`, its `desiredSlotNumber == 1` branch) and builds one pad (`ProjectPSX.cs:30`), so the second slot, chosen by JOY_CTRL's slot bit as psx-spx describes, is iStation's own code: a deliberate divergence, named in the file. `PS1Console.setPad(port: Int, buttons: PS1PadButtons)` with `PS1PadButtons` an `OptionSet` of the 14 digital buttons (psx-spx's bit order: Select, Start, the four directions, L2, R2, L1, R1, Triangle, Circle, Cross, Square; bits 1–2, L3 and R3, are 7a's).
- Business `session` (5b): `setPad(port:buttons:)` on the session latches the latest value and applies it before each `runFrame()`.
- The input service, over `GCController` and `GCKeyboard` — see the open call on its module. It maps elements to `PS1PadButtons` per port with the design's defaults, assigns devices to ports, claims the system's buttons during play and releases every button when iStation loses focus.
- Both apps' Info.plist: `GCSupportedGameControllers` (`ProfileName` `ExtendedGamepad`) and `GCSupportsControllerUserInteraction`, the keys Xcode's own definitions name for controller support (`DVTCorePlistStructDefs`). Neither app declares them today: the targets set only the category, scene, launch-screen and orientation keys (`iStation.xcodeproj/project.pbxproj:432–435, 455–458, 492, 525`).
- Tests: `tests/business/ps1/` (a code-built program polls each port through the port protocol and sees exactly the bits set); `tests/business/session/` (the latched value applied per frame); the input service's tests over snapshot controllers.

**What the spike measured, per wall.**
- **W2, port 2.** The design's HUD reads "Port 1: Wireless Controller · Port 2: Keyboard" (`lib/documentation/design/darwin/html/main.html`, `P.ports`), and two controllers mean two players; ProjectPSX has no second slot (above).
- **W5, readiness.** At launch `GCController.controllers()` was empty and `GCKeyboard.coalesced` nil; `GCControllerDidConnect` came 110 ms later for a controller already on, `GCKeyboardDidConnect` 42 and 57 ms later in two runs. A service that reads state at start sees "no controller", and Settings would flash the no-controller board.
- **W6, thresholds.** On a snapshot controller (`GCController.withExtendedGamepad()`) a trigger reads `isPressed` between 0.001 and 0.01, and a stick's direction at 0.3; seven mapping checks passed, the eighth (L2 at 0.05) read pressed. The DualSense's L2 and R2 registered on hardware, but the threshold must be iStation's.
- **W7, the system's buttons.** On the DualSense, `Button Home` (PS) and `Button Options` (Create, which is Select) are bound to system gestures (`isBoundToSystemGesture`). In the first run, pressing PS took the user out of the probe (it resigned active). In the second, with Home's `preferredSystemGestureState = .disabled`, PS pressed several times left the probe in front, but neither PS nor the touchpad click reached its `pressedChangedHandler`, while the shoulders, stick clicks and sticks did. macOS 27 and iOS 27 add `GCControllerHomeButtonSettingsManager`: read in that run, its system action was 0 ("other") and its in-app action 0 ("system default"), neither customized; it needs `#available` on the macOS 14 and iOS 17 targets.
- **W8, the handoff.** The session runs off the main actor (5b) while GameController calls back on the main queue; `Synchronization.Atomic` fails to compile against the macOS 14 target ("only available in macOS 15.0 or newer"), and the targets are macOS 14 and iOS 17 (`lib/src/darwin/Package.swift:103`). One read of all 14 elements takes 1.5 µs (200,000 reads in 0.30 and 0.31 s, two runs), so reading on the main actor per change costs nothing.
- **W9, focus.** `GCController.shouldMonitorBackgroundEvents` is false by default on macOS (the header; false at launch in every run): input stops while another app is in front. The probe logged no events in its two inactive spans.

**Reference.** The design: contract rows C27–C29 and C54 and gap G4 on the `Contract` board; the mapping table on `Mac-SettingsControllers` (`main.html`, `MAPPING`). ProjectPSX: the files above. Public documentation: psx-spx's controllers and memory cards chapter. Apple's SDK: `GCController.h` (`shouldMonitorBackgroundEvents`, `controllerWithExtendedGamepad`), `GCControllerElement.h` (`preferredSystemGestureState`), `GCControllerHomeButtonSettingsManager.h`. In-house: the JIT probe's sandboxed probe app (`tools/jit-probe/`), the pattern the controller probe followed.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).
- 2026-11-22: both ports carry a pad: a second controller plays on port 2 (the user's call).
- 2026-11-22: iStation claims the PS (Home) button while a game runs — `preferredSystemGestureState = .disabled` — so it no longer leaves the game, and gives it back on pause and stop (the user's call).
- 2026-11-22: when another app comes to the front, the game keeps running and input stops: `shouldMonitorBackgroundEvents` stays false (the user's call).

**Open calls:**
- [default: a digital pad only here; the pad type (digital, analog) and sticks are 7a's] The design shows "Digital pad".
- [default: the input service pushes each change from the main actor to the session's `setPad(port:buttons:)`, which latches it and applies it before the next `runFrame()`] W8: no atomics below macOS 15.
- [default: the input service is a new Infrastructure module, `Gamepads` (`Module(.infrastructure, "Gamepads")`), wrapping GameController in `Sendable` values — connections, each frame's element states, the system's buttons, and 7b's haptics — with the mapping to `PS1PadButtons` in Business `session`] It is no Presentation place, so it takes no `Views/`; below the session, it keeps GameController out of Business, and snapshot controllers test it under `swift test`.
- [default: the service starts from `GCControllerDidConnect`, `GCKeyboardDidConnect` and their disconnects, never from a read at launch] W5.
- [default: L2 and R2 press at a value of 0.5; on the digital pad the sticks drive nothing] W6.
- [default: the Create (Options) button is claimed during play too, so a held Select takes no screenshot] Its binding is measured; the action it triggers isn't.
- [default: while the PS button is claimed, its press toggles Pause through the session when it reaches the app; the second run saw it not reach the probe, so a live run decides (the user's), and without it the button is only claimed] W7.
- [default: when iStation loses focus, every port's buttons are released, so a held button doesn't stay down]
- [default: a new controller takes the lowest free port; the keyboard takes port 1 when no controller does, and the next free port otherwise] The design's "Port 2: Keyboard".
- [default: both apps declare `ExtendedGamepad` and controller interaction; how the array key reaches the generated Info.plist is the builder's] Whether the Mac App Store reads it isn't verified.

**Guardrail(s).** Hermetic tests: a program built in code polls each port and sees exactly the bits set; with nothing plugged in, the BIOS's poll sees no pad on either port, as today. The mapping over snapshot controllers: every button of the design's table, the trigger threshold (0.05 doesn't press, 0.5 does), and release on focus loss.

**Acceptance criteria:**
- [ ] The ports device replaces `PortsStub` with both slots; `setPad(port:buttons:)` reaches a program's polls on each port, tested as above.
- [ ] A controller's and the keyboard's buttons reach the console through the session, port by port.
- [ ] During play the PS button doesn't leave iStation (the user's run with a controller, as the spike's second run).
- [ ] Both apps declare controller support in their Info.plist.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6, gated on 5b (the session it latches into). Unblocks 5j, 6f and 7a, and the iPhone's on-screen pad (5o). Out of scope: the analog pad (7a), rumble (7b), their settings and port 2's mapping (7c).
