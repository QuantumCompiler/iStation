---
name: istation-maintenance-update-release
description: Advance or correct iStation's live version at a release boundary — check the release is actually done (its backlog table empty), then sweep every carrier of the version number (the release branch, CFBundleShortVersionString in scripts/build-app.sh, ROADMAP, CLAUDE.md, CI) so code, CI and docs agree, and prepare the merge into stable and the tag for the user. Use when the user says "cut the release", "release v0.0.1", "bump to v0.1.0", "we're done with this version", "start the next version", or "the version number is wrong".
---

# Update the release — iStation

The release model (the user's call, 2026-10-31): each version is built on its own branch `v<x.y.z>`; when its backlog table is empty it is merged into `stable` and tagged `v<x.y.z>`. **Tagging, merging into `stable`, pushing and publishing are the user's** — this skill prepares them and never does them without the user's explicit say.

## 1. Ground

- The live branch: `git branch --show-current` (a `v<x.y.z>` branch).
- The carriers of the live number:
  - the branch name;
  - `CFBundleShortVersionString` (and `CFBundleVersion`) in `src/istation/scripts/build-app.sh`;
  - [ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md)'s "In progress" heading and its Version scheme line;
  - [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md)'s Versioning section ("`v0.0.1` today") and the root `CLAUDE.md` ("today `v0.0.1`");
  - `.github/workflows/ci.yml` if it names a branch.
- Search for any other occurrence: `grep -rn "0\.0\.1" --exclude-dir=.build --exclude-dir=.git .`

## 2. Gate: is the release actually done?

The version's table in [the backlog index](../../../documentation/istation/backlog/README.md) is empty (every item shipped, or moved with `/istation-backlog-swap-item` by the user's decision), its ROADMAP gate line is ticked, and `/istation-maintenance-update-documents` has run clean. If not, report what remains and stop.

## 3. Sweep the carriers

For a release: the version's table retired from the index; ROADMAP's section moved from "In progress" to shipped (ticked, linked to its milestones) and the next version made "In progress"; MILESTONES' entries reference the version. For the next version: `CFBundleShortVersionString` set and `CFBundleVersion` incremented; CLAUDE.md's and the root CLAUDE.md's "today" updated. For a correction: every carrier made to agree.

## 4. Validate

- `python3 scripts/validate_docs.py documentation` (from the repository root).
- `cd src/istation && swift build --explicit-target-dependency-import-check=error && swift test`
- `cd src/istation && ./scripts/build-app.sh` builds, and `defaults read "$PWD/build/iStation.app/Contents/Info.plist" CFBundleShortVersionString` prints the new number.

## 5. Prepare, then hand over

Give the user the exact commands, each in its own block, for what is theirs to run: commit the sweep; merge the release branch into `stable`; tag `v<x.y.z>`; push the branch and the tag; create the next `v<next>` branch. Report what was swept, the validation results, and those commands.
