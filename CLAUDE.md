# iStation

A personal, native macOS app that gives DuckStation, PCSX2 and RPCS3 one shared game library and one Play button.

**Contributor docs live in [`documentation/`](documentation/CLAUDE.md).** Start at [the documentation router](documentation/CLAUDE.md): it says which application's docs to read for the change you are making. Each application's `assistant/CLAUDE.md` is the entry point for working on it — read it before changing code.

Repo-wide rules to know before anything else:

- **Never commit a disc image, BIOS, PS3 system software or any game file** — users supply their own, and `swift test` fails on one anywhere in the repository.
- **Work happens on the release branch** (`v<x.y.z>`, today `v0.0.1`); `stable` only receives finished releases.
