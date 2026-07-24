import Foundation
import Testing
@testable import ThrottleCore

private struct AlwaysRoot: PrivilegeChecking {
    let isRoot = true
}

private final class FakeNetworkController: NetworkControlling {
    var appliedProfiles: [NetworkProfile] = []

    func apply(_ profile: NetworkProfile) throws -> String? {
        appliedProfiles.append(profile)
        return "12345"
    }

    func removeAll(pfToken: String?) throws {}
}

private struct SelectingFirstProfile: ProfileSelecting {
    func selectProfile(from records: [ProfileRecord]) throws -> ProfileRecord? {
        records.first
    }
}

@Test func applyWithoutProfileUsesInteractiveSelection() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("throttle-service-tests-\(UUID().uuidString)", isDirectory: true)
    let bundled = root.appendingPathComponent("bundled", isDirectory: true)
    let saved = root.appendingPathComponent("saved", isDirectory: true)
    let statusURL = root.appendingPathComponent("status.json")
    try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try """
    {"name":"LTE","download":"50mbit","upload":"10mbit","latency":"60ms","packetLoss":0}
    """.write(to: bundled.appendingPathComponent("LTE.json"), atomically: true, encoding: .utf8)

    let network = FakeNetworkController()
    let service = ThrottleService(
        profiles: ProfileRepository(bundledDirectory: bundled, savedDirectory: saved),
        stateStore: StateStore(statusURL: statusURL),
        networkController: network,
        privileges: AlwaysRoot(),
        profileSelector: SelectingFirstProfile()
    )

    let output = try service.run(.apply(nil))

    #expect(output == "Applied profile: LTE")
    #expect(network.appliedProfiles.map(\.name) == ["LTE"])
}
