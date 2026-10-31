import DataCatalog

/// SF Symbol names, named for what they stand for.
public enum Symbols {
    public static func console(_ platform: Platform) -> String {
        switch platform {
        case .ps1: "1.circle"
        case .ps2: "2.circle"
        case .ps3: "3.circle"
        }
    }

    public static let allGames = "square.grid.2x2"
    public static let recentlyPlayed = "clock"
    public static let addFolder = "folder.badge.plus"
    public static let rescan = "arrow.clockwise"
    public static let noGames = "opticaldisc"
    public static let playing = "play.fill"
    public static let removeFolder = "minus.circle"
}
