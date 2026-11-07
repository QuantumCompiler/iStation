---
name: istation-backlog-swap-version
description: Slide iStation's queued releases by one version — insert a new version ahead of the queue (bumping later versions, their backlog directories, track ids and every reference up) or collapse a vacated one — with an ordered, word-bounded scripted replace plus the judgment edits a script can't make. Use when the user says "insert a v0.1.0 before covers", "bump everything after v0.2.0", "we're skipping v0.3.0", "renumber the releases", or "add a patch release ahead of the queue".
---

# Swap versions — iStation

The version scheme is one version per roadmap phase ([ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md)); the live version is the current release branch. Renumbering touches ROADMAP's sections, the backlog's version tables and directories, release-item ids, and every reference.

1. **Ground.** Read ROADMAP, [the index](../../../documentation/istation/backlog/README.md), [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md)'s Versioning section, and the live branch (`git branch --show-current`). The live, in-progress version is never renumbered without the user saying so explicitly.
2. **Confirm the mapping** with the user in one line per version ("v0.1.0 → v0.2.0, v0.2.0 → v0.3.0, …; new v0.1.0: <theme>").
3. **Move directories in the order that prevents collisions** — highest first when bumping up, lowest first when collapsing down — each with `git mv backlog/v<old>/ backlog/v<new>/`.
4. **One ordered, word-bounded, case-sensitive scripted replace** across `documentation/`, `CLAUDE.md`, `README.md` and `.claude/skills/`, applied in the same order as the moves, so `v0.1.0` never matches inside `v0.1.0x` and a bumped name is never bumped twice. Track numbers move with their version only if the house says so (it does not: ids are identities; a track keeps its number when its release moves).
5. **The judgment edits** a script can't make: prose that names a version's theme ("the CHD release"), the Versioning section's list, the new version's ROADMAP section and theme paragraph, the index's table order (nearest release first). **Dated decisions and MILESTONES entries stay history**: they keep the version they were made under.
6. **Validate**: `python3 scripts/validate_docs.py documentation` (from the repository root) is clean; a search finds no stale version string outside history.
7. **Commit and push** (CLAUDE.md → Committing and pushing): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers — then `git push origin v<x.y.z>`.
8. **Report** the mapping, the directories moved, and every file touched.
