---
name: istation-backlog-execute-group
description: Execute a whole iStation backlog table (a version like v0.1.0, a track within it, or a named set of Maintenance items; the skill resolves which application is meant and asks when it cannot) unsupervised — read every document first, ask every blocking question up front in one sitting, then build each item serially to execute-item's full bar, committing and pushing once per shipped item, and report per item at the end. Use when the user says "do the whole v0.2.0 table", "execute the group", "build everything in Maintenance", "run the release's items", or "work through the backlog without me".
---

# Execute a group — iStation

The group is one table of the application's index — a version, Maintenance, Architecture — or a named track or set of items in one. This skill builds **every item in it, serially, unsupervised**: the user names the group and walks away. Each item gets `/istation-backlog-execute-item`'s full treatment, the per-item law. What this skill adds is the batch contract: all reading and all questions **up front**, autonomous problem-solving **in the middle**, and **one commit and push per shipped item** at each boundary.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Read everything first, ask everything first

1. Load the working process as `/istation-backlog-execute-item` does: `lib/documentation/assistant/<app>/CLAUDE.md` in full, SPEC, ROADMAP and DEVELOPER as needed, and the live index (`lib/documentation/backlog/<app>/README.md`).
2. **Read every document in the group, and its References, before building anything.** The run takes the table's build order, gates honored. Out of the run from the start, and said: a 🚧 row (someone else's) and anything gated on it; an item whose gate chain leaves the group unshipped; a **split first** item (grooming needs the user); and every core item, if this session has read a GPL emulator's source — such a session writes no core code and dispatches no core work (ADR 0013 §3).
3. **Ask every blocking question now**, in one sitting — mid-run there is no user:
   - Every `[user]` call, one AskUserQuestion each, in plain language, the document's recommendation first. One left unanswered drops only its item and its dependents, announced in the plan, not discovered at item seven.
   - Every `[default: …]` call, confirm-or-veto, up to four per round.
   - An item that needs a run only the user can make (their games, BIOS files, signing identity): skip it, wait for it, or make it on the files' paths the user gives — each passed by path, never copied or committed.
4. Record every answer as a dated decision in its document, propagated (as `/istation-backlog-execute-call-resolution` does), then commit and push the answers before the first item, in the form below (`v0.0.1 : Resolve Track 4's Open Calls`): the boundary every revert returns to, and the base every worktree is cut from.
5. Run `git status`: paths already changed are another session's, and stay out of every commit this run makes.

## 2. The serial loop

For each item, in order:

1. Mark its row 🚧 and build **per its document** to execute-item's bar: the layer law and every `⚠` invariant, the clean room first; hermetic tests (a `Sandbox`, never the real home, Launch Services, a real game or a BIOS); green with `cd lib/src/darwin && swift build --explicit-target-dependency-import-check=error && swift test` (or `lib/scripts/cicd.sh --test`, which runs both) and `python3 lib/scripts/validate_docs.py lib/documentation` from the root.
2. Ship it through the documentation flow: the MILESTONES entry; the document and its row deleted, any gate it satisfied updated (🔒 → 🟢); ROADMAP ticked; the Codebase Map, layer cards, ADR 0002's table, DEVELOPER and `reference/` as needed; SPEC only on a scope change.
   Superpowers works inside each item as `/istation-backlog-execute-item` says ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)). The group answers its waits in advance:
   - The plan is self-reviewed against the document, a scratchpad file never committed; the method is `subagent-driven-development` (or `executing-plans` without a subagent tool).
   - The worktree is consented to, made with EnterWorktree under `.claude/worktrees/`, cut from the release branch: `git merge-base --is-ancestor v<x.y.z> HEAD` holds and the baseline `lib/scripts/cicd.sh --test` passes before the first task. Task commits stay on the item branch, with any message.
   - A subagent given core work — porting, a core's tests, reviewing a core — is told the GPL rule in its prompt (the source of SwanStation, PCSX2, DuckStation, PCSX-Redux and its OpenBIOS, Beetle PSX/Mednafen, PCSX-ReARMed, Avocado and RPCS3 is never opened, read or copied; shipped code comes only from ProjectPSX, Play!, iStation's own code and public documentation), and is pointed at no oracle's build folder.
   - Every `Ruling:` (gathered in the final message's "Rulings I made") is carried, dated, into the item's MILESTONES entry with its decisions consumed, since the ship deletes its document; a stopped item keeps them as dated **Decisions made** entries.
   - Finishing's answer is the squash landing. A residual Critical or Important finding from the final review stops the item (§4); deferred minors go in the report. ExitWorktree with `action: "keep"`; then, from the main checkout on the release branch, undo the index's 🚧 edit (the merge won't overwrite local changes), `git merge --squash <item-branch>`, `lib/scripts/cicd.sh --test` on the squashed result, and the one commit and push below; then `git worktree remove .claude/worktrees/<name>` and `git branch -D <item-branch>`, both sanctioned here — never ExitWorktree's `remove`, which would need a confirmation. The item branch is never pushed.
   - A failing baseline, `systematic-debugging`'s third failed fix, or a ruling that would reverse a `[user]` decision takes the stopped-item path (§4).
   - `.superpowers/` is git-ignored and goes with its worktree; the run never `rm -rf`s it.
3. **Commit and push, once per shipped item** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): stage only its paths; the message exactly one line, `v<x.y.z> : Title Case Summary` — the release branch (`git branch --show-current`), then the item's own summary (`v0.0.1 : The Release In One Version File`) — no body, no trailers, not even the session's attribution lines; then `git push origin v<x.y.z>`. A failed push is reported with its error and left for the user, never retried with force.

## 3. Needing to ask for a dangerous operation means rethink

Nobody answers a prompt mid-run, so the rule is absolute: **a step that would warrant a permission ask for a dangerous or outward-facing operation is a step you do not take** — not on wide permissions' back (they are there so safe work flows), and not by stopping to ask. Wanting one means the approach is wrong: find the route that doesn't need it — build in the build tree, probe in a `Sandbox` or the scratchpad, work forward instead of destroying backward. The classes:

- **Destructive filesystem operations** outside the build tree and the scratchpad: any `rm -rf` of source, documents or anything untracked. Deleting is the documentation flow's per-file act, never a sweep.
- **Destructive git** beyond the sanctioned acts: no `reset --hard`, `clean -fd` or history rewriting; no force-push; never a push of `stable` or a tag, nor a merge or pull request into `stable`.
- **Real user state**: the real home and Application Support folders, the user's BIOS dumps, games, memory cards and settings, the signing identity, keychains. Probes run over content built in code, and a live run uses the personal build, never the App Store build ([Development runs on the personal channel](../../../lib/documentation/assistant/darwin/CLAUDE.md#development-runs-on-the-personal-channel)); the user's files are used only on the paths given in §1, never copied into the repository, and named in reports only by size and hash.
- **GPL source**: an oracle is built unmodified and run, nothing more; its source, disassembly or decompilation is never read (`revula_disassemble` and `revula_decompile` are never pointed at one).
- **The machine outside the repository**: installs, system or shell config edits, launch agents, network side effects beyond what a documented build does.
- **Outward-facing acts**: publishing, signing, uploading, submitting, and repository settings — `lib/scripts/required-checks.py --pr <N> --apply` stays the user's whatever an item does to the pipeline (`lib/documentation/assistant/<app>/DEVELOPER.md` → Changing the pipeline); it becomes a line in the report.

The sanctioned acts are the answers' commit (§1), each item's squash landing, commit and push, the landed item's `git worktree remove` and `git branch -D`, and a stopped item's revert of its own paths to the last commit boundary. An item that can't be built without an operation listed here is stopped by definition: what it would have needed, and why, go in its note and the report.

## 4. Unsupervised means unsupervised

- **Issues are yours to solve.** A failing test, a surprising seam, a doc ambiguity: debug it, consult the references the document cites, re-read the contributor docs, adapt. Never stop to ask what §1 could have asked.
- **Unforeseen judgment calls** take the most conservative choice consistent with SPEC and the invariants, recorded as a dated decision in the item's document *before* it ships (so it lands in the MILESTONES entry), and flagged in the report for veto.
- **A stopped item** — not buildable to its acceptance criteria after real effort — doesn't ship broken or poison the run: revert its own paths in the main checkout to the last commit boundary (never the whole tree: the checkout may be shared), leave its worktree and branch in place (ExitWorktree with `action: "keep"`) and name their path in its note and the report, record why in its document (a dated note under Decisions made, its row back to 🟢 or 🔒), skip what is gated on it, and go on.

## 5. End of the run

- What no item's commit carried — a stopped item's note and row — is one last commit in the same form, pushed.
- The validator once more (`python3 lib/scripts/validate_docs.py lib/documentation`): the run deleted documents and rows in pairs, and this proves the index stayed consistent.
- A version table that empties is **not** a release: it stays in the index until the pre-merge docs pass (`/istation-maintenance-update-documents`) retires it; `lib/release/VERSION` and the pull request into `stable` are `/istation-maintenance-update-release`'s, on the user's word, and that merge — the user's — is the release (CI tags and publishes it). Maintenance and Architecture persist empty.

## 6. Report

One report for the run, per item: shipped (its commit subject, pushed or the push's error, its milestone, the commands run and their results) or skipped, and why — a §1 reason, or stopped, with its note's location and any dangerous operation it would have needed. Then every decision made autonomously, gathered for veto; the group's final state; and what is left for the user: runs on their files, the release and its pull request, repository settings, anything skipped.
