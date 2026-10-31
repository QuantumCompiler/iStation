import CoreGraphics

/// Every size and spacing the app lays out with, named for its role.
public enum Metrics {
    // Windows
    public static let windowMinWidth: CGFloat = 820
    public static let windowMinHeight: CGFloat = 520
    public static let sidebarMinWidth: CGFloat = 190
    public static let sidebarIdealWidth: CGFloat = 210
    public static let settingsWidth: CGFloat = 620
    public static let settingsHeight: CGFloat = 560

    // The game grid
    public static let tileMinWidth: CGFloat = 150
    public static let tileMaxWidth: CGFloat = 190
    public static let gridColumnSpacing: CGFloat = 20
    public static let gridRowSpacing: CGFloat = 24
    public static let gridPadding: CGFloat = 24

    // A game tile
    public static let tileSpacing: CGFloat = 6
    public static let tileCornerRadius: CGFloat = 10
    /// Width over height of a game case.
    public static let coverAspectRatio: CGFloat = 0.72
    public static let coverTitlePadding: CGFloat = 12
    public static let coverTitleShadow: CGFloat = 2
    public static let badgeHorizontalPadding: CGFloat = 6
    public static let badgeVerticalPadding: CGFloat = 3
    public static let badgeInset: CGFloat = 8
    public static let runningOutlineWidth: CGFloat = 3
    public static let detailSpacing: CGFloat = 4
}
