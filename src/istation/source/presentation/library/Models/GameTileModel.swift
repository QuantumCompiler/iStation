import DataCatalog
import Foundation

/// What one tile in the game grid shows.
public struct GameTileModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let platform: Platform
    /// The serial and, after a minute of play, the play time: "SLUS-20062 · 3h 5m".
    public let detail: String
    public let isRunning: Bool
    /// The file or folder, for Show in Finder and the tooltip.
    public let location: URL

    public init(game: Game, isRunning: Bool) {
        id = game.id
        title = game.title
        platform = game.platform
        self.isRunning = isRunning
        location = game.location
        let serial = game.serial ?? "Unknown serial"
        detail = game.playTime >= 60 ? "\(serial) · \(Self.playTime(game.playTime))" : serial
    }

    static func playTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }
}
