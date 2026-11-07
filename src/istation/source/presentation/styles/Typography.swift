import SwiftUI

/// Every font the apps set text in, named for its role.
public enum Typography {
    public static let title = Font.title2.weight(.semibold)
    public static let body = Font.body
    /// The large symbol on an empty screen.
    public static let screenSymbol = Font.system(size: 48)
}
