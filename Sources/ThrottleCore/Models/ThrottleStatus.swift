import Foundation

/// Persisted status for the currently applied throttling state.
public struct ThrottleStatus: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        case bundled
        case saved
        case custom
    }

    public let isActive: Bool
    public let profile: NetworkProfile?
    public let source: Source?
    public let appliedAt: Date?
    public let pfToken: String?

    public init(isActive: Bool, profile: NetworkProfile?, source: Source?, appliedAt: Date?, pfToken: String? = nil) {
        self.isActive = isActive
        self.profile = profile
        self.source = source
        self.appliedAt = appliedAt
        self.pfToken = pfToken
    }

    public static let inactive = ThrottleStatus(
        isActive: false,
        profile: nil,
        source: nil,
        appliedAt: nil
    )
}
