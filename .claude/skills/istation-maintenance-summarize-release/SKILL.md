---
name: istation-maintenance-summarize-release
description: Draft iStation's release notes for one version from evidence — ROADMAP, MILESTONES and the git range — with title and theme, intro, highlights, install, platforms, known limitations and reference, every claim checked; the release's range decides which applications' docs are read, and the skill asks when it cannot tell. Use when the user runs /istation-maintenance-summarize-release, or says "write the release notes", "draft the notes for v0.1.0", "what's new in this release", or "summarize the release for GitHub".
argument-hint: "[vX.Y.Z]"
---

# Summarize a release — iStation

The notes a GitHub release page shows for one iStation version, delivered as a draft. A merge into `stable` is the release: CI's `tag and release` (`lib/scripts/release-from-pr.sh`) tags the merge commit `v<VERSION>` and publishes "iStation v<x.y.z>" with GitHub's generated notes, and this draft is what replaces them ([Versioning](../../../lib/documentation/assistant/darwin/CLAUDE.md#versioning)). The **format** comes from the published releases, the **facts** from the repository's own record — never from memory of the session. Publishing is the user's. The optional argument is the version (`v0.1.0` or `0.1.0`); with none, the release `lib/release/VERSION` names.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Pin the release and its range

A release is repo-wide: `lib/release/VERSION`, the pipelines and the publishing rule are recorded once ([Release and Install](../../../lib/documentation/assistant/darwin/CLAUDE.md#release-and-install)); each application the range touched tells its own story from its own boards. If the user's scope is unclear, ask with AskUserQuestion rather than guessing.

```bash
tr -d ' \r\n' < lib/release/VERSION
```

- **The target** — `v<version>`, from the argument or the command above.
- **The previous release** — the newest *published* release that isn't the target, as GitHub has it: `lib/scripts/latest-release.sh --exclude v<version>` prints `<tag> <commit>`, the commit being the remote's tag, never a local one. Nothing printed means this is the first release: no range, only the whole product, and step 2 has no exemplars.
- **The range base** — that commit. If it isn't local (`git cat-file -e <sha>^{commit}`), `git fetch origin stable` brings it. A local tag that disagrees with GitHub's is reported to the user, never deleted or moved: tags are CI's and the user's.
- **The range end** — the target's own published commit if it is out (`git ls-remote origin "refs/tags/v<version>^{}" "refs/tags/v<version>"`, the peeled line winning), else `HEAD`. Drafting ahead of the merge is normal; say so if `git status` shows uncommitted work, since it would be described but isn't in the release.

Every range command below is `<base>..<end>` (the first release: everything up to `<end>`).

## 2. Read the exemplars

The two most recent published release bodies, read **in full** — they are the template, the tone and the level of detail:

```bash
gh release view <tag> --json body -q .body
```

(Without `gh` signed in, `curl -s https://api.github.com/repos/QuantumCompiler/iStation/releases/tags/<tag>` and its `body`.) None published yet, or only GitHub's generated notes: step 4's shape is the template. If the published format has moved on from step 4, the newest published release wins; say which way it moved.

## 3. Gather the evidence

- **The theme** — the version's heading in `lib/documentation/assistant/<app>/ROADMAP.md` (`### v0.1.0 — The first picture`) and that section's checked lines: each is a candidate highlight.
- **The detail** — every MILESTONES entry the range added, found by the git range, never by date:

  ```bash
  git diff <base>..<end> -- lib/documentation/assistant/<app>/MILESTONES.md | grep -E '^\+#{2,3} '
  ```

  Read each one whole: what was built, its trade-offs, how it was verified. What wasn't verified, and every cost it names, feed Known limitations. Include the working tree (`git diff <base> -- …`) when drafting ahead of the merge.
- **Items shipped** — backlog documents deleted anywhere in the range, asked of the log (one created and deleted inside it leaves no net diff) with no pathspec (the docs may have moved inside it): `git log --diff-filter=D --name-only --format= <base>..<end> | grep '/backlog/' | sort -u`. One with no MILESTONES entry was cancelled, not shipped.
- **Did the apps change?** `lib/scripts/changed.sh darwin <base> <end>`. Its paths include `lib/release/VERSION`, so `darwin=false` means the version didn't move either and the merge publishes nothing (`lib/scripts/version-check.sh` says the same): say so and stop. With `darwin=true`, `git diff --stat <base>..<end> -- lib/src/darwin/source lib/src/darwin/apps` tells a release of tools, scripts and the pipeline alone from one a player feels.
- **The history** — `git log --oneline <base>..<end>` for anything the docs missed.
- **What moves the fixed sections** — `git diff --stat <base>..<end> -- README.md lib/src/darwin/scripts` (Install); `platforms:` in `lib/src/darwin/Package.swift` (Platforms); `git diff --name-status <base>..<end> -- LICENSE lib/src/darwin/apps/Acknowledgements.json lib/documentation/reference/<app>` (Reference); and any work that closes a listed limitation.
- **What is still open** — the Maintenance rows in `lib/documentation/backlog/<app>/README.md` and ROADMAP's "Decisions needed": candidates for Known limitations.

## 4. Write it

The shape:

````markdown
# iStation vX.Y.Z — <theme>

<Intro: one paragraph.>

## Highlights

**<The claim, as one sentence.>** <One paragraph: what a person can now do, then how.>

<…four to eight of them.>

## Install

<Today a source release: the release's source archive, or a clone at the tag, built locally.>

```sh
cd lib/src/darwin
./scripts/build-personal.sh macOS      # the personal routine (or iOS, for the Simulator)
./scripts/archive-appstore.sh macOS    # an App Store archive; signing and uploading are yours
```

<Bring your own BIOS; none is included. From v1.0.0: the App Stores.>

## Platforms

<macOS 14 or later on Apple Silicon; iOS 17 or later. No Intel Mac build. Which consoles each app plays.>

## Known limitations

- **<Limitation.>** <What it means and what to do about it.>

## Reference

- <Label>: `<path>`
````

Section by section:

- **Title** — `# iStation vX.Y.Z — <theme>`: the ROADMAP heading's theme after an em dash, its first word lowercased unless it is a name or an acronym (`The first picture` → `the first picture`; `JIT verified, …` stays).
- **Intro** — one paragraph, two or three sentences, in plain words for someone who plays games, not someone who builds them. It opens by saying what kind of release this is — "The first release.", "A maintenance release." — then what changed at the level of the whole release. When nothing a player feels changed, say so, and whether upgrading is worth it.
- **Highlights** — four to eight, what a person can now do first, the process ones last unless the release is about process. Each is a **bold claim that is one full sentence, period inside the bold**, then one paragraph: what changed for the person first, then the mechanism, naming real schemes, scripts and paths in backticks, and real counts. A fix names what used to happen. Group ROADMAP lines that are one story; never split one line into two highlights. Every sentence traces to a MILESTONES entry, a ROADMAP line or the diff; every number is quoted from them or measured, never estimated.
- **Install** and **Platforms** — verbatim from the previous release; change only what step 3 found changed. The first release writes them from `README.md` → Build and run and `lib/src/darwin/Package.swift`. Say which consoles each app plays, and when it plays none yet, say that.
- **Known limitations** — start from the previous release's list. Remove a bullet only when this release closed it (usually a highlight too); reword one that changed; keep the rest word for word. New ones — the costs from step 3 — go after it: one as "One new one: …", several as bullets under a line saying they're new.
- **Reference** — the licences: iStation's own MIT (`LICENSE`) and the notices the apps carry for ported code, ProjectPSX's MIT and Play!'s BSD, as far as `lib/src/darwin/apps/Acknowledgements.json` lists them (nothing GPL ships, so no GPL emulator is named as a source); any user-facing reference document the range added; the source tag. Paths as inline code, not links.

House style:

- The audience plays games and installs the app. No backlog ids (`3e`, `M1`), no milestone letters, no dates, no "the user's call", no session narrative, no links into MILESTONES. Contributor mechanics (the pipelines, `cicd.sh`) appear only when they are the release's subject.
- No Sony logos or artwork; compatibility only ("plays PS1 games"). No BIOS, disc image or game is included or linked to: users bring their own.
- Em dashes in prose; British spelling as iStation's docs have it ("licence", "behaviour"); no emoji; plain Markdown GitHub renders.
- Honest over flattering: a cost is named where it is real.

## 5. Check the draft

Script what can be scripted:

- nothing internal leaked — prints nothing, or only an Apple chip's name (`M1`), checked by eye:

  ```bash
  grep -nE 'item [0-9]|\b[0-9]+[a-z]\b|\b[MA][0-9]+\b|Milestone [A-Z]\b|user.s call|20[0-9]{2}-[0-9]{2}-[0-9]{2}|backlog/|\[(user|default)' <draft>
  ```

- Install and Platforms are identical to the previous release's, unless a change was deliberate — diff the two sections with `diff --strip-trailing-cr` (a body edited on GitHub's page comes back with CRLF endings);
- every path under **Reference** exists at the range end (`git cat-file -e <end>:<path>`);
- every scheme, script and path a highlight names exists at `<end>` (`git cat-file -e`, or a grep under `lib/src/darwin/`);
- every highlight maps to a piece of evidence from step 3 — list the mapping for yourself, not in the notes; drop what can't be backed.

## 6. Deliver

Write the draft to `istation-release-notes-vX.Y.Z.md` in the session's scratchpad (or `${TMPDIR:-/tmp}` without one), never in the repository — this skill changes no file there, so it commits and pushes nothing ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)). Show it in full in the reply inside a four-backtick `markdown` fence, so its own code blocks survive a copy. Then say, briefly: the range (`<base>..<end>`, and whether the working tree was included), which MILESTONES entries each highlight came from, and what was left out and why.

**Do not publish.** Editing a release is public, and the user's: only when they explicitly ask,

```bash
gh release edit vX.Y.Z --notes-file <draft>
```

which replaces the generated notes. Drafting ahead of the merge, the release doesn't exist yet: say it can be applied once the merge publishes it. Without `gh`, the user pastes the draft into the release page's **Edit**. Never a tag, a release or a push to `stable` from here.
