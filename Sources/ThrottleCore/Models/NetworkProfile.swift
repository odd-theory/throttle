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

    /// A relative quality score used to order profiles from best to worst.
    public var qualityScore: Double {
        let downstream = Double(download.bitsPerSecond)
        let upstream = Double(upload.bitsPerSecond)

        if downstream <= 0 || upstream <= 0 {
            return -1_000_000 - (packetLoss.percent * 1_000)
        }

        if packetLoss.percent >= 100 {
            return -900_000 + log10(downstream + upstream)
        }

        let throughputScore = log10(downstream + upstream) * 100
        let latencyPenalty = Double(latency.milliseconds) * 0.35
        let lossPenalty = packetLoss.percent * 125
        return throughputScore - latencyPenalty - lossPenalty
    }
}
