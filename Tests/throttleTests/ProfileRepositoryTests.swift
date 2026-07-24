import Foundation
import Testing
@testable import ThrottleCore

@Test func savedProfilesOverrideBundledProfilesByName() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("throttle-tests-\(UUID().uuidString)", isDirectory: true)
    let bundled = root.appendingPathComponent("bundled", isDirectory: true)
    let saved = root.appendingPathComponent("saved", isDirectory: true)
    try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: saved, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try """
    {"name":"LTE","download":"50mbit","upload":"10mbit","latency":"60ms","packetLoss":0}
    """.write(to: bundled.appendingPathComponent("LTE.json"), atomically: true, encoding: .utf8)
    try """
    {"name":"LTE","download":"5mbit","upload":"1mbit","latency":"150ms","packetLoss":1}
    """.write(to: saved.appendingPathComponent("LTE.json"), atomically: true, encoding: .utf8)

    let repository = ProfileRepository(bundledDirectory: bundled, savedDirectory: saved)
    let foundRecord = try repository.findProfile(named: "lte")
    let record = try #require(foundRecord)
    #expect(record.source == .saved)
    #expect(record.profile.download.bitsPerSecond == 5_000_000)
}

@Test func partialProfileLookupMatchesSingleProfile() throws {
    let repository = try ProfileRepository.live()
    let record = try #require(try repository.findProfile(named: "lossy"))
    #expect(record.profile.name == "Lossy Network")
}

@Test func ambiguousPartialProfileLookupReportsMatches() throws {
    let repository = try ProfileRepository.live()

    #expect(throws: ThrottleError.self) {
        _ = try repository.findProfile(named: "network")
    }
}

@Test func bundledProfilesLoad() throws {
    let repository = try ProfileRepository.live()
    let names = try repository.allProfiles().map(\.profile.name)
    #expect(names.contains("EDGE"))
    #expect(names.contains("LTE"))
    #expect(names.contains("WiFi"))
    #expect(names.contains("Very Bad Network"))
    #expect(!names.contains("Coffee Shop WiFi"))
    #expect(!names.contains("Stadium"))
}
