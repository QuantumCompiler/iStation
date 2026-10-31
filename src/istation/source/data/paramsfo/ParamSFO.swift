import Foundation
import InfrastructureBytes

public enum ParamSFOError: Error {
    case notParamSFO
    case truncated
}

/// PARAM.SFO: the key/value metadata file found in every PS3 game (and PSP/PS Vita titles).
public struct ParamSFO: Sendable {
    public enum Value: Equatable, Sendable {
        case string(String)
        case integer(UInt32)
    }

    public let values: [String: Value]

    public init(bytes: [UInt8]) throws {
        guard bytes.count >= 20, Array(bytes[0..<4]) == [0x00, 0x50, 0x53, 0x46] else { // "\0PSF"
            throw ParamSFOError.notParamSFO
        }
        let keyTable = Int(bytes.u32le(8))
        let dataTable = Int(bytes.u32le(12))
        let count = Int(bytes.u32le(16))
        guard count < 1024 else { throw ParamSFOError.notParamSFO }

        var values: [String: Value] = [:]
        for index in 0..<count {
            let entry = 20 + index * 16
            guard entry + 16 <= bytes.count else { throw ParamSFOError.truncated }
            let keyOffset = keyTable + Int(bytes.u16le(entry))
            let format = bytes.u16le(entry + 2)
            let length = Int(bytes.u32le(entry + 4))
            let dataOffset = dataTable + Int(bytes.u32le(entry + 12))
            guard keyOffset < bytes.count, dataOffset + length <= bytes.count else { throw ParamSFOError.truncated }

            let keyBytes = bytes[keyOffset...].prefix(while: { $0 != 0 })
            let key = String(decoding: keyBytes, as: UTF8.self)

            switch format {
            case 0x0404:
                values[key] = .integer(bytes.u32le(dataOffset))
            case 0x0204, 0x0004:
                let raw = bytes[dataOffset..<(dataOffset + length)].prefix(while: { $0 != 0 })
                values[key] = .string(String(decoding: raw, as: UTF8.self))
            default:
                continue
            }
        }
        self.values = values
    }

    public init(url: URL) throws {
        try self.init(bytes: [UInt8](try Data(contentsOf: url)))
    }

    public func string(_ key: String) -> String? {
        if case .string(let value) = values[key] { return value }
        return nil
    }

    public var title: String? { string("TITLE")?.replacingOccurrences(of: "\n", with: " ") }
    public var titleID: String? { string("TITLE_ID") }
    /// "DG" disc game, "HG" installed (HDD) game, "GD" game data / patch, etc.
    public var category: String? { string("CATEGORY") }
}
