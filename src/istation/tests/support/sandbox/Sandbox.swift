import Foundation

/// A fresh, uniquely named temporary folder, removed when the value is released. Tests write only here.
public final class Sandbox {
    public let root: URL

    public init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("iStationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    public func url(_ path: String) -> URL {
        root.appendingPathComponent(path)
    }

    /// Writes `data` at `path` inside the sandbox, creating its folders.
    @discardableResult
    public func write(_ data: Data, to path: String) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    @discardableResult
    public func write(_ text: String, to path: String) throws -> URL {
        try write(Data(text.utf8), to: path)
    }

    @discardableResult
    public func makeFolder(_ path: String) throws -> URL {
        let url = url(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
