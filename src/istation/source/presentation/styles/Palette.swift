import DataCatalog
import SwiftUI

/// Every color the app draws with, named for its role.
public enum Palette {
    /// The placeholder "case" color for each console, until cover art lands (ROADMAP v0.1.0).
    public static func tint(for platform: Platform) -> Color {
        switch platform {
        case .ps1: Color(red: 0.45, green: 0.47, blue: 0.52)
        case .ps2: Color(red: 0.10, green: 0.20, blue: 0.55)
        case .ps3: Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    /// Text drawn on a console tint.
    public static let onTint = Color.white
    /// The console badge's backing on a tile.
    public static let badgeBackground = Color.black.opacity(0.35)
    /// The outline and label of the game that is running.
    public static let running = Color.accentColor
    /// A setting that needs attention (an emulator not found).
    public static let missing = Color.red
    public static let secondaryText = Color.secondary
}
