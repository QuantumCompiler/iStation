# Development runs on the personal channel — personal builds get their own identity, so they never touch the App Store install

**What / why.** Apogee's rule "Development runs on the dev channel" (the user's call there, 2026-10-31): the installed release is the user's production install, changed only by what a release ships, so its updaters are tested for real; development builds drive their own channel and keep their own settings. Its Apple app found the gap this rule closes (Apogee's M18, measured 2026-10-31): Debug and Release shared one bundle identifier, so a development build read and wrote the installed app's `UserDefaults`. iStation has the same gap today: each app target has **one bundle identifier for both routines** — `local.istation.ios` (`lib/src/darwin/iStation.xcodeproj/project.pbxproj:409`) and `local.istation.macos` (`:472`) — so a personal build and an App Store install share their sandbox container, defaults and imported-file bookmarks. Once the apps import BIOS files and games (v0.2.0), a personal build would read and change the user's real library. This item adopts the rule (the user's call, 2026-11-14, to mimic Apogee's procedure).

**Core constraint(s).** Release builds carry no tools: the App Store routine's identity and entitlements don't change. The user's data stays readable ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5): the App Store app's container is never written by development. Tests and previews never touch the real home. The signing team stays in `Local.xcconfig`.

**Seam + files.** No module.
- `lib/src/darwin/apps/Config/Personal.xcconfig`: `PRODUCT_BUNDLE_IDENTIFIER` with a personal suffix and a display name that says it is the personal build; `AppStore.xcconfig` keeps today's identifiers (or the user's App Store Connect ones from v1.0.0).
- `lib/src/darwin/iStation.xcodeproj`: the identifiers move out of the targets' build settings into the routines' xcconfigs.
- A check (`ArchitectureTests` → project rules): the two routines' identifiers differ for each app.
- CLAUDE.md → Working process: "Development runs on the personal channel" — live passes, smoke tests and "try it" steps use the personal build; the App Store install's container is read-only to development.

**Reference.** Apogee: `lib/documentation/assistant/cli/CLAUDE.md` → "Development runs on the dev channel"; `lib/documentation/assistant/darwin/CLAUDE.md` → its state of play; `backlog/darwin/macos/maintenance/app-dev-channel.md` (M18). In-house: Milestone F (the routines), `Personal.xcconfig`.

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call).
- 2026-11-14: the personal identities are `local.istation.macos.personal` and `local.istation.ios.personal`, displayed as "iStation Personal" (the default, confirmed by the user).
- 2026-11-14: the App Store identifiers stay `local.istation.macos` and `local.istation.ios` until the user's App Store Connect identifiers exist (v1.0.0) (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** The check fails on a planted personal identifier equal to the App Store one; a personal build launched beside an App Store build of the same app keeps separate containers (seen once and recorded in MILESTONES).

**Acceptance criteria:**
- [ ] Each app's personal and App Store routines build with different bundle identifiers — checked.
- [ ] The personal build's name says it is the personal build.
- [ ] CLAUDE.md states the personal-channel rule.

**Scope note.** v0.0.1, track 4; gated on 4b (the project's new place). Out of scope: the import of BIOS files and games itself (v0.2.0), which this protects.
