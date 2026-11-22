# Sound settings

**What / why.** With sound crossing the interface (6i), the design adds an Audio tab to Settings: volume (with its percentage), "Mute when iStation isn't the active app", and the output, which follows the Mac's sound output. Until then the tab is absent, since there is nothing to set.

**Core constraint(s).**
- View-models import no UI toolkit; the audio engine is an injected service.
- Settings persist with defaults.

**Seam + files.**
- Presentation `settings`: the Audio tab and its view-model over the audio service (6i).
- Tests: `tests/presentation/settings/` (defaults, volume persisted, mute applied when the app resigns active).

**Reference.** The design: board `Mac-SettingsAudio`; contract row C26.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: volume 80%, muted when inactive] The design's defaults.

**Guardrail(s).** View-model tests for each setting; a preview matching the board.

**Acceptance criteria:**
- [ ] Settings › Audio matches `Mac-SettingsAudio`, and its settings act on the sound at once.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 5, gated on 6i and 5e.
