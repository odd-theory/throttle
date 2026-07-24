import Foundation

/// User-facing errors raised by the CLI.
public enum ThrottleError: Error, CustomStringConvertible, Equatable {
    case invalidCommand(String)
    case invalidArgument(String)
    case invalidUnit(String)
    case invalidProfile(String)
    case malformedProfile(path: String, reason: String)
    case missingPrivileges(command: String)
    case commandFailed(command: String, status: Int32, output: String)
    case applyFailed(String)
    case noActiveCustomProfile
    case fileSystem(String)

    public var description: String {
        switch self {
        case .invalidCommand(let message):
            return message
        case .invalidArgument(let message):
            return message
        case .invalidUnit(let value):
            return "Invalid unit: \(value)"
        case .invalidProfile(let name):
            return "Unknown profile: \(name)"
        case .malformedProfile(let path, let reason):
            return "Malformed profile JSON at \(path): \(reason)"
        case .missingPrivileges(let command):
            return "Missing privileges. Run `sudo throttle \(command)` to change network rules."
        case .commandFailed(let command, let status, let output):
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOutput.isEmpty {
                return "`\(command)` failed with exit code \(status)."
            }
            return "`\(command)` failed with exit code \(status): \(trimmedOutput)"
        case .applyFailed(let message):
            return "Failed to apply throttling: \(message)"
        case .noActiveCustomProfile:
            return "There is no active custom profile to save."
        case .fileSystem(let message):
            return message
        }
    }
}
