---
name: istation-maintenance-summarize-pull-request
description: Draft an iStation pull request description from evidence — the branch's diff, its MILESTONES entries, the backlog documents it deleted, and the decisions recorded on it — with Summary, items closed, decisions, docs updated, verification actually run, review notes, before-merging steps and open questions; the branch decides which application's docs are read, and the skill asks when it cannot tell. Use when the user says "write the PR description", "summarize this branch for a pull request", "draft the PR", or "what goes in the PR for v0.0.1?".
---

# Summarize a pull request — iStation

A PR description written from evidence, delivered as text for the user to paste. The pull request is the release branch's into `stable`, and its merge is the release. The diff largely narrates itself — a deleted backlog document plus a new MILESTONES entry *is* a shipped item — so the description is assembled from that record, never from memory of the session. Opening the PR is the user's, unless they ask.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Gather the evidence

**The docs are reconciled first**: if `/istation-maintenance-update-documents` hasn't run on this branch, run it — a description of stale docs is stale. **The branch decides the scope**: every application its diff touched, each from its own docs; the repo-wide machinery (`lib/release/VERSION`, the pipelines) is described once ([Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning)).

After `git fetch origin stable` (a local `stable` can lag):

```bash
git log --oneline origin/stable..HEAD
git diff --stat origin/stable...HEAD
git status -sb
```

Warn if uncommitted work, or commits not yet on `origin/v<x.y.z>`, would be missing from the PR. Then the deltas that carry the narrative:

- **Shipped** — backlog documents deleted on the branch, asked of the log since an item created and shipped there leaves no net diff, and with no pathspec, since the docs may have moved since (`git log --diff-filter=D --name-only --format= origin/stable..HEAD | grep '/backlog/' | sort -u`), each matched to its new entry in `lib/documentation/assistant/<app>/MILESTONES.md`: its goal and acceptance criteria. A deleted document with no entry was cancelled, not shipped.
- **Advanced** — rows still 🚧 in `lib/documentation/backlog/<app>/README.md`: the state each is left in. A release merges when its table is empty, so each is a **Before merging** line.
- **Decisions** — new dated lines in the item documents' Decisions made (exercised `[default: …]` calls included), ADRs (`lib/documentation/adrs/<app>/`), SPEC and ROADMAP (`lib/documentation/assistant/<app>/ROADMAP.md`, its ticks the release-level framing); changed contracts under `lib/documentation/reference/<app>/`.
- **The implementation surface** — new and changed files under `lib/src/darwin/`, `lib/scripts/`, `lib/release/VERSION` and `.claude/skills/`. A job added, removed or renamed under `.github/workflows/` means the required checks must follow it (`lib/documentation/assistant/<app>/DEVELOPER.md` → **Changing the pipeline**).
- **Every release PR, whatever changed** — `lib/scripts/required-checks.py --verify` (read-only; needs `gh` signed in) and `lib/scripts/version-check.sh` (what merging would publish); carry what each printed under **Before merging**. Never say the checks are required until `--verify` has listed them. Once the PR exists, `lib/scripts/release-from-pr.sh <N>` rehearses the release (`--publish` is CI's).

## 2. Verify, don't claim

From the repository root, run `lib/scripts/pr-ci.sh` — CI's jobs on the test merge into `stable`, the checklist's bar before a pull request (`lib/documentation/assistant/<app>/CLAUDE.md` → Implementing a Feature) — or, where it can't run, its parts: `lib/scripts/cicd.sh --test` (the strict build and `swift test`, with `ArchitectureTests`) and `python3 lib/scripts/validate_docs.py lib/documentation`. Report the actual results; a command not run is listed as not run.

Runs with the user's BIOS or games are the user's: report them as the user did, or, where the user gave the agent the files' paths to run, name each file only by its size and hash. No Sony file is attached, linked or committed for the PR.

## 3. Write the description

Omit empty sections. A reviewer who knows nothing of this session should understand the branch from the description alone.

```markdown
## Summary
<Two or three sentences: what the branch delivers and why.>

## Backlog items
- **Shipped:** <id> — <its goal>; acceptance criteria met (MILESTONES.md → <milestone>).
- **Advanced:** <id> — <the state it's left in>.

## Decisions made on this branch
- <date> — <decision, whose call, where it's recorded>.

## Documentation
<Per document, one line each.>

## Verification
<Each command and its result; any run the user made (an emulator, a BIOS, a game), as they reported it.>

## Review notes
<Where to look first; the riskiest change; anything touching the invariants — the layer law, shipped-code provenance and GPL emulators as black boxes, Sony's files, tools only in personal builds, hot-path types, the user's data staying readable — and each deliberate divergence from ProjectPSX or Play!.>

## Before merging
<What CI doesn't do: `required-checks.py --verify`'s and `version-check.sh`'s answers; the release's table empty and its version swept by `/istation-maintenance-update-release`; when a job changed or nothing is required, `lib/scripts/required-checks.py --pr <this PR> --apply` once this PR's run passes — the user's to run.>

## Open questions
<Any [user] call still open, or deliberately deferred.>
```

Suggest a **title** in the commits' one-line form: `v<x.y.z> : Title Case Summary`. End the description with the session's pull-request attribution line.

## 4. Deliver

Write the description to `pr-description-v<x.y.z>.md` in the session's scratchpad (never the repository), then present it in full as text, the final output. This skill itself changes no file in the repository and commits nothing; the docs pass §1 may run commits and pushes its own changes before the description is drafted ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)).

**Do not open the pull request** unless the user explicitly asks: its target is `stable`, and opening and merging it are the user's ([Release and Install](../../../lib/documentation/assistant/darwin/CLAUDE.md#release-and-install)). If they ask, with nothing ahead of `origin/v<x.y.z>`: `gh pr create --base stable --head v<x.y.z> --title "<title>" --body-file <draft>`, the body verbatim from the scratchpad. Never a pull request into `stable` mid-release, whatever Superpowers' `finishing-a-development-branch` offers: that pull request is the release, prepared at the boundary ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)).
