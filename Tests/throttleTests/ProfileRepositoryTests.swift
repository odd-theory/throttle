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

@Test func profilesSortFromBestConnectionToWorstConnection() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("throttle-order-tests-\(UUID().uuidString)", isDirectory: true)
    let bundled = root.appendingPathComponent("bundled", isDirectory: true)
    let saved = root.appendingPathComponent("saved", isDirectory: true)
    try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let profiles = [
        #"{"name":"Offline","download":"0bit","upload":"0bit","latency":"0ms","packetLoss":100}"#,
        #"{"name":"EDGE","download":"240kbit","upload":"100kbit","latency":"400ms","packetLoss":1}"#,
        #"{"name":"LTE","download":"50mbit","upload":"10mbit","latency":"60ms","packetLoss":0.1}"#,
        #"{"name":"WiFi","download":"100mbit","upload":"20mbit","latency":"20ms","packetLoss":0}"#,
        #"{"name":"Lossy Network","download":"10mbit","upload":"2mbit","latency":"150ms","packetLoss":5}"#,
        #"{"name":"100% Loss","download":"1mbit","upload":"1mbit","latency":"0ms","packetLoss":100}"#
    ]

    for (index, profile) in profiles.enumerated() {
        try profile.write(
            to: bundled.appendingPathComponent("\(index).json"),
            atomically: true,
            encoding: .utf8
        )
    }

    let repository = ProfileRepository(bundledDirectory: bundled, savedDirectory: saved)
    let names = try repository.allProfiles().map(\.profile.name)

    #expect(names == [
        "WiFi",
        "LTE",
        "EDGE",
        "Lossy Network",
        "100% Loss",
        "Offline"
    ])
}
