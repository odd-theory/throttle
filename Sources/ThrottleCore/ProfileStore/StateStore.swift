import Foundation

public final class StateStore {
    private let fileManager: FileManager
    private let statusURL: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder

    public init(statusURL: URL, fileManager: FileManager = .default) {
        self.statusURL = statusURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func live(fileManager: FileManager = .default) throws -> StateStore {
        let support = try fileManager.throttleApplicationSupportDirectory()
        return StateStore(statusURL: support.appendingPathComponent("status.json"), fileManager: fileManager)
    }

    public func load() throws -> ThrottleStatus {
        guard fileManager.fileExists(atPath: statusURL.path) else {
            return .inactive
        }
        let data = try Data(contentsOf: statusURL)
        do {
            return try decoder.decode(ThrottleStatus.self, from: data)
        } catch {
            throw ThrottleError.malformedProfile(path: statusURL.path, reason: error.localizedDescription)
        }
    }

    public func save(_ status: ThrottleStatus) throws {
        let directory = statusURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(status)
        try data.write(to: statusURL, options: .atomic)
    }
}
