# The narrow interface: the video standard

**What / why.** Gap G12 of the design: whether a game runs at 50 or 60 frames a second (contract row C25). Until it's known, the session paces at 60 (5b) and the HUD shows frames per second without a target, so nothing claims full speed. The GPU's status word carries the standard in bit 20: ProjectPSX sets it from its `isPal` flag (`Devices/GPU/GPU.cs:216`) and changes the vertical timing with it (`:1149–1150`, 314 lines for PAL, 263 for NTSC). iStation's GPU has a `status` word today (`source/business/ps1/GPU.swift:120`) and will have the display-mode command with 6b's split. This item reports the standard through `PS1Console`, has the session pace to it, and gives the HUD a target: "60 fps", or "52 of 60 fps" when behind.

**Core constraint(s).**
- **The clean room**: from ProjectPSX and psx-spx only ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework; the member is a plain value read between frames.

**Seam + files.**
- Business, `ps1`: `PS1Console.videoStandard: PS1VideoStandard` (`.ntsc`, `.pal`) from GPUSTAT bit 20.
- Business `session` (5b): paces to 60 or 50.
- Presentation `player`: the HUD's frames-per-second text with its target.
- Tests: `tests/business/ps1/` (a code-built program switching to PAL), `tests/business/session/` (50 frames a second for PAL).

**Reference.** The design: contract rows C08 and C25 and gap G12 on the `Contract` board. ProjectPSX: `Devices/GPU/GPU.cs` as above. Public documentation: psx-spx's GPU status register.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the HUD shows "60 fps" at speed and "52 of 60 fps" when behind] The design doesn't draw the second form yet: add its preset and board in the design in the same change.

**Guardrail(s).** The tests above.

**Acceptance criteria:**
- [ ] `videoStandard` reports PAL and NTSC from GPUSTAT; the session paces to it; the HUD shows the target as designed, its board added to the design.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 6, gated on 6b (the GPU's display-mode command arrives with its split).
