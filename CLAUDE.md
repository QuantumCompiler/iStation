# iStation

A personal, native Apple-platform app that plays PS1 and PS2 games in its own Swift emulators — ports of SwanStation and PCSX2 — behind one game library and one Play button.

**Contributor docs live in [`documentation/`](documentation/CLAUDE.md).** Start at [the documentation router](documentation/CLAUDE.md): it says which application's docs to read for the change you are making. Each application's `assistant/CLAUDE.md` is the entry point for working on it — read it before changing code.

Repo-wide rules to know before anything else:

- **Never commit a disc image, BIOS, PS3 system software or any game file** — users supply their own, and `swift test` fails on one anywhere in the repository.
- **Never read or copy the current DuckStation** (stenzek/duckstation, CC BY-NC-ND): PS1 code is ported only from SwanStation, PS2 code only from PCSX2.
- **Work happens on the release branch** (`v<x.y.z>`, today `v0.0.1`); `stable` only receives finished releases.
