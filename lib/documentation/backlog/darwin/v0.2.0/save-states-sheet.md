# Save states

**What / why.** With save states crossing the interface (6g), the design adds:
- **Save State… (⌘S) and Load State… (⌘L):** a sheet of eight slots per game, each with its picture, when it was saved, the frame and the format.
- **Confirmations:** replacing a filled slot confirms ("can't be undone"), with `saveState()` under Details. Loading confirms that what's happening now is replaced.
- **Older formats:** a save in an older format is refused with both formats named, never loaded.
- **Stopping:** Stop's alert gains Save First….
- **Game info:** shows how many saves a game has.

**Core constraint(s).**
- A save state carries its version; an older one is refused with a message ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- View-models import no UI toolkit; slot files are an injected store.
- Nothing is saved without the person asking: no automatic save on Stop.

**Seam + files.**
- Presentation, new place `savestates`: the sheet's view-model over the session (5b) and a slot store, with views and previews per state.
- Presentation `player`: the toolbar and Game menu commands; Stop's Save First….
- Presentation `library`: Game info's save-state count.
- The app side: `…/Application Support/iStation/Save States/<serial>/slot-<n>.state`, each with a thumbnail made from the latest picture's raw 15- or 24-bit rows (6b) by 5g's shared converter in `styles`, since the core hands no RGBA and Metal converts only what is on screen (decided 2026-11-22).
- Tests: `tests/presentation/savestates/` (first empty slot chosen, replace confirming, load confirming, older format refused).

**Reference.** The design: boards `Mac-StatesSave`, `Mac-StatesOverwrite`, `Mac-StatesLoad`, `Mac-StatesVersionError` and `Mac-StopConfirm`; contract rows C31 and C32; the `Processes` board's file table; the scripted flow "play" in `tools/check.mjs`, which saves, replaces and refuses an older save.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: eight slots per game, keyed by the disc's serial] The design's decision; a PS-EXE with no serial keys by its file's SHA-1, worked out as 5c fingerprints the BIOS and kept in `library.json` (5d) as a defaulted field.
- [default: no automatic save on Stop; Stop asks, and offers Save First…] The design's decision.

**Guardrail(s).** View-model tests over a fake session and store for each state; a preview per board's state.

**Acceptance criteria:**
- [ ] The save and load sheets, the replace and load confirmations and the older-format refusal match their boards, with ⌘S and ⌘L.
- [ ] A state saved, the app quit and relaunched, and the state loaded, resumes the game where it was.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 5, gated on 6g and 5g.
