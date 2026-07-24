import Foundation

public struct OutputFormatter {
    public init() {}

    public func list(_ records: [ProfileRecord]) -> String {
        guard !records.isEmpty else {
            return "No profiles found."
        }

        return records.map { record in
            let marker = record.source == .saved ? "saved" : "built-in"
            return "\(record.profile.name)  [\(marker)]"
        }
        .joined(separator: "\n")
    }

    public func status(_ status: ThrottleStatus) -> String {
        guard status.isActive, let profile = status.profile else {
            return "Status: inactive"
        }

        return """
        Status: active
        Profile: \(profile.name)
        Download: \(profile.download)
        Upload: \(profile.upload)
        Latency: \(profile.latency)
        Packet Loss: \(profile.packetLoss)
        """
    }

    public func applied(_ profile: NetworkProfile) -> String {
        "Applied profile: \(profile.name)"
    }

    public func disabled() -> String {
        "Throttling disabled."
    }

    public func saved(_ profile: NetworkProfile) -> String {
        "Saved profile: \(profile.name)"
    }

    public func deleted(_ name: String) -> String {
        "Deleted profile: \(name)"
    }
}
