import Testing
@testable import ThrottleCore

@Test func parsesBandwidthUnits() throws {
    #expect(try Bandwidth("5mbit").bitsPerSecond == 5_000_000)
    #expect(try Bandwidth("768kbit").bitsPerSecond == 768_000)
    #expect(try Bandwidth("1.5mbit").bitsPerSecond == 1_500_000)
    #expect(try Bandwidth("0bit").bitsPerSecond == 0)
}

@Test func rejectsInvalidBandwidthUnits() {
    #expect(throws: ThrottleError.self) {
        _ = try Bandwidth("fast")
    }
}

@Test func parsesLatency() throws {
    #expect(try Latency("150ms").milliseconds == 150)
}

@Test func parsesPacketLoss() throws {
    #expect(try PacketLoss(rawValue: "2").percent == 2)
    #expect(try PacketLoss(rawValue: "2.5%").percent == 2.5)
}

@Test func rejectsPacketLossOutsidePercentageRange() {
    #expect(throws: ThrottleError.self) {
        _ = try PacketLoss(rawValue: "101")
    }
}
