# The release in `lib/release/VERSION` — one file names the release, the apps' version follows it, a check guards it

**What / why.** In Apogee, **`lib/release/VERSION` is the release, and the only thing that names one** (its CLI docs' Versioning, 2026-09-25); the first commit on a new release branch bumps it, or the pull request's `version bump` check fails (`lib/scripts/version-check.sh`); and **the merge into `stable` is the release** (2026-09-22): once the pull request merges, CI tags and publishes the version `VERSION` names. iStation names its version in three places that a sweep must keep together — the branch name, `MARKETING_VERSION` in `lib/src/darwin/apps/Config/Version.xcconfig:3` (`0.0.1`), and ROADMAP's "In progress" heading — and the merge, tag and any publishing are the user's to do by hand (CLAUDE.md → Release and Install). This item adopts Apogee's single source (the user's call, 2026-11-14, to mimic Apogee's procedure).

Measured, not guessed (2026-11-14): Apogee's `lib/release/VERSION` holds `0.2.0`; its `lib/scripts/` has `version-check.sh`, `release-from-pr.sh` and `latest-release.sh`. iStation's `/istation-maintenance-update-release` sweeps the branch, `Version.xcconfig`, ROADMAP, CLAUDE.md and CI by hand.

**Core constraint(s).** The apps' version (`MARKETING_VERSION`) can never disagree with the release: it is derived from `VERSION` or checked equal to it. Release builds carry no tools. The commit-and-push rule stands: every commit is `v<x.y.z> : Title Case Summary`, the version in it the branch's. Publishing and anything with the user's signing identity stay the user's.

**Seam + files.** No module.
- `lib/release/VERSION` (`0.0.1`).
- `lib/src/darwin/apps/Config/Version.xcconfig` follows it — written from it by `scripts/build.sh`, or checked equal by a test.
- `lib/scripts/version-check.sh`: fails a pull request into `stable` whose `VERSION` is not newer than the latest release tag, and a release branch whose name disagrees with `VERSION`.
- `ArchitectureTests` or the validator: `VERSION`, `MARKETING_VERSION`, the branch and ROADMAP's heading agree.
- `lib/scripts/release-from-pr.sh` and a job on a merge into `stable`: tag `v<x.y.z>` from `VERSION` and publish a GitHub release of the source — the merge is the release (the user's call, 2026-11-14).
- `/istation-maintenance-update-release`: sweeps `VERSION` first; CLAUDE.md's Versioning and Release sections.

**Reference.** Apogee: `lib/release/VERSION`, `lib/scripts/version-check.sh`, `lib/scripts/release-from-pr.sh`, its CLI docs' Versioning ("two versions, one job each"; "the merge IS the release"). In-house: the update-release skill; CLAUDE.md → Versioning.

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call).
- 2026-11-14: a merge into `stable` is the release, as in Apogee: when a pull request merges, CI tags `v<x.y.z>` from `VERSION` and publishes a GitHub release of the source; App Store submission stays the user's (the user's call).
- 2026-11-14: `scripts/build.sh` writes `MARKETING_VERSION` from `VERSION`, so there is one place to edit, and a test fails if they ever differ (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** `version-check.sh` fails on a planted unbumped `VERSION` against the latest tag, and on a branch name that disagrees; the agreement check fails on a planted `MARKETING_VERSION` that differs.

**Acceptance criteria:**
- [ ] `lib/release/VERSION` names the release; nothing else does by hand.
- [ ] The apps' version always equals it — checked.
- [ ] `version-check.sh` runs in CI on every pull request into `stable`.
- [ ] A merge into `stable` tags the release and publishes its source on GitHub, by CI.
- [ ] The update-release skill and CLAUDE.md describe the new carriers and the merge-is-the-release law.

**Scope note.** v0.0.1, track 4; gated on 4b (the paths). 4d runs the check in CI. Out of scope: App Store submission (v1.0.0), any binary release artifact (iStation's apps ship through the App Stores).
