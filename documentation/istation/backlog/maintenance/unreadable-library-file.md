# An unreadable library file is silently replaced — keep it aside and tell the user

**What / why.** `LibraryStore.load()` (`src/istation/source/data/store/LibraryStore.swift`) returns an empty `LibraryState` both when `library.json` is missing and when it exists but fails to decode (`try?` on the decode). `Library.init` (`src/istation/source/business/library/Library.swift`) then calls `detectEmulators()`, which saves as soon as it finds any emulator — so a corrupt file, or one written by a newer iStation, is overwritten at launch, and the user's play history goes with it. Any later save (a setting, a rescan) does the same. Inherited from the scaffold; found by reading the code at construction, 2026-10-31, not yet reproduced against a real file.

**Core constraint(s).** [ADR 0007](../../adrs/backwards-compatibility.md): state written by any version is read compatibly or migrated, never silently rewritten. A missing file must still mean a quiet, empty first launch. The real home is reached only through `Locations` (⚠ in CLAUDE.md), so tests run this over a `Sandbox`.

**Seam + files.**
- Data `store`: `load()` tells "no file" (an empty library) apart from "a file that can't be read" (a thrown error, or a result enum); a new `LibraryStore` function moves an unreadable file aside.
- Business `library`: `LibraryPersisting.load` changes to match; `Library.init` keeps the file aside, starts empty, and sets `lastError` to a message naming the kept file. The live conformance in `Services.swift` and the fakes in `tests/support/libraryfakes/LibraryFakes.swift` and each Presentation module's `Previews/PreviewLibrary.swift` change with the protocol.
- Tests: `tests/data/store/LibraryStoreTests.swift`, `tests/business/library/LibraryTests.swift`.

**Decisions made** (dated):
- 2026-10-31: queued as Maintenance, found while porting the scaffold (construction).

**Open calls:**
- [default: move it aside as `library.unreadable-<ISO 8601 timestamp>.json` beside the original, start with an empty library, and show "Your library file couldn’t be read, so iStation started a new one. The old file was kept as <name>."] What happens to the unreadable file, and what the user is told.
- [default: treat a file from a newer iStation the same as a corrupt one; no version field is added in this item] Files from the future.

**Guardrail(s).** A test writes a corrupt `library.json` into a `Sandbox`, builds a `Library` over a real `LibraryStore` with an emulator detected (which forces the first save), and asserts that the original bytes survive in the kept-aside file and that `lastError` names it. The missing-file test stays: no error, no kept file.

**Acceptance criteria:**
- [ ] Launching over a corrupt `library.json` never overwrites its bytes; they are kept beside it under a new name.
- [ ] The user sees one message saying what happened and where the old file is.
- [ ] A missing file still starts an empty library with no message.
- [ ] `RecordedLibraryFileTests` still passes unchanged.

**Scope note.** Maintenance, claimable any time; no gate. Out of scope: migrating old files (none exist yet), a format version field.
