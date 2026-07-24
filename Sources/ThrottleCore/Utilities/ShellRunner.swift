import Foundation

public struct ShellResult: Equatable, Sendable {
    public let command: String
    public let status: Int32
    public let output: String

    public var succeeded: Bool {
        status == 0
    }
}

public protocol ShellRunning {
    func run(_ executable: String, _ arguments: [String]) throws -> ShellResult
}

public final class ProcessShellRunner: ShellRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw ThrottleError.commandFailed(
                command: Self.commandLine(executable, arguments),
                status: -1,
                output: error.localizedDescription
            )
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return ShellResult(
            command: Self.commandLine(executable, arguments),
            status: process.terminationStatus,
            output: output
        )
    }

    public static func commandLine(_ executable: String, _ arguments: [String]) -> String {
        ([executable] + arguments).joined(separator: " ")
    }
}
