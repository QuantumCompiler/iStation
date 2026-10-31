/// A console iStation can launch games for.
public enum Platform: String, Codable, CaseIterable, Identifiable, Sendable {
    case ps1, ps2, ps3

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ps1: "PlayStation"
        case .ps2: "PlayStation 2"
        case .ps3: "PlayStation 3"
        }
    }

    public var shortName: String {
        switch self {
        case .ps1: "PS1"
        case .ps2: "PS2"
        case .ps3: "PS3"
        }
    }
}
