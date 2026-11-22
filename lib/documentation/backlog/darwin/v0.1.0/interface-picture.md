# The narrow interface: the picture and VRAM

**What / why.** **Split first.** This is gap G1 of the design: the app gets each frame's picture through `PS1Console`, and personal builds get VRAM. Contract rows C21, C22 and C45 wait on it, and so does v0.1.0's gate (the BIOS's shell and a homebrew PS-EXE drawing in the macOS app). Today the console's GPU keeps timing only (`source/business/ps1/GPU.swift`: `horizontalTiming`, `scanline`, `status` at `:120`): there is no VRAM and no rasterizer. ProjectPSX hands its host VRAM and the display's geometry through `IHostWindow` (`ProjectPSX/Host/IHostWindow.cs`): `Render(int[] vram)`, `SetDisplayMode(horizontalRes, verticalRes, is24BitDepth)`, `SetHorizontalRange`, `SetVerticalRange`, `SetVRAMStart`. Most of the work is the GPU itself, which ROADMAP v0.1.0 lists first ("The GPU and its software rasterizer, ported from ProjectPSX") and which no document specs yet. Split before building:
- **The GPU and its software rasterizer**: its own document, specced from ROADMAP v0.1.0's first line, ported from ProjectPSX's `Devices/GPU/GPU.cs`, `VRAM.cs` and `VRAM1555.cs`.
- **This document**: the interface member that hands a frame to the app, the personal-build VRAM snapshot, and EmuKit's Metal presentation of frames (ROADMAP v0.1.0's third line).
- **VRAM recorded from SwanStation and compared**: ROADMAP v0.1.0's fourth line, its own document.

**Core constraint(s).**
- **The clean room**: core code comes only from ProjectPSX, iStation's own code and public documentation (psx-spx); a GPL emulator is a black box whose recorded VRAM may be compared, never read ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework: the core hands pixels as plain values; Metal lives in Presentation.
- Per-pixel code uses concrete types and no allocation per frame ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §4).
- The VRAM snapshot is a personal-build tool ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).

**Seam + files.**
- Business, `ps1`: `PS1Console.picture: PS1Picture?` refreshed by `runFrame()` (width, height, 15- or 24-bit, the display area's pixels); under `PERSONAL_BUILD`, `vramSnapshot` (1024 × 512 at 16 bits).
- Presentation, `player`: a `FrameView` (`MTKView` in an `NSViewRepresentable`, and a `UIViewRepresentable` for the iPhone later) that uploads each picture's raw rows to a texture, converts 15- or 24-bit pixels in its fragment shader and draws the latest picture only, nearest-neighbour unless smoothing is on.
- Tests: `tests/business/ps1/` (a frame drawn by a code-built program gives the expected dimensions and pixels); `tests/presentation/player/` (the picture's size and shape for each mode).
- The design: the `Contract` board's G1 change (`html/Contract.dc.html`) names `PS1Picture`, carrying the display area's raw rows and their mode, one per vertical blank, replaced in place, converted by Metal's shader, in the same change.

**Reference.** The design: contract rows C21, C22, C45 and gap G1 on the `Contract` board; the `Layout` board's "The picture" row. ProjectPSX: `Host/IHostWindow.cs`, and `Devices/GPU/GPU.cs`, which sets GPUSTAT's PAL bit (bit 20) and 24-bit bit (bit 21) at `:216–217`. Public documentation: psx-spx's GPU display modes.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).
- 2026-11-22: the core hands the display area's raw 15- or 24-bit rows and their mode, and the conversion to a texture's format happens in the Metal shader, keeping pixel formats out of the core and the copy out of the hot path (the default, confirmed by the user).
- 2026-11-22: one picture per vertical blank, replaced in place, never queued; the session (5b) presents the latest (the default, confirmed by the user).
- 2026-11-22: the split happens before anyone builds: the GPU's document is written with `/istation-backlog-create-item` and takes its own v0.1.0 row ahead of this one; building the GPU is core work for a session that has read no GPL emulator's source (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** Hermetic tests over a program built in code that fills a known rectangle: the picture's size, mode and pixels match. VRAM compared with SwanStation's recorded VRAM is the fourth ROADMAP line's guardrail.

**Acceptance criteria:**
- [ ] The split's documents exist, and the GPU and its rasterizer are built.
- [ ] `PS1Console.picture` gives each frame's display area; the VRAM snapshot exists in personal builds only.
- [ ] A frame from a code-built program draws through `FrameView` at the right size.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 6, split first. Unblocks 5g (the picture on screen), and through it 5l's thumbnails and 5o's iPhone picture.
