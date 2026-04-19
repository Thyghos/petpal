// PetpalBackupZip.swift
// Minimal ZIP read/write (STORED / compression 0) for a single JSON entry — no third-party deps.

import Foundation
import zlib

enum PetpalBackupZip {
    /// Entry file name inside archives we create.
    static let entryName = "petpal-backup.json"

    enum ZipError: LocalizedError {
        case invalidArchive
        case unsupportedCompression
        case corruptEntry

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "The ZIP file isn’t a valid Petpal backup."
            case .unsupportedCompression: return "This ZIP uses compression Petpal doesn’t support yet."
            case .corruptEntry: return "The ZIP entry couldn’t be read."
            }
        }
    }

    /// Wrap `jsonData` as a one-file ZIP (STORED).
    static func zipJSON(_ jsonData: Data) -> Data {
        zipSingleStoredFile(fileData: jsonData, entryName: entryName)
    }

    /// If `data` begins with a ZIP local header, extract the JSON payload; otherwise return `data`.
    static func jsonDataIfZipOrPlain(_ data: Data) throws -> Data {
        guard data.count >= 4,
              data[0] == 0x50,
              data[1] == 0x4B,
              data[2] == 0x03,
              data[3] == 0x04
        else {
            return data
        }
        guard let extracted = try extractStoredJSON(from: data) else {
            throw ZipError.invalidArchive
        }
        return extracted
    }

    // MARK: - Write

    private static func zipSingleStoredFile(fileData: Data, entryName: String) -> Data {
        let nameBytes = Data(entryName.utf8)
        let uncompressed = UInt32(fileData.count)
        let crc = crc32IEEE(fileData)

        var out = Data()
        let localHeaderOffset: UInt32 = 0

        appendUInt32(&out, 0x0403_4b50)
        appendUInt16(&out, 20)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt32(&out, crc)
        appendUInt32(&out, uncompressed)
        appendUInt32(&out, uncompressed)
        appendUInt16(&out, UInt16(nameBytes.count))
        appendUInt16(&out, 0)
        out.append(nameBytes)
        out.append(fileData)

        let centralDirOffset = UInt32(out.count)

        appendUInt32(&out, 0x0201_4b50)
        appendUInt16(&out, 0x0314)
        appendUInt16(&out, 20)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt32(&out, crc)
        appendUInt32(&out, uncompressed)
        appendUInt32(&out, uncompressed)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt32(&out, 0)
        appendUInt32(&out, localHeaderOffset)
        appendUInt16(&out, UInt16(nameBytes.count))
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        out.append(nameBytes)

        let centralSize = UInt32(out.count) - centralDirOffset

        appendUInt32(&out, 0x0605_4b50)
        appendUInt16(&out, 0)
        appendUInt16(&out, 0)
        appendUInt16(&out, 1)
        appendUInt16(&out, 1)
        appendUInt32(&out, centralSize)
        appendUInt32(&out, centralDirOffset)
        appendUInt16(&out, 0)

        return out
    }

    private static func appendUInt16(_ data: inout Data, _ v: UInt16) {
        var le = v.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ data: inout Data, _ v: UInt32) {
        var le = v.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func crc32IEEE(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return UInt32(crc32(0, base, uInt(raw.count)))
        }
    }

    // MARK: - Read (local headers, STORED only)

    private static func extractStoredJSON(from zipData: Data) throws -> Data? {
        var offset = 0
        var preferred: Data?
        var fallback: Data?

        while offset + 30 <= zipData.count {
            let sig = readUInt32(zipData, at: offset)
            if sig == 0x0201_4b50 {
                break
            }
            if sig != 0x0403_4b50 {
                offset += 1
                continue
            }

            let method = readUInt16(zipData, at: offset + 8)
            guard method == 0 else {
                throw ZipError.unsupportedCompression
            }

            let expectedCrc = readUInt32(zipData, at: offset + 14)
            let compSize = Int(readUInt32(zipData, at: offset + 18))
            let uncompSize = Int(readUInt32(zipData, at: offset + 22))
            let nameLen = Int(readUInt16(zipData, at: offset + 26))
            let extraLen = Int(readUInt16(zipData, at: offset + 28))
            let headerEnd = offset + 30 + nameLen + extraLen
            let dataStart = headerEnd
            let dataEnd = dataStart + compSize

            guard compSize == uncompSize, dataEnd <= zipData.count else {
                throw ZipError.corruptEntry
            }

            let nameStart = offset + 30
            let entryNameRaw = String(data: zipData.subdata(in: nameStart ..< nameStart + nameLen), encoding: .utf8) ?? ""
            let payload = zipData.subdata(in: dataStart ..< dataEnd)

            if crc32IEEE(payload) != expectedCrc {
                throw ZipError.corruptEntry
            }

            if entryNameRaw == entryName {
                preferred = payload
            } else if fallback == nil {
                fallback = payload
            }

            offset = dataEnd
        }

        return preferred ?? fallback
    }

    private static func readUInt16(_ data: Data, at i: Int) -> UInt16 {
        guard i + 2 <= data.count else { return 0 }
        return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at i: Int) -> UInt32 {
        guard i + 4 <= data.count else { return 0 }
        return UInt32(data[i])
            | (UInt32(data[i + 1]) << 8)
            | (UInt32(data[i + 2]) << 16)
            | (UInt32(data[i + 3]) << 24)
    }
}
