---
name: istation-maintenance-update-documents
description: The pre-merge documentation reconciliation for iStation — the branch decides which application's docs are walked, and the skill asks when the user's scope and the diff disagree — scope from the branch's diff, walk every document the diff touched (backlog, MILESTONES, ROADMAP, CLAUDE.md, DEVELOPER.md, layer cards, ADRs, reference, SPEC, skills, the pipeline) against the code, fix the drift, validate mechanically, commit and push, and report what still needs the user. Use before opening a pull request or merging a release branch, or when the user says "update the docs", "reconcile the documentation", "docs pass", "make the docs match the code", or "is the backlog up to date?".
---

# Update the documents — iStation

The docs are the source of truth, so before a merge they must say what the code now does: a pull request whose docs lag its code ships drift the next agent will faithfully build on. Audit claims about **changed areas only** — no drive-by rewrites; small diffs review better.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Scope from the diff

After `git fetch origin stable` (a local `stable` can lag): `git diff --stat origin/stable...HEAD` plus `git status` (uncommitted work counts). List the modules, contracts and documents touched. **The diff decides the scope**: every application it touched, each walked against its own docs (an OS folder's documents with them); repo-wide process — versioning, CI, the release — is recorded once, in darwin's contributor guide ([Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning), the router's rule), and audited once. A scope the user names that the diff disagrees with is asked about with AskUserQuestion, never guessed.

Where the diff touched a core or a ported file, the audit includes the clean room (ADR 0013, ADR 0014): each ported file's provenance line and notice, its module's `derivedFrom:` in `Package.swift`, and the acknowledgements list (`lib/src/darwin/apps/Acknowledgements.json`). This pass reads iStation's own tree: a claim about an oracle (SwanStation, PCSX2) is checked against iStation's record of it — the reference docs, MILESTONES, its tools under `lib/src/darwin/tools/` — never by opening its source or its build folder. A subagent dispatched for part of the pass (an Explore agent, say) is given these rules in its prompt, the GPL rule first ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)).

## 2. Walk the documents against the diff

In this order. Read `lib/documentation/assistant/<app>/CLAUDE.md` → Documentation and Status first: it is the flow this skill enforces.

1. **Backlog** (`lib/documentation/backlog/<app>/README.md`, the index, and its documents):
   - An item the branch **completed** → its work recorded in MILESTONES, its document **deleted**, its row removed, its track preamble updated. **A completed item still in the backlog is the cardinal violation.**
   - An item the branch **started** → its row 🚧. A **gate it satisfied** → the downstream rows' 🔒 updated.
   - A decision taken while building → a dated entry in that item's **Decisions made**; an exercised `[default: …]` is recorded as a decision.
   - **The in-development version's table, once empty, is retired here** (the index's lifecycle: at the pre-merge docs pass). The version is `lib/release/VERSION`, the branch's name, and the merge into `stable` is the release ([Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning)). Its `### v<x.y.z>` heading, its track preambles and the empty table leave the index; its directory went with its last document; its ids stay in "Ids spent so far", never reused.
   - A table with rows still standing is never retired: report the rows — moving them is `/istation-backlog-swap-item`'s, on the user's word. The standing **Architecture** and **Maintenance** tables are never retired, however empty.
   - The "Ids spent so far" line is current.
2. **MILESTONES** (`lib/documentation/assistant/<app>/MILESTONES.md`): every shipped item has its entry — goal, what was built, trade-offs, how it was verified, decisions consumed — in its lettered milestone, or a new one for a genuinely new area.
3. **ROADMAP** (`lib/documentation/assistant/<app>/ROADMAP.md`): shipped lines ticked and linked to their milestone; "Decisions needed" current; nothing shipped still listed as pending.
4. **CLAUDE.md** (`lib/documentation/assistant/<app>/CLAUDE.md`): the Codebase Map covers every module added, moved or retired (one concern per row — a row that can't be written that way is a split waiting, ADR 0003); Stack & environment still true; a rule earned on this branch promoted to `⚠` once a test locks it; Code Style additions; the checklist.
5. **DEVELOPER.md** (`lib/documentation/assistant/<app>/DEVELOPER.md`): the tree, each changed module's section, the build and test commands as `lib/scripts/cicd.sh` really runs them, the test table, a recipe for any extension point the branch created.
6. **Layer cards** (`lib/src/darwin/source/<layer>/CLAUDE.md`, `lib/src/darwin/tests/<layer>/CLAUDE.md`), **ADR 0002's table**, the `macOS Personal` scheme's test list and each Presentation module's own scheme (ADR 0017; `lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/`) against the `modules` rows in `lib/src/darwin/Package.swift`.
7. **ADRs** (`lib/documentation/adrs/<app>/`): a new standing rule gets a record; a changed one a superseding record (append-only — the old record's Status line is its only edit); each Enforcement section names the real check.
8. **Reference** (`lib/documentation/reference/<app>/`) against the shipped contract: TraceKit's trace formats (`lib/src/darwin/source/data/tracing/`), and any persisted format the apps write.
9. **SPEC** (`lib/documentation/assistant/<app>/SPEC.md`) only if scope, non-goals or principles moved, with a dated note.
10. **The root `README.md` and `CLAUDE.md`**: the README if building, running or installing changed; the root `CLAUDE.md` (the pointer to the router, with the repo-wide rules) if one of those rules or the docs' path moved.
11. **Skills** (`.claude/skills/*/SKILL.md`) and CLAUDE.md's list of them: any path or process step the branch moved or renamed. Each still opens with the "Which application?" ladder and names the docs as `lib/documentation/<kind>/<app>/` ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle) → Writing a skill).
12. **The pipeline**, if the diff touches `.github/` or `lib/scripts/`: walk `lib/documentation/assistant/<app>/DEVELOPER.md` → Changing the pipeline against it — every job builds through `lib/scripts/cicd.sh`, `lib/scripts/changed.sh` declares anything new a pipeline is built from, `lib/scripts/pr-ci.sh` mirrors every pull-request job, and no required job has a job-level `if:`. If a job's name or set changed, the report says so: once the pull request's run has passed, `lib/scripts/required-checks.py --pr <N>` proposes the checks (it reads, never writes; run it then if the pull request already exists), and the user runs `--apply`. **On a release pull request, whatever the diff**, run `lib/scripts/required-checks.py --verify` (read-only too) and carry what it printed into the report.

## 3. Validate mechanically

Script it — never eyeball:

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root): every relative link in `lib/documentation/` and in every CLAUDE.md and SKILL.md resolves; every row's document exists, in its table's directory, and every document has its row; ids unique; one status per row; every 🔒 gate a pending id.
- `cd lib/src/darwin && swift build --explicit-target-dependency-import-check=error && swift test` (or `lib/scripts/cicd.sh --test`, which runs both): the layering and layer-context checks — the cards, ADR 0002's table and the schemes against `Package.swift` — the version's carriers, and the check that fails on a disc image, BIOS or game anywhere in the repository.
- What the validator doesn't check, by grep: no version table left empty; every open call tagged `[user]`, `[default: …]` or `(consumed decision)`; no template marker or `_TODO:_` newly introduced unless deliberate.

## 4. Commit and push

([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a push that fails is reported with its error and left for the user. A pass that changed no file commits nothing.

## 5. Report

For the pull request's description: which documents changed and why; which backlog items were completed, started or re-gated; whether the in-development version's table was retired, or why not; the decisions recorded; the validation results; the commit and push. Then, explicitly, what needs the **user**: an unanswered `[user]` call the branch stepped around, a SPEC change made without a recorded decision, a release step (`/istation-maintenance-update-release`), what `required-checks.py --verify` printed, and — when the pipeline's jobs changed — that `lib/scripts/required-checks.py --pr <N> --apply` must run after the pull request's CI passes and before it merges, which is theirs to run. Remind that `lib/scripts/pr-ci.sh` must pass before the pull request is opened.
