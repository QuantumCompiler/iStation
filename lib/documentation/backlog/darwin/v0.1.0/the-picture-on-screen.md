# The picture on screen: the player, Video settings, screenshots and VRAM

**What / why.** Once frames cross the interface (6b), the design shows them:
- **The player:** the picture fills the window at 4:3, either fitted or in whole multiples of the console's resolution, nearest-neighbour unless smoothing is on. Until then 5b draws "No picture yet".
- **Settings › Video:** scale (fit the window or whole multiples), shape (TV 4:3 or square pixels), smoothing, and the HUD's frame counter. The renderer reads "Software" as plain text until there is a second renderer (6j).
- **Save Screenshot** (⇧⌘S): written to the container's Screenshots folder, with a toast.
- **VRAM tab** in Tools (personal builds): 1024 × 512 at 16 bits, shown at three quarters of its size.

**Core constraint(s).**
- Visuals from `styles` (5a); view-models import no UI toolkit (the scale and shape are states the view maps).
- The VRAM tab is personal-only, under `#if PERSONAL_BUILD` ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).
- Under the App Sandbox the App Store build reads only files the user chose (`apps/macos/AppStore.entitlements:6`), so screenshots stay in its container unless an entitlement is added.

**Seam + files.**
- Presentation, `player`: `FrameView` (6b) placed and scaled per the Video settings; Save Screenshot from the latest picture.
- Presentation, `settings`: the Video tab.
- Presentation, `tools`: the VRAM tab, from 6b's snapshot.
- Tests: `tests/presentation/player/` (picture size for each scale and shape at 1280 × 800 and 800 × 560), `tests/presentation/settings/` (Video defaults).

**Reference.** The design: boards `Mac-PlayerRunning`, `Mac-PlayerFullscreen`, `Mac-PlayerMin`, `Mac-SettingsVideo` and `Mac-ToolsVram`; contract rows C21–C24 and C45; the `Layout` board's picture sizes.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [user] Screenshots: keep them in the container's Screenshots folder with Show in Finder, as designed, or save to Pictures, which needs `com.apple.security.assets.pictures.read-write` in the App Store entitlements?
- [default: scale "Fit the window" and shape "TV shape (4:3)" by default, smoothing off]
- [default: the renderer shows as text until 6j gives a choice] The design leaves out what can't be chosen.

**Guardrail(s).** View-model tests for the picture's computed size at each scale, shape and window size; a preview per Video state; `ArchitectureTests` keep the VRAM tab personal-only.

**Acceptance criteria:**
- [ ] A homebrew PS-EXE's picture draws in the macOS player (v0.1.0's gate, with 6b), matching `Mac-PlayerRunning` and `Mac-PlayerFullscreen`.
- [ ] Settings › Video matches `Mac-SettingsVideo`; its choices change the picture at once.
- [ ] ⇧⌘S saves a screenshot and says where; the VRAM tab matches `Mac-ToolsVram` in personal builds.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 6b, 5e and 5f.
