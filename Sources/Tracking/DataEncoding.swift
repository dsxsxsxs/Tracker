import Foundation

struct TrackingLog: Encodable, Sendable {
    let eventId: String
    let eventTime: Date
    let payload: [String: Sendable]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(eventTime.timestamp, forKey: .eventTime)
        try container.encode(payload, forKey: .payload)
    }

    enum CodingKeys: String, CodingKey {
        case eventTime
        case eventId
        case payload
    }
}

extension Date {
    var timestamp: Int {
        Int(floor(timeIntervalSince1970))
    }
}

extension [TrackingData] {
    func asData() throws -> Data {
        let leftBracket = try "[".utf8Data()
        let rightBracket = try "]".utf8Data()
        let comma = try ",".utf8Data()
        let flattened: Data = self.map(\.data).joined(separator: comma)
            .reduce(into: leftBracket) { result, data in
                result.append(data)
            }
        return flattened + rightBracket
    }
}

private extension String {
    func utf8Data() throws -> Data {
        guard let data = data(using: .utf8) else {
            throw NSError(domain: "unable to convert to utf8 data", code: 0, userInfo: ["value": self])
        }
        return data
    }
}

import zlib

// MEMO:
// zlib doc: https://zlib.net/manual.html
extension Data {
    // 16384bytes
    private static let chunk = 1 << 14

    func deflated() throws -> Data {
        var stream = z_stream()
        var status: Int32

        // Initialize the stream for compression (Z_DEFLATED and Compression Level 8)
        status = deflateInit_(&stream, 8, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else {
            throw NSError(domain: "zlib", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "deflateInit failed with status: \(status)"])
        }
        // 省略
        var data = Data(capacity: Self.chunk)
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += Self.chunk
            }

            let inputCount = self.count
            let outputCount = data.count

            self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
                stream.avail_in = uInt(inputCount) - uInt(stream.total_in)

                data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(outputCount) - uInt(stream.total_out)

                    status = deflate(&stream, Z_FINISH)

                    stream.next_out = nil
                }

                stream.next_in = nil
            }

        } while stream.avail_out == .zero && status != Z_STREAM_END

        guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
            throw NSError(domain: "zlib", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "deflate failed with status: \(status)"])
        }

        data.count = Int(stream.total_out)

        return data
    }
}
