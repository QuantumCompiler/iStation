import Foundation

/// One component whose notice the apps carry: its name, licence, notice text and source.
public struct Acknowledgement: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    /// An SPDX licence identifier, e.g. "MIT".
    public let licence: String
    public let notice: String
    public let source: URL

    public init(name: String, licence: String, notice: String, source: URL) {
        self.name = name
        self.licence = licence
        self.notice = notice
        self.source = source
    }
}
