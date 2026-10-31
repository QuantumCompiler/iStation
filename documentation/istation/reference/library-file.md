# The library file

Everything iStation remembers lives in one JSON file, `~/Library/Application Support/iStation/library.json`, written by `LibraryStore` (`src/istation/source/data/store/LibraryStore.swift`) whenever the folders, the settings or a game's play history change. The file is read compatibly by every later version ([ADR 0007](../adrs/backwards-compatibility.md)).

## Encoding

Pretty-printed JSON with sorted keys, written atomically. Dates are ISO 8601 (`2026-10-26T07:33:20Z`). URLs are absolute `file://` strings. Every top-level section, and every settings field, may be missing: it then takes its default.

## Shape (v0.0.1)

```json
{
  "folders": [
    { "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "url": "file:///Games/PS1", "platformHint": "ps1" }
  ],
  "games": [
    {
      "id": "ps1:/Games/PS1/Crash Bandicoot (USA).cue",
      "title": "Crash Bandicoot",
      "serial": "SCUS-94900",
      "platform": "ps1",
      "location": "file:///Games/PS1/Crash%20Bandicoot%20(USA).cue",
      "bootTarget": { "path": { "_0": "file:///Games/PS1/Crash%20Bandicoot%20(USA).cue" } },
      "lastPlayed": "2026-10-26T07:33:20Z",
      "playTime": 11100
    },
    {
      "id": "ps3:id:NPUA80083",
      "title": "Flower",
      "serial": "NPUA80083",
      "platform": "ps3",
      "location": "file:///Users/me/Library/Application%20Support/rpcs3/dev_hdd0/game/NPUA80083",
      "bootTarget": { "rpcs3TitleID": { "_0": "NPUA80083" } },
      "playTime": 1800
    }
  ],
  "settings": {
    "emulatorApps": { "pcsx2": "file:///Applications/PCSX2.app/" },
    "launchOptions": { "fullscreen": true, "fastBoot": false },
    "includeRPCS3InstalledGames": true,
    "rpcs3GameFolder": "file:///Volumes/Games/rpcs3/dev_hdd0/game"
  }
}
```

| Field | Meaning | Default when missing |
|---|---|---|
| `folders[].id` | The folder's identity (a UUID) | required in a folder entry |
| `folders[].url` | A library folder | required in a folder entry |
| `folders[].platformHint` | `ps1`/`ps2`/`ps3`: the console to assume when a disc can't be read | none (auto-detect) |
| `games[].id` | `<console>:<standardized path>`, or `<console>:id:<title ID>` for an installed PS3 title — the key play history follows across rescans | required |
| `games[].title`, `serial`, `platform`, `location` | What the library shows; `serial` may be absent | required, except `serial` |
| `games[].bootTarget` | `path` (an image, playlist or PS3 folder) or `rpcs3TitleID` | required |
| `games[].lastPlayed` | When it was last launched | never played |
| `games[].playTime` | Total seconds played | required |
| `settings.emulatorApps` | The `.app` chosen per emulator (`duckstation`, `pcsx2`, `rpcs3`) | none chosen |
| `settings.launchOptions` | `fullscreen`, `fastBoot` | both `true` |
| `settings.includeRPCS3InstalledGames` | List RPCS3's installed titles | `true` |
| `settings.rpcs3GameFolder` | RPCS3's `dev_hdd0/game` | RPCS3's default location |

A rescan rebuilds `games` from the folders and copies `lastPlayed` and `playTime` across by `id`; moving a file changes its `id` and starts its history over.

## Known gap

A file that exists but fails to decode is loaded as an empty library and replaced by the next save (Maintenance item M1).
