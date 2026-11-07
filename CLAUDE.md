# iStation

Two native Apple apps with PlayStation emulators written in Swift — macOS (PS1 and PS2) and iOS (PS1) — ported from permissively licensed references (ProjectPSX, Play!) and eligible for Apple's App Stores.

**Contributor docs live in [`documentation/`](documentation/CLAUDE.md).** Start at [the documentation router](documentation/CLAUDE.md): it says which application's docs to read for the change you are making. Each application's `assistant/CLAUDE.md` is the entry point for working on it — read it before changing code.

Repo-wide rules to know before anything else:

- **Never commit a disc image, BIOS, PS3 system software or any game file** — users supply their own, and `swift test` fails on one anywhere in the repository.
- **Never open, read or copy the source of a GPL emulator** (SwanStation, PCSX2, DuckStation, PCSX-Redux and its OpenBIOS, Beetle PSX/Mednafen, PCSX-ReARMed, Avocado, RPCS3): shipped code comes only from ProjectPSX (MIT), Play! (BSD), iStation's own MIT code and public documentation. GPL emulators are only built unmodified and run, as black-box oracles.
- **Work happens on the release branch** (`v<x.y.z>`, today `v0.0.1`); `stable` only receives finished releases.
- **Every task ends with one commit and a push** to that branch. The commit message is exactly one line — `v<x.y.z> : Title Case Summary`, e.g. `v0.0.1 : Documentation And Planning` — with no body and no trailers ([the rule](documentation/istation/assistant/CLAUDE.md#committing-and-pushing)).
