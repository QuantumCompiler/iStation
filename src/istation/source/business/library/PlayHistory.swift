import DataCatalog

public enum PlayHistory {
    /// Keep play history for games that are still present after a rescan, matched by game ID.
    public static func merge(scanned: [Game], previous: [Game]) -> [Game] {
        let history = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return scanned.map { game in
            guard let old = history[game.id] else { return game }
            var merged = game
            merged.lastPlayed = old.lastPlayed
            merged.playTime = old.playTime
            return merged
        }
    }
}
