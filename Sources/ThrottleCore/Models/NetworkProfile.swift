import Foundation

/// A complete network throttling profile.
public struct NetworkProfile: Codable, Equatable, Sendable {
    public let name: String
    public let download: Bandwidth
    public let upload: Bandwidth
    public let latency: Latency
    public let packetLoss: PacketLoss

    public init(
        name: String,
        download: Bandwidth,
        upload: Bandwidth,
        latency: Latency,
        packetLoss: PacketLoss
    ) {
        self.name = name
        self.download = download
        self.upload = upload
        self.latency = latency
        self.packetLoss = packetLoss
    }

    public var normalizedName: String {
        name.normalizedProfileName
    }
}
