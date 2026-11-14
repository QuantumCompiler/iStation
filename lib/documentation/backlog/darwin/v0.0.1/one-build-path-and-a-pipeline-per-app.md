# One build path and a pipeline per app — `lib/scripts/cicd.sh`, `changed.sh`, `pr-ci.sh` and `.github/workflows/darwin.yml`, Apogee's way

**What / why.** Apogee has **one build path**: `lib/scripts/cicd.sh --app <app>` is the same command a developer runs and CI runs, calling the app's own `scripts/build.sh`; `lib/scripts/changed.sh <pipeline>` declares once what each pipeline is built from, so a pipeline whose inputs didn't change passes under its required name without building; each application has **its own pipeline** beside the repository's (`.github/workflows/ci.yml`, and `darwin.yml` for the Apple app); `lib/scripts/pr-ci.sh` rehearses CI's jobs locally before a pull request; and `lib/scripts/required-checks.py` keeps the repository's required checks equal to the passing jobs (applying it changes repository settings, so it is the user's to run). iStation has one workflow, `.github/workflows/ci.yml` (on `macos-15`, `working-directory: src/istation`: the strict build, `swift test`, the docs validator), run only for pull requests and merges into `stable` (the user's call, 2026-10-31), and no script that CI and a developer share. This item adopts Apogee's pipeline shape (the user's call, 2026-11-14).

Measured, not guessed (2026-11-14): Apogee's `lib/scripts/` holds 17 scripts, among them `cicd.sh`, `changed.sh`, `pr-ci.sh`, `required-checks.py`, `ci-annotate.sh` and `version-check.sh`; `.github/workflows/darwin.yml` builds the app on GitHub's `xcode-27` image through `cicd.sh --app darwin` and keeps a required job that never carries a job-level `if:` (a skipped required job never passes); `.github/actions/package/action.yml` packages an artifact.

**Core constraint(s).** CI runs only for pull requests and merges into `stable` (the user's call, 2026-10-31) — unchanged. Release builds carry no tools, and CI never signs: the App Store routine is checked for its entitlements, not archived with an identity. Tests stay hermetic: no BIOS, no game, no network in CI. Repository settings (required checks) are the user's to change.

**Seam + files.** No module.
- `lib/scripts/cicd.sh`: `--app darwin` builds; `--test` runs `swift test` and the strict build; `--docs` runs the validator; `--all` everything — the one command CI and developers run.
- `lib/scripts/changed.sh <pipeline>`: what `darwin` is built from (`lib/src/darwin/`, the workflows); documentation-only changes build no app.
- `.github/workflows/ci.yml`: the repository's pipeline — the docs validator, `version-check.sh` (4c), the project rules.
- `.github/workflows/darwin.yml`: the apps' pipeline — `cicd.sh --app darwin --test`, both apps' personal routine built unsigned, the App Store entitlements checked; required jobs without job-level `if:`.
- `lib/scripts/pr-ci.sh`: rehearses both pipelines locally before a pull request; `lib/scripts/required-checks.py` (`--pr <N>`, then `--apply`, the user's).
- CLAUDE.md's checklist (rehearse before a pull request) and Release and Install; DEVELOPER.md's commands.

**Reference.** Apogee: `lib/scripts/{cicd.sh,changed.sh,pr-ci.sh,required-checks.py}`, `.github/workflows/{ci.yml,darwin.yml}` (its header comment: the required-checks rule and the one build path). In-house: `.github/workflows/ci.yml`; Milestone F's routine checks.

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call).
- 2026-11-14: CI runs on the newest Xcode image GitHub offers (Apogee's `xcode-27`) (the default, confirmed by the user).
- 2026-11-14: no packaged artifact until v1.0.0; `.github/actions/package/` waits (the default, confirmed by the user).
- 2026-11-14: required checks are proposed by `required-checks.py --pr <N>` and applied by the user (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** A documentation-only pull request builds no app and passes; a planted failing test fails `darwin.yml` and `pr-ci.sh` alike; `changed.sh darwin` reports "changed" for a planted edit under `lib/src/darwin/` and "unchanged" for one under `lib/documentation/`.

**Acceptance criteria:**
- [ ] `lib/scripts/cicd.sh` is the one build-and-test path, used by CI and named in DEVELOPER.md.
- [ ] `ci.yml` and `darwin.yml` run as described, each required job reporting under its name.
- [ ] `pr-ci.sh` rehearses both pipelines locally.
- [ ] CLAUDE.md's checklist asks for the rehearsal before a pull request.

**Scope note.** v0.0.1, track 4; gated on 4c (the version check it runs). Out of scope: a Linux or Windows pipeline (Apple platforms only), signing and notarization in CI (the user's, v1.0.0).
