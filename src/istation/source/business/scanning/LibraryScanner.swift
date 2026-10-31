import BusinessIdentification
import DataCatalog
import DataParamSFO
import DataPlaylists
import Foundation

/// Walks library folders and turns disc images / game folders into `Game`s.
public struct LibraryScanner: Sendable {
    public init() {}

    public func scan(folders: [LibraryFolder]) -> [Game] {
        var games: [Game] = []
        var seen = Set<String>()
        for folder in folders {
            for game in scan(folder: folder.url, hint: folder.platformHint) where seen.insert(game.id).inserted {
                games.append(game)
            }
        }
        return games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public func scan(folder root: URL, hint: Platform?) -> [Game] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var candidates: [URL] = []
        var games: [Game] = []

        while let url = enumerator.nextObject() as? URL {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                if let game = ps3Folder(url) {
                    games.append(game)
                    enumerator.skipDescendants()
                }
                continue
            }
            if DiscIdentifier.gameFileExtensions.contains(url.pathExtension.lowercased()) {
                candidates.append(url)
            }
        }

        // A .bin referenced by a .cue, or a disc referenced by an .m3u, shouldn't appear twice.
        var referenced = Set<String>()
        for url in candidates {
            switch url.pathExtension.lowercased() {
            case "cue":
                for track in Playlists.cueTracks(url) { referenced.insert(Self.key(track)) }
            case "m3u":
                for disc in Playlists.m3uEntries(url) {
                    referenced.insert(Self.key(disc))
                    if disc.pathExtension.lowercased() == "cue" {
                        for track in Playlists.cueTracks(disc) { referenced.insert(Self.key(track)) }
                    }
                }
            default: break
            }
        }

        for url in candidates where !referenced.contains(Self.key(url)) {
            if let game = game(file: url, hint: hint ?? DiscIdentifier.platformHint(fromPath: url)) {
                games.append(game)
            }
        }
        return games
    }

    /// Installed PS3 titles (PSN games) live in RPCS3's `dev_hdd0/game/<TITLE_ID>`.
    public func scanRPCS3Installed(gameFolder: URL) -> [Game] {
        let fm = FileManager.default
        guard let titles = try? fm.contentsOfDirectory(at: gameFolder, includingPropertiesForKeys: nil) else { return [] }
        return titles.compactMap { dir in
            guard let sfo = try? ParamSFO(url: dir.appendingPathComponent("PARAM.SFO")),
                  sfo.category == "HG", // skip patches, DLC and save data
                  let titleID = sfo.titleID
            else { return nil }
            return Game(
                title: sfo.title ?? titleID,
                serial: titleID,
                platform: .ps3,
                location: dir,
                bootTarget: .rpcs3TitleID(titleID)
            )
        }
    }

    /// Compare paths after resolving symlinks (/var vs /private/var, aliased volumes).
    static func key(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    // MARK: - Identification

    func ps3Folder(_ folder: URL) -> Game? {
        guard let info = DiscIdentifier.identify(ps3DiscFolder: folder) else { return nil }
        return Game(
            title: info.title ?? TitleCleaner.clean(folder.lastPathComponent),
            serial: info.serial,
            platform: .ps3,
            location: folder,
            bootTarget: .path(folder)
        )
    }

    func game(file url: URL, hint: Platform?) -> Game? {
        guard let info = DiscIdentifier.identify(file: url, hint: hint) else { return nil }
        return Game(
            title: info.title ?? TitleCleaner.clean(url.lastPathComponent),
            serial: info.serial,
            platform: info.platform,
            location: url,
            bootTarget: .path(url)
        )
    }
}
