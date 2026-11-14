# Superpowers inside the lifecycle, and the skills in Apogee's form — `.claude/settings.json`, the mapping table, the "Which application?" ladder

**What / why.** Apogee runs its docs-first lifecycle with two more pieces iStation lacks (the user's call, 2026-11-14, to mimic its procedure):

- **Superpowers inside the lifecycle.** Apogee's `.claude/settings.json` enables `superpowers@claude-plugins-official` and sets `worktree.baseRef: head`; its `.gitignore` keeps `.superpowers/`, `.claude/worktrees/` and `.claude/settings.local.json` out of every commit; and its CLI docs' "Superpowers fits the docs-first lifecycle" (2026-11-07) maps each Superpowers skill onto a lifecycle step — brainstorming ends in a backlog document; a spike stays a report; `systematic-debugging` stops before the fix, which becomes the queued item; an item is built with `test-driven-development` and, for several tasks, `writing-plans` then `subagent-driven-development` in a worktree from the release branch, its plan a session-only file never committed; landing is one squash commit per item; `writing-skills` keeps the skills application-agnostic.
- **Application-aware skills.** Each of Apogee's 13 skills opens with "0. Which application?" (`apogee-backlog-execute-item/SKILL.md:10–18`): resolve `<app>` from the arguments, then the conversation, else ask — then read `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`.

iStation's 13 skills name `documentation/istation/…` directly and have no ladder; its CLAUDE.md has no Superpowers section, though the Superpowers skills are already offered in its sessions.

**Core constraint(s).** **iStation's own rules win where Apogee's differ**: every task ends with one commit, `v<x.y.z> : Title Case Summary` and nothing else, **and a push** to the release branch (the user's call, 2026-11-07) — Apogee's "pushing is on the user's word" and "the user makes the commit" give way. The clean-room rule (ADR 0013 §2–§3): a subagent Superpowers dispatches for core work is given the GPL rule in its prompt and never sees GPL emulators' source, and a session that has read one dispatches no core work. Release builds carry no tools. Tests hermetic.

**Seam + files.** No module.
- `.claude/settings.json`: `superpowers@claude-plugins-official` enabled, `worktree.baseRef: head`.
- `.gitignore`: `.superpowers/`, `.claude/worktrees/`, `.claude/settings.local.json`.
- `lib/documentation/assistant/darwin/CLAUDE.md`: a "Superpowers fits the docs-first lifecycle" section — Apogee's table with iStation's skills, its tests (`cicd.sh --test`, `swift test`), its commit-and-push landing, and the clean-room rule for dispatched subagents; the one-time setup (`claude plugin install superpowers@claude-plugins-official --scope project`, the user's).
- The 13 skills under `.claude/skills/istation-*`: a "0. Which application?" step (today one application, `darwin`, with `macos/` and `ios/` subfolders), paths of the form `lib/documentation/<kind>/<app>/`, and whatever else Apogee's version of each skill carries that iStation's lacks — compared skill by skill, keeping iStation's commit-and-push and clean-room steps.

**Reference.** Apogee: `.claude/settings.json`, `.gitignore`, `lib/documentation/assistant/cli/CLAUDE.md` → "Superpowers fits the docs-first lifecycle", `lib/documentation/assistant/darwin/CLAUDE.md` → "Superpowers" (an app's delta), and its 13 `.claude/skills/apogee-*/SKILL.md`. In-house: CLAUDE.md → Committing and pushing; ADR 0013.

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's agentic procedure, adapted for iStation (the user's call).
- 2026-11-07: every task ends with one commit and a push, `v<x.y.z> : Title Case Summary` (the user's call) — consumed here, not reopened.
- 2026-11-14: a Superpowers worktree item lands as one squash commit on the release branch, then is pushed (the default, confirmed by the user).
- 2026-11-14: each skill is compared with its Apogee twin and gains what iStation can use; a step that only fits Apogee is left out and named in MILESTONES (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** The validator checks every skill's links; a search finds no `documentation/istation` path in `.claude/skills/`; a dry `/istation-backlog-investigate-spike` with an ambiguous request asks which application before reading anything.

**Acceptance criteria:**
- [ ] `.claude/settings.json` and `.gitignore` match Apogee's for Superpowers and worktrees.
- [ ] CLAUDE.md maps every Superpowers skill onto iStation's lifecycle, with iStation's commit-and-push landing and the clean-room rule.
- [ ] All 13 skills open with the application ladder and read the new layout.

**Scope note.** v0.0.1, track 4; gated on 4b (the final paths). Out of scope: installing the plugin on the user's machine (the user's), and Apogee's dev-channel rules for a CLI binary (iStation's counterpart is 4f).
