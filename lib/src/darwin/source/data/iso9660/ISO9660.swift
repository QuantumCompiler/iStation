// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import InfrastructureBytes

public enum DiscError: Error {
    case unreadable
    case notISO9660
    case truncated
}

/// Reads 2048-byte user-data sectors from a cooked .iso or a raw 2352-byte .bin.
struct SectorReader {
    static let userDataSize = 2048
    private static let syncPattern: [UInt8] = [0x00] + Array(repeating: 0xFF, count: 10) + [0x00]

    private let handle: FileHandle
    let sectorSize: Int
    let dataOffset: Int

    init(url: URL) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw DiscError.unreadable }
        self.handle = handle
        let header = [UInt8](try handle.read(upToCount: 16) ?? Data())
        if header.count == 16, Array(header[0..<12]) == Self.syncPattern {
            // Raw CD sector: 12 sync + 3 address + 1 mode byte.
            sectorSize = 2352
            dataOffset = header[15] == 1 ? 16 : 24 // Mode 1 vs Mode 2 Form 1 (8-byte subheader)
        } else {
            sectorSize = 2048
            dataOffset = 0
        }
    }

    func read(sector: Int, count: Int = 1) throws -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(count * Self.userDataSize)
        for index in 0..<count {
            try handle.seek(toOffset: UInt64((sector + index) * sectorSize + dataOffset))
            let chunk = [UInt8](try handle.read(upToCount: Self.userDataSize) ?? Data())
            guard chunk.count == Self.userDataSize else { throw DiscError.truncated }
            out += chunk
        }
        return out
    }

    func close() {
        try? handle.close()
    }
}

/// Minimal read-only ISO 9660 filesystem: just enough to find SYSTEM.CNF / PARAM.SFO.
public struct ISO9660 {
    public struct Entry: Sendable {
        public let name: String
        public let lba: Int
        public let size: Int
        public let isDirectory: Bool
    }

    private let reader: SectorReader
    public let root: Entry

    public init(url: URL) throws {
        reader = try SectorReader(url: url)
        let pvd = try reader.read(sector: 16)
        guard pvd[0] == 1, Array(pvd[1..<6]) == Array("CD001".utf8) else {
            reader.close()
            throw DiscError.notISO9660
        }
        guard let root = Self.parseRecord(pvd, at: 156) else {
            reader.close()
            throw DiscError.notISO9660
        }
        self.root = root
    }

    public func close() {
        reader.close()
    }

    public func entries(in directory: Entry) throws -> [Entry] {
        let sectorCount = max(1, (directory.size + SectorReader.userDataSize - 1) / SectorReader.userDataSize)
        guard sectorCount < 512 else { return [] } // sanity limit for corrupt images
        let data = try reader.read(sector: directory.lba, count: sectorCount)
        var result: [Entry] = []
        var offset = 0
        while offset < min(data.count, directory.size) {
            let length = Int(data[offset])
            if length == 0 {
                // Records never straddle sectors; zero padding means skip to the next sector.
                offset = (offset / SectorReader.userDataSize + 1) * SectorReader.userDataSize
                continue
            }
            if let entry = Self.parseRecord(data, at: offset), entry.name != "." && entry.name != ".." {
                result.append(entry)
            }
            offset += length
        }
        return result
    }

    /// Case-insensitive lookup of a slash-separated path such as "PS3_GAME/PARAM.SFO".
    public func find(_ path: String) throws -> Entry? {
        var current = root
        for component in path.split(separator: "/") {
            let target = component.uppercased()
            guard current.isDirectory,
                  let next = try entries(in: current).first(where: { $0.name == target })
            else { return nil }
            current = next
        }
        return current
    }

    public func read(_ entry: Entry, maxBytes: Int = 64 * 1024) throws -> [UInt8] {
        let size = min(entry.size, maxBytes)
        guard size > 0 else { return [] }
        let sectors = (size + SectorReader.userDataSize - 1) / SectorReader.userDataSize
        return Array(try reader.read(sector: entry.lba, count: sectors).prefix(size))
    }

    private static func parseRecord(_ data: [UInt8], at offset: Int) -> Entry? {
        guard offset + 33 <= data.count else { return nil }
        let length = Int(data[offset])
        let nameLength = Int(data[offset + 32])
        guard length >= 34, offset + 33 + nameLength <= data.count else { return nil }

        let rawName = Array(data[(offset + 33)..<(offset + 33 + nameLength)])
        let name: String
        if rawName == [0] {
            name = "."
        } else if rawName == [1] {
            name = ".."
        } else {
            var text = String(decoding: rawName, as: UTF8.self).uppercased()
            if let semicolon = text.firstIndex(of: ";") { text = String(text[..<semicolon]) }
            if text.hasSuffix(".") { text.removeLast() }
            name = text
        }

        return Entry(
            name: name,
            lba: Int(data.u32le(offset + 2)),
            size: Int(data.u32le(offset + 10)),
            isDirectory: data[offset + 25] & 0x02 != 0
        )
    }
}
