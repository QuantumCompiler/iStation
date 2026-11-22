# Choosing the renderer

**What / why.** Gap G11 of the design: a choice between the software rasterizer and the Metal renderer (contract row C24). ROADMAP v0.3.0's first line, "A Metal renderer, checked against the software rasterizer", builds the renderer itself and has no document yet. Until it exists, Settings › Video shows "Software" as text (5g), because there is nothing to choose. This item adds the console setting that picks a renderer, and turns the text into a picker, once both renderers draw.

**Core constraint(s).**
- The renderer setting is one of ADR 0015 §5's settings crossing the narrow interface: a plain value.
- The two renderers must agree: the Metal renderer is checked against the software rasterizer (ROADMAP v0.3.0), so switching mid-game changes nothing a guest can see.
- Settings persist with defaults.

**Seam + files.**
- Business, `ps1`: a renderer value among the console's settings (`.software`, `.metal`), applied between frames.
- Presentation `settings`: the Video tab's renderer picker.
- Presentation `player`: what `FrameView` draws under the Metal renderer is the Metal renderer's document's to decide, since the core imports no Metal (ADR 0015 §1). 6b's raw-row upload and shader conversion (decided 2026-11-22) stay the software rasterizer's path, and 5g's screenshots and 5l's thumbnails keep a source of raw rows, or a read-back, under either renderer.
- Tests: `tests/business/ps1/` (switching between frames keeps VRAM), `tests/presentation/settings/` (the picker appears only with two renderers).

**Reference.** The design: board `Mac-SettingsVideo` and contract row C24; the `Layout` board's picture row.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: the default renderer is Metal once it passes its comparison with the software rasterizer, software otherwise]
- [default: this item builds after the Metal renderer's own document, which the v0.3.0 grooming writes from ROADMAP's first line, and gains that id as a gate then]

**Guardrail(s).** The tests above.

**Acceptance criteria:**
- [ ] With both renderers built, Settings › Video offers the choice and the picture changes renderer between frames.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 6, gated on 5g; the Metal renderer's document joins the gate when it is written.
