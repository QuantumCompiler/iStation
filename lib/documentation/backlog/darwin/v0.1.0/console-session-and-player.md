# The console session and the player

**What / why.** In the design the player takes over the Mac app's one window while a game or the BIOS runs. Its toolbar has Stop (⌘.), Pause and Resume (⌘P), Reset (⌘R) and Full screen (⌃⌘F). A HUD gives the status, the frame counter and the frames per second. Until frames exist (6b, 5g) a "No picture yet" panel shows the frame count, and a paused overlay offers Resume. Reset and Stop each confirm in an alert whose Details shows the exact call. Today the player is one state, "Nothing to play yet." (`PlayerViewModel.swift:14, 29`), and nothing runs the console. Behind the player sits the service that runs the console off the main actor, which every later screen uses: power, frames at a steady pace, pause, reset and stop. Measured, not guessed, 2026-11-21 (probe over the CPU-check image built in code): 60 `runFrame()` calls took 0.014 s, so the session must pace frames, not race them; powering on again brought `frame` back to 0, which is how Reset works (contract row C06).

**Core constraint(s).**
- The layer law ([ADR 0018](../../../adrs/darwin/four-layers-dependencies-point-down.md)): the session sits below Presentation and imports no UI or Apple framework, only the standard library and Swift concurrency; a new module is a row, a directory, a test directory, a card line and an ADR 0002 row in the same change.
- View-models import no UI toolkit; the view maps their states to `styles` (5a) ([ADR 0020](../../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)).
- A core is driven from one thread ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §4); work leaving the main actor runs in a `Task.detached` inside the service that owns it.
- Tests and previews never touch the real home or a real BIOS: build images in code.

**Seam + files.**
- Business, new module `session` (`Module(.business, "Session", uses: ["BusinessPS1"])`): `ConsoleSession` owns one `PS1Console`, runs it on its own task paced by `ContinuousClock` at 60 frames a second, and offers power on (with BIOS bytes), pause, resume, reset, stop, plus a `Sendable` snapshot stream (frame, frames per second, running or paused).
- Presentation, `player`: `PlayerViewModel` gains states (`.running`, `.paused`, `.stopped`) and intents (pause, resume, reset, stop, full screen) over a session protocol, and is told the BIOS file's name and size by whatever starts it (5c's Run the BIOS, 5d's opening job; a code-built image in tests and previews) for Reset's Details; `PlayerView` draws the HUD, the "No picture yet" panel, the paused overlay, and the Reset and Stop alerts through `DetailsAlert` (5a); `Previews/` per state over a fake session.
- The macOS app target: the main window shows the library (5d) or the player, one at a time; its toolbar and the Game menu's commands with their keys.
- Tests: `tests/business/session/` (pacing, pause holds the frame, reset returns to 0, stop releases), `tests/presentation/player/` (each state and intent over the fake).
- The Business layer card's Position (`source/business/CLAUDE.md`: "the cores — what a console does") and [ADR 0018](../../../adrs/darwin/four-layers-dependencies-point-down.md) §3's definition of Business ("the cores, what a console does") gain `session`, what the apps do with a core: the card in this change, the ADR by a superseding record (ADRs are append-only).
- The design: `Processes.dc.html`'s console-thread row says the Business `session` paces `runFrame` by `ContinuousClock` at 60 a second until the video standard is known (G12), not "at the display's pace", in the same change.

**Reference.** The design: boards `Mac-TodayPlayer` (today's player: frames, no picture), `Mac-PlayerPaused`, `Mac-PlayerFullscreen`, `Mac-ResetConfirm`, `Mac-StopConfirm`, `Mac-PlayerMin`, and `Mac-PlayerRunning` for the HUD; contract rows C03–C08, C48, C50; the `Processes` board's console thread. In-house: `istation-run`'s run loop times emulation apart from its own work (`tools/istation-run/Sources/main.swift`), the pattern for the frames-per-second measure.

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: the runner is a new Business module, `session`: not a core, but what the apps do with one, free of UI frameworks (the default, confirmed by the user).
- 2026-11-22: frames are paced by `ContinuousClock` at 60 a second until 6h reports the video standard; frames per second is shown without a target until then (G12) (the default, confirmed by the user).
- 2026-11-22: one window: the player takes the main window, one console at a time, as the design has it (the default, confirmed by the user).
- 2026-11-22: Stop asks first and saves nothing by itself; Save First… joins the Stop alert with save states (5l) (the default, confirmed by the user).
- 2026-11-22: Reset's and Stop's Details name the calls as the design does, e.g. "PS1Console.powerOn(bios:) with my-console-bios.bin (524,288 bytes)" — the design's placeholder name; the app shows the kept file's own (the default, confirmed by the user).
- 2026-11-22: the design's changes land in its local mirror, pass its checks and are published to the canvas as this item lands, keeping the two identical (the user's call, before the group run).
- 2026-11-22: each screen is checked against its board by rendering its previews to images and comparing them with the board in the built-in browser; no app is launched for the check (the user's call, before the group run).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** Session tests over a code-built BIOS image: 60 frames take about one second of `ContinuousClock` time; paused, the frame count holds; Reset returns the frame to 0; Stop releases the console. View-model tests cover each state and intent; a preview per state matches its board.

**Acceptance criteria:**
- [ ] `ConsoleSession` runs a console at 60 frames a second, pauses, resumes, resets and stops, with tests as above.
- [ ] The macOS player matches `Mac-TodayPlayer`, `Mac-PlayerPaused`, `Mac-PlayerFullscreen`, `Mac-ResetConfirm` and `Mac-StopConfirm`, with ⌘P, ⌘R, ⌃⌘F and ⌘. working.
- [ ] Reset and Stop each ask first, as `Mac-ResetConfirm` and `Mac-StopConfirm` show: Reset's Details name `PS1Console.powerOn(bios:)` with the BIOS file's own name and size (the design's `my-console-bios.bin` is a placeholder), Stop's say it ends the console's run loop and releases it, leaving the disc image and the BIOS unchanged; Stop saves nothing.
- [ ] At 800 × 560 the player still fits (`Mac-PlayerMin`); the player area is at least 640 × 480 (`Metrics` today).
- [ ] The new module has its row, card lines (Modules and Position), ADR 0002 row, and tests in the `macOS Personal` scheme (a scheme of its own is for Presentation modules, ADR 0017), and the record superseding ADR 0018 names `session` in Business; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5a. The picture in the player is 5g's (after 6b); the debug drawer is 5f's.
