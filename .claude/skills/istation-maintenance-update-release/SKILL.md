---
name: istation-maintenance-update-release
description: Advance or correct iStation's live version at a release boundary — check the release is actually done (its backlog table empty), then sweep the version's carriers (lib/release/VERSION first, then the release branch, MARKETING_VERSION in lib/src/darwin/apps/Config/Version.xcconfig, ROADMAP, CLAUDE.md) so code, CI and docs agree, and prepare the pull request into stable whose merge is the release. Use when the user says "cut the release", "release v0.0.1", "bump to v0.1.0", "we're done with this version", "start the next version", or "the version number is wrong".
---

# Update the release — iStation

The release model: each version is built on its own branch `v<x.y.z>` (the user's call, 2026-10-31); `lib/release/VERSION` is the release and the only thing that names one, and **the merge into `stable` is the release**: once a pull request into `stable` merges, CI's `tag and release` job tags the merge commit `v<VERSION>` and publishes a GitHub release of its source (the user's call, 2026-11-14). **Opening and merging that pull request are the user's**, and so is any App Store submission — this skill prepares them and never does them without the user's explicit say.

## 1. Ground

- The live branch: `git branch --show-current` (a `v<x.y.z>` branch).
- The carriers of the live number:
  - **`lib/release/VERSION`** — the release; sweep it first, everything else follows it;
  - the branch name (`lib/scripts/version-check.sh` fails a release branch named for another version);
  - `MARKETING_VERSION` in `lib/src/darwin/apps/Config/Version.xcconfig`, written from `VERSION` by `scripts/build.sh` (and `CURRENT_PROJECT_VERSION`, by hand);
  - [ROADMAP.md](../../../lib/documentation/assistant/darwin/ROADMAP.md)'s "In progress" heading and its Version scheme line;
  - [CLAUDE.md](../../../lib/documentation/assistant/darwin/CLAUDE.md)'s Versioning section ("`v0.0.1` today") and the root `CLAUDE.md` ("today `v0.0.1`");
  - `.github/workflows/ci.yml` if it names a branch.
- `ArchitectureTests` (`theVersionFollowsTheRelease`) fails while `VERSION`, `MARKETING_VERSION` and ROADMAP's "In progress" heading disagree.
- Search for any other occurrence: `grep -rn "0\.0\.1" --exclude-dir=.build --exclude-dir=.git .`

## 2. Gate: is the release actually done?

The version's table in [the backlog index](../../../lib/documentation/backlog/darwin/README.md) is empty (every item shipped, or moved with `/istation-backlog-swap-item` by the user's decision), its ROADMAP gate line is ticked, and `/istation-maintenance-update-documents` has run clean. If not, report what remains and stop.

## 3. Sweep the carriers

For a release: the version's table retired from the index; ROADMAP's section moved from "In progress" to shipped (ticked, linked to its milestones) and the next version made "In progress"; MILESTONES' entries reference the version. For the next version: `CFBundleShortVersionString` set and `CFBundleVersion` incremented; CLAUDE.md's and the root CLAUDE.md's "today" updated. For a correction: every carrier made to agree.

## 4. Validate

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root).
- `cd lib/src/darwin && swift build --explicit-target-dependency-import-check=error && swift test`
- `lib/scripts/version-check.sh` (from the repository root): it says what merging into `stable` would publish, and fails if the release is already out or the branch disagrees.
- `cd lib/src/darwin && ./scripts/archive-appstore.sh macOS` archives, and `defaults read "$PWD/build/macOS/iStation.xcarchive/Products/Applications/iStation.app/Contents/Info.plist" CFBundleShortVersionString` prints the new number.

## 5. Prepare, then hand over

**Commit and push the sweep yourself** (CLAUDE.md → Committing and pushing): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers — then `git push origin v<x.y.z>`. Then give the user the exact commands, each in its own block, for what is theirs to run: open the pull request from the release branch into `stable` (`gh pr create --base stable --head v<x.y.z>`), then merge it once CI passes — the merge is the release, and CI tags and publishes it (`lib/scripts/release-from-pr.sh <pr>` rehearses that from a checkout); then create the next `v<next>` branch, its first commit bumping `lib/release/VERSION`. Report what was swept, the validation results, and those commands.
