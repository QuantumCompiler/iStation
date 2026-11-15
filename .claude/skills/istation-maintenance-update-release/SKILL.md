---
name: istation-maintenance-update-release
description: Advance or correct iStation's live version at a release boundary (the skill resolves which application's table and docs are meant, today darwin's, and asks when it cannot) — check the release is actually done (its backlog table empty), then sweep the version's carriers (lib/release/VERSION first, then the release branch, MARKETING_VERSION in lib/src/darwin/apps/Config/Version.xcconfig, ROADMAP, CLAUDE.md) so code, CI and docs agree, and prepare the pull request into stable whose merge is the release. Use when the user says "cut the release", "release v0.1.0", "bump to v0.2.0", "we're done with this version", "start the next version", or "the version number is wrong".
---

# Update the release — iStation

The release model: each version is built on its own branch `v<x.y.z>` (the user's call, 2026-10-31); `lib/release/VERSION` is the release and the only thing that names one, and **the merge into `stable` is the release**: once a pull request into `stable` merges, CI's `tag and release` job tags the merge commit `v<VERSION>` and publishes a GitHub release of its source (the user's call, 2026-11-14). **Opening and merging that pull request are the user's**, and so is any App Store submission — this skill prepares them and never does them without the user's explicit say.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.1.0`, `v0.2.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Ground

- The live branch: `git branch --show-current` (a `v<x.y.z>` branch).
- The carriers of the live number:
  - **`lib/release/VERSION`** — the release; sweep it first, everything else follows it;
  - the branch name (`lib/scripts/version-check.sh` fails a release branch named for another version);
  - `MARKETING_VERSION` in `lib/src/darwin/apps/Config/Version.xcconfig`, written from `VERSION` by `lib/src/darwin/scripts/build.sh` (and `CURRENT_PROJECT_VERSION`, by hand);
  - `lib/documentation/assistant/<app>/ROADMAP.md`'s "In progress" heading and its Version scheme line;
  - the repo-wide sections of the contributor guide: [Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning) ("`v0.1.0` today"), [Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing) ("today `v0.1.0`") and [Release and Install](../../../lib/documentation/assistant/darwin/CLAUDE.md#release-and-install) ("Today (v0.1.0):"); the root `CLAUDE.md` ("today `v0.1.0`"); and the root `README.md`'s Status ("v0.1.0, …");
  - `.github/workflows/ci.yml` if it names a branch.
- `ArchitectureTests` (`theVersionFollowsTheRelease`) fails while `VERSION`, `MARKETING_VERSION` and ROADMAP's "In progress" heading disagree.
- Search for any other occurrence: `grep -rIn "0\.1\.0" --exclude-dir=.build --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData --exclude-dir=worktrees .` — a tool's own version (`tools/jit-probe/Info.plist`) and "v<x.y.z> item" notes are history, not carriers

## 2. Gate: is the release actually done?

The version's table in the backlog index (`lib/documentation/backlog/<app>/README.md`) is empty (every item shipped, or moved with `/istation-backlog-swap-item` by the user's decision), its ROADMAP gate line is ticked, and `/istation-maintenance-update-documents` has run clean. If not, report what remains and stop.

## 3. Sweep the carriers

For a release: the version's table retired from the index, if the pre-merge docs pass (`/istation-maintenance-update-documents`) hasn't already; ROADMAP's section stays under "In progress", every line ticked and linked to its milestones — `theVersionFollowsTheRelease` holds its heading to `lib/release/VERSION` until the next version starts; MILESTONES' entries reference the version. For the next version, in its branch's first commit: `lib/release/VERSION` bumped first; ROADMAP's shipped section moved out of "In progress" into a `## Shipped` section between it and "Planned" (created with the first release), and the next version's section moved up from "Planned"; then `MARKETING_VERSION` in `Version.xcconfig` follows it (`lib/src/darwin/scripts/build.sh` writes it, or set it by hand to the same number) and `CURRENT_PROJECT_VERSION` is incremented; every "today" in CLAUDE.md and the root CLAUDE.md, and the root `README.md`'s Status, updated. For a correction: every carrier made to agree.

## 4. Validate

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root).
- `cd lib/src/darwin && swift build --explicit-target-dependency-import-check=error && swift test`
- `lib/scripts/version-check.sh` (from the repository root): it says what merging into `stable` would publish, and fails if the release is already out or the branch disagrees.
- `lib/scripts/pr-ci.sh --uncommitted` (from the repository root) passes: CI's pull-request jobs on the test merge into `stable`, the sweep included, before the pull request is opened.
- `cd lib/src/darwin && ./scripts/build.sh appstore macOS && defaults read "$PWD/build/macOS/iStation.xcarchive/Products/Applications/iStation.app/Contents/Info.plist" CFBundleShortVersionString` prints the new number: `build.sh` writes `MARKETING_VERSION` from `lib/release/VERSION`, then archives into `build/macOS/iStation.xcarchive`. Run it with `ISTATION_TEAM_ID` unset, so the archive is not signed for distribution (macOS: ad-hoc, as `archive-appstore.sh` says); signing with the user's team is the user's.

## 5. Prepare, then hand over

**Commit and push the sweep yourself** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag (the tag is CI's, at the merge); a failed push is reported with its error and left for the user. Then give the user the exact commands, each in its own block, for what is theirs to run: open the pull request from the release branch into `stable` (`gh pr create --base stable --head v<x.y.z>`), then merge it once CI passes — the merge is the release, and CI tags and publishes it (`lib/scripts/release-from-pr.sh <pr>` rehearses that from a checkout). Once the merge has published, the next version is this skill's again ("start the next version"): the `v<next>` branch cut from the merged `stable`, its first commit bumping `lib/release/VERSION` and the carriers per §3, pushed with `git push -u origin v<next>`. Report what was swept, the validation results, and those commands.
