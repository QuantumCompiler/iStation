import SwiftUI

/// Every font the app sets text in, named for its role.
public enum Typography {
    /// The title printed on a placeholder case.
    public static let coverTitle = Font.headline
    public static let tileTitle = Font.callout.weight(.medium)
    public static let tileDetail = Font.caption
    public static let badge = Font.caption2.weight(.bold)
}
