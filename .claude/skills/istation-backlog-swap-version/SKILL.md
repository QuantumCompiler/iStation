---
name: istation-backlog-swap-version
description: Slide iStation's queued releases by one version — insert a new version ahead of the queue (bumping later versions, their backlog directories and every reference up) or collapse a vacated one — with an ordered, word-bounded scripted replace plus the judgment edits a script can't make; the skill resolves which application's queue is meant and asks when it cannot. Use when the user says "insert a v0.2.0 before PS1 games boot", "bump everything after v0.2.0", "we're skipping v0.3.0", "renumber the releases", or "add a patch release ahead of the queue".
---

# Swap versions — iStation

The version scheme is one version per roadmap phase (the Version scheme line of `lib/documentation/assistant/<app>/ROADMAP.md`); the live version is the release branch, and `lib/release/VERSION` names it. Inserting a release ahead of queued ones — or removing a vacated one — slides every version at and above it by one: ROADMAP's sections, the backlog's version tables and directories, and every reference. Track ids do not move: a track keeps its number when its release moves. Versions are identities and a renumber is a deliberate act, so **this skill runs only on the user's explicit instruction**, and the result records it, dated, as the user's call.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.1.0`, `v0.2.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Ground in the live state first

1. Read ROADMAP, the index (`lib/documentation/backlog/<app>/README.md`), the repo-wide [Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning) section, the live branch (`git branch --show-current`), `lib/release/VERSION` and `git status` — which items are 🚧, whether recent ships landed, and that the tree is committed enough for `git mv`.
2. **The live, in-progress version is never renumbered without the user saying so explicitly.** If they do, its carriers (`lib/release/VERSION` first, the branch, `MARKETING_VERSION`, ROADMAP's "In progress" heading) are `/istation-maintenance-update-release`'s correction, not this script's.
3. **Nothing released is renumbered**: no affected version has a published tag (`git ls-remote --tags origin 'v*'`: the remote's tags, never only the local ones).
4. **Survey every reference before replacing any**: `grep -rln` the affected range (`v0\.[2-4]\.0`, say) across `lib/documentation/`, the root `CLAUDE.md` and `README.md`, and `.claude/skills/`. List the files; drop the hits that are only examples — the skills' trigger phrases name versions as samples, not references.
5. **Removal direction only:** the vacated table is already empty — its items shipped, cancelled or moved with `/istation-backlog-swap-item` — before this runs; if it isn't, stop and say so.

## 2. Confirm the mapping

With the user, one line per version ("v0.2.0 → v0.3.0, v0.3.0 → v0.4.0, …; new v0.2.0: <theme>"), before anything moves.

## 3. Move the directories — order prevents collisions

- **Insert** (versions slide up): highest first — `git mv lib/documentation/backlog/<app>/v0.4.0 lib/documentation/backlog/<app>/v0.5.0`, then 0.3.0 → 0.4.0, and down. The new version's directory comes with its first item (`/istation-backlog-create-item`), not here.
- **Remove** (versions slide down): the vacated directory is removed first (git keeps no empty one), then lowest first — `git mv …/v0.3.0 …/v0.2.0`, then 0.4.0 → 0.3.0, and up.
- The OS folders' version directories (`<app>/macos/v<x.y.z>/`, `<app>/ios/v<x.y.z>/`) move in the same order.

## 4. The scripted replace — ordered, word-bounded, case-sensitive

One script over the surveyed files, applying replacements in the same order as the moves (descending when bumping up, ascending when collapsing), so a bumped name is never bumped twice: `v0\.3\.0\b` → `v0.4.0` before `v0\.2\.0\b` → `v0.3.0`. Dots escaped and `\b` closing it, so `v0.2.0` never matches inside `v0.2.01`; it also rewrites every link path (`v0.2.0/<file>.md`), matching the directory moves.

- **No pattern touches an id, a bare number or a date**: track numbers don't move with their version (ids are identities), so nothing risks the day in `2026-11-14`.
- **Left out of the pass and read by hand after**: MILESTONES and every dated **Decisions made** entry. History keeps the version it was made under; only a forward-looking reference there (a pending item's earmark, a shipped spike's pending split) is bumped, as an exact string.

## 5. The judgment edits

- Prose that names a version's theme ("PS1 games boot"), and any narrative the renumber makes false — re-read after the pass and rewritten to stay true.
- The repo-wide [Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning) section's list and ROADMAP's Version scheme line.
- ROADMAP: the new release's section and theme paragraph under "Planned" (or the removed one deleted); the pass already bumped the surviving headings and links.
- The index: the new version's table at its release-order position (nearest release first), with its preamble — or the vacated one removed. Every other table keeps its rows: a swap renumbers, it never reorders.
- **Record the renumber itself**, dated, in the new (or removed) table's preamble: the former versions and what they became, the user's call.
- SPEC usually needs only what the script did (a targeted version in a scope line): read its diff and confirm it is exactly that.

## 6. Validate

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean: each row's Version cell matches its directory, rows ↔ documents both ways, every 🔒 gate names a pending id, every relative link resolves.
- Stray-reference greps for the old directory paths and version strings: zero outside history.
- If an Edit fails because a parallel session touched the file, re-read the live region and re-anchor — never force the stale version over it.

## 7. Commit, push and report

- **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user.
- **Report** the version mapping, the directories moved, how many files the scripted pass touched, every hand edit (the rewritten narratives and the recorded renumber especially), what changed in MILESTONES and SPEC and why only that, and the validation results. If an insert's new table has no documents yet, say so — authoring them is `/istation-backlog-create-item`'s.
