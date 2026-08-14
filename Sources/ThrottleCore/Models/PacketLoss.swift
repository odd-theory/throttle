import Foundation

/// Packet loss as a percentage from 0 through 100.
public struct PacketLoss: Codable, Equatable, Sendable, CustomStringConvertible {
    public let percent: Double

    public init(percent: Double) throws {
        guard percent.isFinite, percent >= 0, percent <= 100 else {
            throw ThrottleError.invalidArgument("Packet loss must be between 0 and 100.")
        }
        self.percent = percent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            try self.init(percent: number)
            return
        }

        let rawValue = try container.decode(String.self)
        do {
            try self.init(rawValue: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(error)")
        }
    }

    public init(rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
        guard let value = Double(trimmed) else {
            throw ThrottleError.invalidUnit(rawValue)
        }
        try self.init(percent: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(percent)
    }

    public var description: String {
        if percent.rounded() == percent {
            return "\(Int(percent))%"
        }
        return "\(percent)%"
    }

    public var dummynetProbability: String {
        let probability = percent / 100
        return String(format: "%.6f", probability)
    }
}
