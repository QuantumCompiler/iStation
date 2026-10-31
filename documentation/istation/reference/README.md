# iStation — Reference

The contracts iStation builds against and writes, each pinned by tests. Internals are in [DEVELOPER.md](../assistant/DEVELOPER.md); the rules are in the [ADRs](../adrs/README.md).

| Document | Contract | Pinned by |
|---|---|---|
| [emulator-launch-contract.md](emulator-launch-contract.md) | Each emulator's binary, how it is found, and the flags iStation passes | `DataEmulatorsTests/LaunchContractTests`, `BusinessLaunchingTests/GameLauncherTests` |
| [library-file.md](library-file.md) | `library.json`: the folders, games and settings iStation saves | `DataStoreTests/RecordedLibraryFileTests`, `LibraryStoreTests` |
