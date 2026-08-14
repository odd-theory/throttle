import Foundation

/// A one-way latency delay represented in milliseconds.
public struct Latency: Codable, Equatable, Sendable, CustomStringConvertible {
    public let milliseconds: Int

    public init(milliseconds: Int) throws {
        guard milliseconds >= 0 else {
            throw ThrottleError.invalidArgument("Latency cannot be negative.")
        }
        self.milliseconds = milliseconds
    }

    public init(_ rawValue: String) throws {
        try self.init(milliseconds: Self.parse(rawValue))
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
        "\(milliseconds)ms"
    }

    public var dummynetValue: String {
        "\(milliseconds)ms"
    }

    private static func parse(_ rawValue: String) throws -> Int {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = #"^([0-9]+)\s*ms$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw ThrottleError.invalidUnit(rawValue)
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let numberRange = Range(match.range(at: 1), in: trimmed),
              let milliseconds = Int(trimmed[numberRange]) else {
            throw ThrottleError.invalidUnit(rawValue)
        }
        return milliseconds
    }
}
