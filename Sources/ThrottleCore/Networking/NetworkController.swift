import Foundation

public protocol NetworkControlling {
    func apply(_ profile: NetworkProfile) throws -> String?
    func removeAll(pfToken: String?) throws
}

public final class DummynetNetworkController: NetworkControlling {
    public static let anchorName = "com.apple/throttle"
    public static let downloadPipe = 12001
    public static let uploadPipe = 12002

    private let runner: ShellRunning
    private let fileManager: FileManager
    private let temporaryDirectory: URL

    public init(
        runner: ShellRunning = ProcessShellRunner(),
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.runner = runner
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
    }

    public func apply(_ profile: NetworkProfile) throws -> String? {
        var pfToken: String?
        do {
            try removeAll(pfToken: nil)
            try configurePipes(for: profile)
            try loadAnchorRules()
            pfToken = try enablePacketFilter()
            return pfToken
        } catch {
            try? removeAll(pfToken: pfToken)
            throw ThrottleError.applyFailed("\(error)")
        }
    }

    public func removeAll(pfToken: String?) throws {
        try run("/sbin/pfctl", ["-a", Self.anchorName, "-F", "all"])
        try deletePipeIfPresent(Self.downloadPipe)
        try deletePipeIfPresent(Self.uploadPipe)
        if let pfToken, !pfToken.isEmpty {
            try run("/sbin/pfctl", ["-X", pfToken])
        }
    }

    public func generatedRules() -> String {
        """
        dummynet in quick all pipe \(Self.downloadPipe)
        dummynet out quick all pipe \(Self.uploadPipe)
        """
    }

    private func configurePipes(for profile: NetworkProfile) throws {
        try run("/usr/sbin/dnctl", pipeArguments(
            pipe: Self.downloadPipe,
            bandwidth: profile.download,
            latency: profile.latency,
            packetLoss: profile.packetLoss
        ))
        try run("/usr/sbin/dnctl", pipeArguments(
            pipe: Self.uploadPipe,
            bandwidth: profile.upload,
            latency: profile.latency,
            packetLoss: profile.packetLoss
        ))
    }

    private func pipeArguments(
        pipe: Int,
        bandwidth: Bandwidth,
        latency: Latency,
        packetLoss: PacketLoss
    ) -> [String] {
        [
            "pipe",
            "\(pipe)",
            "config",
            "bw",
            bandwidth.dummynetValue,
            "delay",
            latency.dummynetValue,
            "plr",
            packetLoss.dummynetProbability
        ]
    }

    private func loadAnchorRules() throws {
        let rulesURL = temporaryDirectory.appendingPathComponent("throttle-\(UUID().uuidString).pf.conf")
        try generatedRules().write(to: rulesURL, atomically: true, encoding: .utf8)
        defer {
            try? fileManager.removeItem(at: rulesURL)
        }
        try run("/sbin/pfctl", ["-a", Self.anchorName, "-f", rulesURL.path])
    }

    private func enablePacketFilter() throws -> String? {
        let result = try run("/sbin/pfctl", ["-E"])
        return Self.extractToken(from: result.output)
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        let result = try runner.run(executable, arguments)
        guard result.succeeded else {
            throw ThrottleError.commandFailed(
                command: result.command,
                status: result.status,
                output: result.output
            )
        }
        return result
    }

    private func deletePipeIfPresent(_ pipe: Int) throws {
        let arguments = ["pipe", "delete", "\(pipe)"]
        let result = try runner.run("/usr/sbin/dnctl", arguments)
        if result.succeeded || Self.isMissingPipeDeleteFailure(result.output) {
            return
        }

        throw ThrottleError.commandFailed(
            command: result.command,
            status: result.status,
            output: result.output
        )
    }

    static func isMissingPipeDeleteFailure(_ output: String) -> Bool {
        output.contains("IP_DUMMYNET_DEL") && output.contains("Invalid argument")
    }

    static func extractToken(from output: String) -> String? {
        let pattern = #"Token\s*:\s*([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let tokenRange = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return String(output[tokenRange])
    }
}
