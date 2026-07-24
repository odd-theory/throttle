import Foundation
import Testing
@testable import ThrottleCore

@Test func foregroundSessionRenderShowsActiveProfileAndExitHint() throws {
    let profile = NetworkProfile(
        name: "LTE",
        download: try Bandwidth("50mbit"),
        upload: try Bandwidth("10mbit"),
        latency: try Latency("60ms"),
        packetLoss: try PacketLoss(rawValue: "0.1")
    )

    let startedAt = Date(timeIntervalSince1970: 0)
    let output = ConsoleForegroundSession.render(
        profile: profile,
        startedAt: startedAt,
        now: Date(timeIntervalSince1970: 65)
    )

    #expect(output.contains("Status: active"))
    #expect(output.contains("Profile: LTE"))
    #expect(output.contains("Elapsed: 1:05"))
    #expect(output.contains("Press Ctrl-C to disable throttling."))
}
