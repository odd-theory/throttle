import Testing
@testable import ThrottleCore

@Test func parsesApplyCommand() throws {
    #expect(try CommandParser().parse(["apply", "LTE"]) == .apply("LTE", .foreground))
}

@Test func parsesApplyWithoutProfileForInteractiveSelection() throws {
    #expect(try CommandParser().parse(["apply"]) == .apply(nil, .foreground))
}

@Test func joinsUnquotedMultiWordProfileNames() throws {
    #expect(try CommandParser().parse(["apply", "Lossy", "Network"]) == .apply("Lossy Network", .foreground))
}

@Test func parsesDetachedApplyCommand() throws {
    #expect(try CommandParser().parse(["apply", "Lossy", "Network", "--detach"]) == .apply("Lossy Network", .detached))
}

@Test func parsesCustomCommand() throws {
    let command = try CommandParser().parse([
        "custom",
        "--download", "5mbit",
        "--upload", "1mbit",
        "--latency", "150ms",
        "--packet-loss", "1"
    ])

    guard case .custom(let profile, let mode) = command else {
        Issue.record("Expected custom command")
        return
    }

    #expect(mode == .foreground)
    #expect(profile.download.bitsPerSecond == 5_000_000)
    #expect(profile.upload.bitsPerSecond == 1_000_000)
    #expect(profile.latency.milliseconds == 150)
    #expect(profile.packetLoss.percent == 1)
}

@Test func parsesDetachedCustomCommand() throws {
    let command = try CommandParser().parse([
        "custom",
        "--download", "5mbit",
        "--upload", "1mbit",
        "--latency", "150ms",
        "--packet-loss", "1",
        "--detach"
    ])

    guard case .custom(_, let mode) = command else {
        Issue.record("Expected custom command")
        return
    }

    #expect(mode == .detached)
}

@Test func rejectsIncompleteCustomCommand() {
    #expect(throws: ThrottleError.self) {
        _ = try CommandParser().parse(["custom", "--download", "5mbit"])
    }
}
