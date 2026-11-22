# The picture on screen: the player, Video settings, screenshots and VRAM

**What / why.** Once frames cross the interface (6b), the design shows them:
- **The player:** the picture fills the window at 4:3, either fitted or in whole multiples of the console's resolution, nearest-neighbour unless smoothing is on. Until then 5b draws "No picture yet".
- **Settings › Video:** scale (fit the window or whole multiples), shape (TV 4:3 or square pixels), smoothing, and the HUD's frame counter. The renderer reads "Software" as plain text until there is a second renderer (6j).
- **Save Screenshot** (⇧⌘S): written to the container's Screenshots folder, with a toast.
- **VRAM tab** in Tools (personal builds): 1024 × 512 at 16 bits, shown at three quarters of its size.

**Core constraint(s).**
- Visuals from `styles` (5a); view-models import no UI toolkit (the scale and shape are states the view maps).
- The VRAM tab is personal-only, under `#if PERSONAL_BUILD` ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).
- Under the App Sandbox the App Store build reads only files the user chose (`apps/macos/AppStore.entitlements:6`), so screenshots stay in its container, and its entitlements gain nothing for them. The app target resolves the Screenshots folder in its own container and hands the player the URL: nothing in the package reaches the home folder (`noRealHome`).

**Seam + files.**
- Presentation, `player`: `FrameView` (6b) placed and scaled per the Video settings; Save Screenshot from the latest picture, its raw 15- or 24-bit rows converted to RGBA in Presentation, off the hot path and never in the core, by one shared converter in `styles`, which `player`, `tools`' VRAM tab and 5l's save-state thumbnails all use (ADR 0020's bar for sharing; 6b's shader converts only what is drawn on screen).
- The design, in the same change (its CLAUDE.md): the screenshot toast in `html/main.html` gains its Show in Finder button, and `Processes.dc.html`'s Screenshots row says it is shown in the Finder from the toast, with no Pictures entitlement.
- Presentation, `settings`: the Video tab.
- Presentation, `tools`: the VRAM tab, from 6b's snapshot.
- Tests: `tests/presentation/player/` (picture size for each scale and shape at 1280 × 800 and 800 × 560), `tests/presentation/settings/` (Video defaults).

**Reference.** The design: boards `Mac-PlayerRunning`, `Mac-PlayerFullscreen`, `Mac-PlayerMin`, `Mac-SettingsVideo` and `Mac-ToolsVram`; contract rows C21–C24 and C45; the `Layout` board's picture sizes.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: screenshots stay in the app's own Screenshots folder, in its container, with a toast and Show in Finder, as designed; no Pictures entitlement joins the App Store build (the user's call).
- 2026-11-22: the Video defaults are scale "Fit the window", shape "TV shape (4:3)" and smoothing off (the default, confirmed by the user).
- 2026-11-22: the renderer shows as text, "Software", until 6j gives a choice: the design leaves out what can't be chosen (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** View-model tests for the picture's computed size at each scale, shape and window size; a preview per Video state; `ArchitectureTests` keep the VRAM tab personal-only.

**Acceptance criteria:**
- [ ] A homebrew PS-EXE's picture draws in the macOS player (v0.1.0's gate, with 6b), matching `Mac-PlayerRunning` and `Mac-PlayerFullscreen`.
- [ ] Settings › Video matches `Mac-SettingsVideo`; its choices change the picture at once.
- [ ] ⇧⌘S saves a screenshot to the app's own Screenshots folder and says where, with Show in Finder; the App Store entitlements are unchanged. The VRAM tab matches `Mac-ToolsVram` in personal builds.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 6b, 5e and 5f.
