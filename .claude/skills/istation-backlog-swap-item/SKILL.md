---
name: istation-backlog-swap-item
description: Move one iStation backlog item between tables — a release table and Maintenance or Architecture, or one version to another — giving it the destination's id and position, moving its document, and fixing every reference across the docs and skills. Use when the user says "move M2 into v0.1.0", "push 1a to v0.1.0", "make this a maintenance item instead", "swap this item to another version", or "reschedule item X".
---

# Swap an item between tables — iStation

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the index is [`backlog/README.md`](../../../documentation/istation/backlog/README.md).

1. **Ground in the live index.** Find the item's row, document and status (a 🚧 item is someone else's — stop). Find every item whose gate names it.
2. **The destination decides the new id and position.** A release table: the track's next letter ever assigned, or the next track number ever used; Maintenance/Architecture: the next `M<n>`/`A<n>`. Ids are never reused: the old id stays spent, and the gap it leaves is not closed (this house does not renumber). Ask for the position if the user hasn't given it.
3. **Move the document** with `git mv` into the destination's directory (`backlog/v<x.y.z>/`, `maintenance/`, `architecture/`), creating the directory with a table's first item.
4. **Fix its row**: removed from the old table, added to the new one in position, with its new id, its Version cell (`v0.1.0`, `maint.`, `arch.`) and its File link; its status re-derived (a gate pointing at a different release may no longer hold).
5. **Fix every reference**, scripted and word-bounded so `M1` never matches `M10`: other items' gates and cross-links (`../maintenance/<file>` style), track preambles, the ROADMAP line (moved to the destination's section), CLAUDE.md, MILESTONES, the ADRs, `reference/`, and the skills under `.claude/skills/`. Its own document's Scope note and a dated Decisions entry ("YYYY-MM-DD: moved from M2 to 1b (the user's call)").
6. **Retire** a version table the move left empty only at the pre-merge docs pass, never the standing tables; update the "Ids spent so far" line.
7. **Validate**: `python3 scripts/validate_docs.py documentation` (from the repository root) is clean.
8. **Report** the old → new id, its new position and status, and every file touched.
