import Foundation
import Testing
@testable import ThrottleCore

@Test func interactiveProfileSelectionUsesArrowKeysAndEnter() throws {
    var keys: [ProfileSelectionKey] = [.down, .down, .up, .enter]
    let selected = try ConsoleProfileSelector.selectInteractively(
        from: profileRecords(["EDGE", "LTE", "WiFi"]),
        readKey: { keys.removeFirst() },
        writeOutput: { _ in }
    )

    #expect(selected?.profile.name == "LTE")
}

@Test func interactiveProfileSelectionUsesNumberKeysToPreselect() throws {
    var keys: [ProfileSelectionKey] = [.digit(3), .enter]
    let selected = try ConsoleProfileSelector.selectInteractively(
        from: profileRecords(["EDGE", "LTE", "WiFi"]),
        readKey: { keys.removeFirst() },
        writeOutput: { _ in }
    )

    #expect(selected?.profile.name == "WiFi")
}

@Test func interactiveProfileSelectionCanSelectTwoDigitNumbers() throws {
    var keys: [ProfileSelectionKey] = [.digit(1), .digit(0), .enter]
    let selected = try ConsoleProfileSelector.selectInteractively(
        from: profileRecords([
            "Profile 1",
            "Profile 2",
            "Profile 3",
            "Profile 4",
            "Profile 5",
            "Profile 6",
            "Profile 7",
            "Profile 8",
            "Profile 9",
            "Profile 10"
        ]),
        readKey: { keys.removeFirst() },
        writeOutput: { _ in }
    )

    #expect(selected?.profile.name == "Profile 10")
}

private func profileRecords(_ names: [String]) throws -> [ProfileRecord] {
    try names.map { name in
        ProfileRecord(
            profile: NetworkProfile(
                name: name,
                download: try Bandwidth("1mbit"),
                upload: try Bandwidth("1mbit"),
                latency: try Latency("0ms"),
                packetLoss: try PacketLoss(rawValue: "0")
            ),
            source: .bundled,
            url: URL(fileURLWithPath: "/tmp/\(name.profileFileName).json")
        )
    }
}
