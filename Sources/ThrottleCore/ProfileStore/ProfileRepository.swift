import Foundation

public enum ProfileSource: String, Codable, Equatable, Sendable {
    case bundled
    case saved
}

public struct ProfileRecord: Equatable, Sendable {
    public let profile: NetworkProfile
    public let source: ProfileSource
    public let url: URL
}

public final class ProfileRepository {
    private let fileManager: FileManager
    private let bundledDirectory: URL
    private let savedDirectory: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        bundledDirectory: URL,
        savedDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.bundledDirectory = bundledDirectory
        self.savedDirectory = savedDirectory
        self.fileManager = fileManager
        decoder = JSONDecoder()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    public static func live(fileManager: FileManager = .default) throws -> ProfileRepository {
        guard let bundledDirectory = Bundle.module.url(forResource: "Profiles", withExtension: nil) else {
            throw ThrottleError.fileSystem("Bundled Profiles directory is missing.")
        }
        let support = try fileManager.throttleApplicationSupportDirectory()
        let savedDirectory = support.appendingPathComponent("Profiles", isDirectory: true)
        return ProfileRepository(
            bundledDirectory: bundledDirectory,
            savedDirectory: savedDirectory,
            fileManager: fileManager
        )
    }

    public func allProfiles() throws -> [ProfileRecord] {
        var recordsByName: [String: ProfileRecord] = [:]
        for record in try loadProfiles(from: bundledDirectory, source: .bundled) {
            recordsByName[record.profile.normalizedName] = record
        }
        for record in try loadProfiles(from: savedDirectory, source: .saved) {
            recordsByName[record.profile.normalizedName] = record
        }
        return recordsByName.values.sorted {
            $0.profile.name.localizedCaseInsensitiveCompare($1.profile.name) == .orderedAscending
        }
    }

    public func findProfile(named name: String) throws -> ProfileRecord? {
        try allProfiles().first { $0.profile.normalizedName == name.normalizedProfileName }
    }

    public func save(profile: NetworkProfile, as name: String) throws -> ProfileRecord {
        try ensureSavedDirectory()
        let savedProfile = NetworkProfile(
            name: name,
            download: profile.download,
            upload: profile.upload,
            latency: profile.latency,
            packetLoss: profile.packetLoss
        )
        let url = savedDirectory.appendingPathComponent("\(name.profileFileName).json")
        let data = try encoder.encode(savedProfile)
        try data.write(to: url, options: .atomic)
        return ProfileRecord(profile: savedProfile, source: .saved, url: url)
    }

    public func deleteProfile(named name: String) throws {
        guard let record = try findProfile(named: name), record.source == .saved else {
            throw ThrottleError.invalidProfile(name)
        }
        try fileManager.removeItem(at: record.url)
    }

    private func loadProfiles(from directory: URL, source: ProfileSource) throws -> [ProfileRecord] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let jsonURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
        return try jsonURLs.map { url in
            let data = try Data(contentsOf: url)
            do {
                let profile = try decoder.decode(NetworkProfile.self, from: data)
                return ProfileRecord(profile: profile, source: source, url: url)
            } catch {
                throw ThrottleError.malformedProfile(path: url.path, reason: error.localizedDescription)
            }
        }
    }

    private func ensureSavedDirectory() throws {
        try fileManager.createDirectory(at: savedDirectory, withIntermediateDirectories: true)
    }
}
