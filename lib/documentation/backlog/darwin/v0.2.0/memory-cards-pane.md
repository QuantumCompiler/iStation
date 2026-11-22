# Memory cards

**What / why.** With cards crossing the interface (6f), the design adds Memory Cards to the sidebar (⌘5):
- **The pane:** a list of cards with their blocks used, and a card's details: who uses it, blocks, size, last written, file. Duplicate, Show in Finder and Move to Trash… sit beside them.
- **Empty state:** "No memory cards yet".
- **Settings › Memory Cards:** each game gets its own card, made the first time it saves, or all games share two cards. The tab also shows the folder.
- **Game info:** shows a game's card.

Move to Trash confirms, with `FileManager.trashItem(at:)` and the file under Details, and can be undone from the Trash in the Finder.

**Core constraint(s).**
- The least destructive option: a card goes to the Trash, never an outright delete.
- Settings persist with defaults; the card files are the console's own format (6f).
- View-models import no UI toolkit; file operations are an injected service.

**Seam + files.**
- Presentation, new place `memorycards`: the pane's view-model over a card store (list, duplicate, trash) and the directory reader (6f); views and previews per state.
- Presentation `settings`: the Memory Cards tab.
- Presentation `library`: Game info's memory card fact.
- The app side: cards in `…/Application Support/iStation/Memory Cards/`, inserted by the session at power-on per the policy.
- Tests: `tests/presentation/memorycards/` (list, empty, duplicate, trash confirming first), settings defaults.

**Reference.** The design: boards `Mac-Cards`, `Mac-CardsEmpty`, `Mac-CardDelete` and `Mac-SettingsCards`; contract rows C33 and C34; the `Processes` board's file table; the scripted flow "memory cards" in `tools/check.mjs`.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: each game gets its own card, made the first time it saves; sharing two cards is the setting's other choice] The design's decision.
- [default: the iPhone has no Trash, so the iPhone's delete says it can't be undone] That is 5n's to draw.

**Guardrail(s).** View-model tests for each state and action over a fake store; a preview per board's state.

**Acceptance criteria:**
- [ ] The pane, its empty state, the Trash confirmation and Settings › Memory Cards match their boards, with ⌘5.
- [ ] A game's saves survive quitting and relaunching the app.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.2.0, track 5, gated on 6f, 5e and 5d.
