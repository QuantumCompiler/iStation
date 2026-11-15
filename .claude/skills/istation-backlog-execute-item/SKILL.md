---
name: istation-backlog-execute-item
description: Build one iStation backlog item straight from its document — the skill resolves which application's queue is meant and asks when it cannot — resolve its open calls first, mark it in progress, implement it within the layer law and the invariants, run the tests and checks green, then ship it through the documentation flow (MILESTONES entry, backlog document and row deleted, ROADMAP ticked) with one commit and a push. Use when the user says "Continue", "take the next item", "build 1a", "do M1", "execute the item", "work the backlog", or names an item id or document.
---

# Execute a backlog item — iStation

iStation is built docs-first: every work item has its own document in `lib/documentation/backlog/<app>/`, and an agent builds straight from it. One item, built from its document, then shipped through the docs, committed and pushed. Then stop.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Load the working process

Read `lib/documentation/assistant/<app>/CLAUDE.md` in full — the working process, the invariants, code style, the per-change checklist (the definition of done) and the Documentation and Status flow — then, beside it and as needed, `SPEC.md` (scope, non-goals, principles), `ROADMAP.md` (the release's context and its outstanding `[user]` decisions) and `DEVELOPER.md` (the module reference and recipes). They override anything remembered from earlier sessions.

## 2. Pick

Read the index, `lib/documentation/backlog/<app>/README.md`: lifecycle, document format, the gate convention, the tables in build order.

- A bare "Continue": the **topmost 🟢 row of the earliest version table**. Maintenance and Architecture items are taken by name.
- A named item: verify its gate (a 🔒 row waits on the ids its Status cell names; an item builds on everything shipped plus its own gate chain); if unmet, say so and stop.
- **Re-read the live index** first: parallel sessions take items. A 🚧 row is someone else's.

## 3. Read the whole document

It is the working spec: What / why, Core constraints, Seam + files, Reference, Decisions made, Open calls, Guardrails, Acceptance criteria, Scope note.

- **Split first** (in its Scope note or row): nothing is built. It is groomed into its sub-documents (the split confirmed with the user, each to create-item's bar), they join the index and ROADMAP, the validator is clean, the split is committed and pushed as §6 says, and you stop.
- **Reference**: read the precedents and prior art it names before designing — for a core, the ProjectPSX or Play! files and the public documentation it cites, never a GPL emulator's source.

## 4. Resolve the open calls before any code

- Every `[user]` call blocks the build: asked with AskUserQuestion, in plain language, the document's recommendation first, and waited for. Nothing is built until every one is answered; each answer is recorded under **Decisions made** as "YYYY-MM-DD: <decision> (the user's call)".
- Every `[default: …]`: taken and recorded under **Decisions made** as "YYYY-MM-DD: <decision> (the default, taken)" — veto-able later.
- `(consumed decision)`: not reopened.
- Rewrite every constraint, seam line, guardrail and criterion that branched on an answer, in the document, before building.

## 5. Build

- **The clean room** (ADR 0013): shipped code comes only from ProjectPSX (MIT), Play! (BSD), iStation's own code and public documentation, every ported file naming its source and keeping its notice; a GPL emulator is only built unmodified and run. A session that has read one's source writes no core code and dispatches no core work: for a core item, say so and stop, before marking the row.
- Mark the row 🚧 (and save the index) before the first code change.
- One item. Honor its constraints and every `⚠` invariant.
- **Superpowers at this step** ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle), the user's call, 2026-11-14). The document is the approved design, so `superpowers:brainstorming` does not run again, and the request to build is the approval. `superpowers:test-driven-development` for each change; for an item of several tasks, `superpowers:writing-plans`, then `superpowers:subagent-driven-development` (or `executing-plans` where no subagent tool exists), in a worktree from `superpowers:using-git-worktrees`. Its defaults give way:
  - The plan restates nothing the document decides, and it is a session-only file in the scratchpad (with none, a `mktemp -d` directory outside the repository), **never committed**. writing-plans' hand-off is self-review against the document, with no wait.
  - The plan's `Spec:` line is this document's path. The worktree is consented to (using-git-worktrees doesn't ask): made with EnterWorktree under `.claude/worktrees/`, while on the release branch (`worktree.baseRef` is `head`). Before the first task, `git merge-base --is-ancestor v<x.y.z> HEAD`, and the baseline `lib/scripts/cicd.sh --test` passes — a failing one stops the build. Task commits stay on its branch, with any message: the squash replaces them. Where no worktree can be made, the plan's Commit steps are dropped and the item lands as one uncommitted change.
  - A subagent given core work (porting, a core's tests, reviewing a core) is told the GPL rule in its prompt — the clean room above, naming SwanStation, PCSX2, DuckStation, PCSX-Redux and its OpenBIOS, Beetle PSX/Mednafen, PCSX-ReARMed, Avocado and RPCS3 as never opened, read or copied — and is pointed at no oracle's build folder.
  - Every `Ruling:` (the ledger's, gathered in the final message's "Rulings I made") is carried, dated, into the item's MILESTONES entry with its decisions consumed — the ship deletes the document that holds **Decisions made**; an item that stops keeps them there as dated entries. A ruling that would reverse a `[user]` decision is not made: it stops the build (a group run takes its stopped-item path).
  - Before calling it done, `superpowers:verification-before-completion` and `superpowers:requesting-code-review`. The review's range is `git merge-base v<x.y.z> HEAD`..`HEAD` for a worktree item, or the working tree against `HEAD` (untracked files included) for an uncommitted one — never a range from `stable`.
- **The layer law**: a new module brings its `Module(…)` row in `lib/src/darwin/Package.swift`, its source and test directories, its layer card's Modules line, its ADR 0002 table row, its test target in the `macOS Personal` scheme's tests (`lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/`) and its Codebase Map row — a new Presentation place also its own shared scheme (ADR 0017) — in the same change.
- **Live runs use the personal build** ([Development runs on the personal channel](../../../lib/documentation/assistant/darwin/CLAUDE.md#development-runs-on-the-personal-channel)): a smoke test or a "try it" step runs "iStation Personal", never the App Store build against the user's data.
- **Hermetic tests per its guardrails**: files only in a `Sandbox`, never the real home, Launch Services, a real emulator, a real game or a BIOS.
- **Sony's files stay the user's**: no BIOS, disc image or game is committed or copied into the repository. A run with the user's BIOS, games or signing identity is prepared by you and run by the user; record what they report. If they tell you to make it and give the paths, each file is passed by path and named in reports only by its size and hash. Running the references and oracles on open content (homebrew, the open suites, programs built in code) is yours, under `lib/src/darwin/tools/` or in the scratchpad — a GPL oracle only unmodified.
- An item that changes the pipeline (a job, a workflow, what a pipeline is built from) follows DEVELOPER.md → Changing the pipeline (`lib/documentation/assistant/<app>/DEVELOPER.md#changing-the-pipeline`). `lib/scripts/required-checks.py --pr <N> --apply` changes the repository's settings: say it is needed, and leave it to the user. `--verify` is read-only: run it and report what it printed when the item touches the pipeline or is the last in its release's table; anything missing is a "needs the user" line.
- Done means green, with the real commands (`lib/scripts/cicd.sh --test` runs the first two):
  - `cd lib/src/darwin && swift build --explicit-target-dependency-import-check=error`
  - `cd lib/src/darwin && swift test` (includes `ArchitectureTests`)
  - `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root)
- Changing repository settings, CI secrets, or anything else outward-facing (publishing, signing) is asked first. Force-pushing, and pushing `stable` or a tag, are never done; pushing the release branch when the item ships is routine (§6).

## 6. Ship — the documentation and status flow, in the same change

When the acceptance criteria pass, each checked by running it:

1. **MILESTONES.md** (`lib/documentation/assistant/<app>/MILESTONES.md`) extended — folded into the matching milestone, or a new lettered one: goal, what was built (modules and files), trade-offs, how it was verified (the commands and their results), decisions consumed.
2. **The backlog document and its index row deleted**; any item gated on it updated (🔒 → 🟢 when its gate empties). A version table that empties is retired at the pre-merge docs pass.
3. **ROADMAP.md** line ticked, linking the milestone.
4. **Codebase Map, DEVELOPER.md, layer cards, ADR 0002's table** updated for any module change; `lib/documentation/reference/<app>/` for a changed contract (a trace format, a persisted format the apps write).
5. **SPEC.md** only on a scope change, with a dated note.
6. A new standing rule → an ADR in `lib/documentation/adrs/<app>/`; promoted to a `⚠` section once enforced.
7. The validator clean again.

*Superpowers' `finishing-a-development-branch`*: its menu gives way to one landing, once what it would have shown is settled — a residual Critical or Important finding from the final review stops the landing; deferred minors go in the report, and a self-review is said there. ExitWorktree with `action: "keep"` returns to the main checkout, still on the release branch, with no checkout or pull. There, undo the index's 🚧 edit (the item branch carries the row's deletion, and the merge won't overwrite local changes), then `git merge --squash <item-branch>` — the docs flow above lands in the same change — and `lib/scripts/cicd.sh --test` on the squashed result (a failure stops the landing, the worktree and branch kept). After the commit and push below, `git worktree remove .claude/worktrees/<name>` and `git branch -D <item-branch>`; never ExitWorktree's `remove`, which refuses a squash-landed branch without discarding it. The item branch is never pushed.

**Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user. **Never a merge into `stable` or a pull request into it mid-release**: that merge is the release, prepared at the boundary by `/istation-maintenance-update-release` and `/istation-maintenance-summarize-pull-request`, and opened and merged by the user.

## 7. Stop

Report what was built, how it was verified, the docs updated, the commit and its push, and anything left for the user. When the item was the last in its release's table, say the release is next (`/istation-maintenance-update-documents`, then `/istation-maintenance-update-release`, with `lib/scripts/pr-ci.sh` before its pull request). Wait to be asked to continue: a bare "Continue" re-reads CLAUDE.md, then takes the topmost claimable item.
