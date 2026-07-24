import Foundation

/// A bandwidth value represented internally in bits per second.
public struct Bandwidth: Codable, Equatable, Sendable, CustomStringConvertible {
    public let bitsPerSecond: Int64

    public init(bitsPerSecond: Int64) throws {
        guard bitsPerSecond >= 0 else {
            throw ThrottleError.invalidArgument("Bandwidth cannot be negative.")
        }
        self.bitsPerSecond = bitsPerSecond
    }

    public init(_ rawValue: String) throws {
        let parsed = try Self.parse(rawValue)
        try self.init(bitsPerSecond: parsed)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        do {
            try self.init(rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(error)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        if bitsPerSecond == 0 {
            return "0bit"
        }
        if bitsPerSecond % 1_000_000_000 == 0 {
            return "\(bitsPerSecond / 1_000_000_000)gbit"
        }
        if bitsPerSecond % 1_000_000 == 0 {
            return "\(bitsPerSecond / 1_000_000)mbit"
        }
        if bitsPerSecond % 1_000 == 0 {
            return "\(bitsPerSecond / 1_000)kbit"
        }
        return "\(bitsPerSecond)bit"
    }

    public var dummynetValue: String {
        if bitsPerSecond == 0 {
            return "0bit/s"
        }
        if bitsPerSecond % 1_000_000_000 == 0 {
            return "\(bitsPerSecond / 1_000_000_000)Gbit/s"
        }
        if bitsPerSecond % 1_000_000 == 0 {
            return "\(bitsPerSecond / 1_000_000)Mbit/s"
        }
        if bitsPerSecond % 1_000 == 0 {
            return "\(bitsPerSecond / 1_000)Kbit/s"
        }
        return "\(bitsPerSecond)bit/s"
    }

    private static func parse(_ rawValue: String) throws -> Int64 {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = #"^([0-9]+(?:\.[0-9]+)?)\s*(bit|bits|bps|kbit|kbps|mbit|mbps|gbit|gbps)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw ThrottleError.invalidUnit(rawValue)
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let numberRange = Range(match.range(at: 1), in: trimmed),
              let unitRange = Range(match.range(at: 2), in: trimmed),
              let value = Double(trimmed[numberRange]) else {
            throw ThrottleError.invalidUnit(rawValue)
        }

        let multiplier: Double
        switch String(trimmed[unitRange]) {
        case "bit", "bits", "bps":
            multiplier = 1
        case "kbit", "kbps":
            multiplier = 1_000
        case "mbit", "mbps":
            multiplier = 1_000_000
        case "gbit", "gbps":
            multiplier = 1_000_000_000
        default:
            throw ThrottleError.invalidUnit(rawValue)
        }

        let bits = value * multiplier
        guard bits.isFinite, bits <= Double(Int64.max) else {
            throw ThrottleError.invalidArgument("Bandwidth is too large: \(rawValue)")
        }
        return Int64(bits.rounded())
    }
}
