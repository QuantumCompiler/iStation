// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Builds a tiny single-directory ISO 9660 image, optionally as raw 2352-byte Mode 2 sectors.
public func makeISO(files: [String: [UInt8]], raw: Bool = false) -> Data {
    let sectorSize = 2048
    func le32(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24 & 0xFF)] }
    func record(_ name: [UInt8], lba: Int, size: Int, directory: Bool) -> [UInt8] {
        let length = 33 + name.count + (name.count % 2 == 0 ? 1 : 0)
        var r = [UInt8](repeating: 0, count: length)
        r[0] = UInt8(length)
        r.replaceSubrange(2..<6, with: le32(lba))
        r.replaceSubrange(10..<14, with: le32(size))
        r[25] = directory ? 0x02 : 0x00
        r[32] = UInt8(name.count)
        r.replaceSubrange(33..<(33 + name.count), with: name)
        return r
    }
    func pad(_ bytes: [UInt8]) -> [UInt8] { bytes + Array(repeating: 0, count: sectorSize - bytes.count) }

    let rootLBA = 18
    let sortedFiles = files.sorted { $0.key < $1.key }
    var directory = record([0], lba: rootLBA, size: sectorSize, directory: true)
        + record([1], lba: rootLBA, size: sectorSize, directory: true)
    var fileSectors: [[UInt8]] = []
    for (offset, file) in sortedFiles.enumerated() {
        directory += record(Array("\(file.key);1".utf8), lba: rootLBA + 1 + offset, size: file.value.count, directory: false)
        fileSectors.append(pad(file.value))
    }

    var pvd = [UInt8](repeating: 0, count: sectorSize)
    pvd[0] = 1
    pvd.replaceSubrange(1..<6, with: Array("CD001".utf8))
    pvd[6] = 1
    pvd.replaceSubrange(156..<190, with: record([0], lba: rootLBA, size: sectorSize, directory: true))

    var terminator = [UInt8](repeating: 0, count: sectorSize)
    terminator[0] = 0xFF
    terminator.replaceSubrange(1..<6, with: Array("CD001".utf8))

    let sectors = Array(repeating: [UInt8](repeating: 0, count: sectorSize), count: 16)
        + [pvd, terminator, pad(directory)] + fileSectors

    guard raw else { return Data(sectors.joined()) }
    let sync: [UInt8] = [0x00] + Array(repeating: 0xFF, count: 10) + [0x00]
    var out = Data()
    for sector in sectors {
        out += sync + [0, 0, 0, 2] + Array(repeating: 0, count: 8) + sector + Array(repeating: 0, count: 280)
    }
    return out
}
