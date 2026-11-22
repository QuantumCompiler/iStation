# The narrow interface: pads

**What / why.** Gap G4 of the design: buttons reach the console (contract rows C28, C29, C54). Today the console's controller ports are a stub (`source/business/ps1/DeviceStubs.swift:77`, `PortsStub`) answering the BIOS's polls with no pad. ProjectPSX's ports are `Devices/Input/JOYPAD.cs` with a digital pad, `Controller.cs` and `DigitalController.cs`. The host presses and releases buttons through `JoyPadDown`/`JoyPadUp(GamepadInputsEnum)` (`ProjectPSX/Core/ProjectPSX.cs:66–68`, `Devices/Input/GamepadInputsEnum.cs`). ROADMAP v0.2.0's line "Pads and memory cards, through the GameController framework" owns this; the memory-card half is 6f. On the app side, GameController delivers each controller's and the keyboard's state to the session, which hands the console one value per port.

**Core constraint(s).**
- **The clean room**: the port and pad come only from ProjectPSX, iStation's own code and psx-spx ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework: GameController stays on the app side; the core takes plain button bits.
- The interface stays narrow: one value per port per frame, not callbacks.

**Seam + files.**
- Business, `ps1`: the ports device replacing `PortsStub`, ported from ProjectPSX; `PS1Console.setPad(port: Int, buttons: PS1PadButtons)` with `PS1PadButtons` an `OptionSet` of the 14 digital buttons.
- Business `session` (5b): applies the latest pad state before each frame.
- The app side: an input service over `GCController` and `GCKeyboard`, mapping elements to `PS1PadButtons` per port with the design's defaults.
- Tests: `tests/business/ps1/` (a code-built program reads the pad's bits through the port protocol); `tests/business/session/` (state applied per frame).

**Reference.** The design: contract rows C27–C29 and C54 and gap G4 on the `Contract` board; the mapping table on `Mac-SettingsControllers`. ProjectPSX: the files above. Public documentation: psx-spx's controllers and memory cards chapter. The ProjectPSX trace host empties both ports so the three consoles agree (`tools/projectpsx-trace/README.md`): with a pad plugged in, the boot traces will differ from the oracle's, so recorded comparisons keep the ports empty.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).

**Open calls:**
- [default: a digital pad only for now; the pad type (digital, analog) and sticks come later with their own member] The design shows "Digital pad".
- [default: the app sends each port's state once per frame, before `runFrame()`]

**Guardrail(s).** Hermetic tests: a program built in code polls port 1 and sees exactly the bits set; with nothing plugged in, the BIOS's poll sees no pad, as today.

**Acceptance criteria:**
- [ ] The ports device replaces `PortsStub`; `setPad(port:buttons:)` reaches a program's polls, tested as above.
- [ ] A controller's and the keyboard's buttons reach the console through the session.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6. Unblocks 5j and 6f, and the iPhone's on-screen pad (5o).
