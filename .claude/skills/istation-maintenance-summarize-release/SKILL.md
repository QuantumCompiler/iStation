---
name: istation-maintenance-summarize-release
description: Draft iStation's release notes for one version from evidence — ROADMAP, MILESTONES and the git range — with title and theme, intro, highlights, install, platforms, known limitations and reference, every claim checked. Use when the user says "write the release notes", "draft the notes for v0.1.0", "what's new in this release", or "summarize the release for GitHub".
---

# Summarize a release — iStation

Release notes in the house format, delivered as a draft. Publishing (a GitHub release, the Sparkle appcast) is the user's.

1. **Pin the release and its range.** The version (the release branch, e.g. `v0.1.0`) and the previous tag; the range is `git log --oneline v<previous>..HEAD` (the first release: everything).
2. **Read the previous release notes** (GitHub releases, if any) as exemplars of tone and shape.
3. **Gather the evidence**: the version's [ROADMAP](../../../documentation/istation/assistant/ROADMAP.md) section and its gate; the [MILESTONES](../../../documentation/istation/assistant/MILESTONES.md) entries shipped in the range; the range's commits; the [SPEC](../../../documentation/istation/assistant/SPEC.md)'s Distribution section for install and platforms; the [reference](../../../documentation/istation/reference/README.md) for any changed contract (emulator flags, the library file).
4. **Write**:
   - **Title and theme** — `iStation v<x.y.z> — <the phase's theme>`.
   - **Intro** — two sentences, in plain words for someone who plays games, not someone who builds them.
   - **Highlights** — what a person can now do.
   - **Install** — how to get it (today: build from source with `./scripts/build-app.sh`; from v1.0.0: the notarized `.dmg`), the App Store or the personal build, and which consoles each app plays.
   - **Platforms** — macOS 14+, Apple Silicon.
   - **Known limitations** — from the open Maintenance items and ROADMAP; honest.
   - **Reference** — the licences (iStation's own MIT; ProjectPSX's MIT and Play!'s BSD notices it carries) and the source tag.
   No Sony logos or artwork; describe compatibility only ("plays PS2 games").
5. **Check every claim** against the evidence; drop what can't be backed.
6. **Deliver the draft** as text.
