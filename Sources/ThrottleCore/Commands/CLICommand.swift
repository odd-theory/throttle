import Foundation

public enum CLICommand: Equatable {
    case list
    case apply(String?)
    case off
    case status
    case custom(NetworkProfile)
    case save(String)
    case delete(String)
    case help
}

public struct CommandParser {
    public init() {}

    public func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else {
            return .help
        }

        let rest = Array(arguments.dropFirst())
        switch command {
        case "list":
            try expectNoArguments(rest, command: "list")
            return .list
        case "apply":
            return .apply(joinedValue(rest))
        case "off":
            try expectNoArguments(rest, command: "off")
            return .off
        case "status":
            try expectNoArguments(rest, command: "status")
            return .status
        case "custom":
            return try .custom(parseCustom(rest))
        case "save":
            guard let profileName = joinedValue(rest) else {
                throw ThrottleError.invalidCommand("Usage: throttle save <name>")
            }
            return .save(profileName)
        case "delete":
            guard let profileName = joinedValue(rest) else {
                throw ThrottleError.invalidCommand("Usage: throttle delete <name>")
            }
            return .delete(profileName)
        case "help", "--help", "-h":
            return .help
        default:
            throw ThrottleError.invalidCommand("Unknown command: \(command)\n\n\(Self.usage)")
        }
    }

    private func expectNoArguments(_ arguments: [String], command: String) throws {
        guard arguments.isEmpty else {
            throw ThrottleError.invalidCommand("Usage: throttle \(command)")
        }
    }

    private func joinedValue(_ arguments: [String]) -> String? {
        let value = arguments.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func parseCustom(_ arguments: [String]) throws -> NetworkProfile {
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            guard option.hasPrefix("--") else {
                throw ThrottleError.invalidArgument("Unexpected argument: \(option)")
            }
            let key = String(option.dropFirst(2))
            guard ["download", "upload", "latency", "packet-loss"].contains(key) else {
                throw ThrottleError.invalidArgument("Unknown option: \(option)")
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw ThrottleError.invalidArgument("Missing value for \(option)")
            }
            guard values[key] == nil else {
                throw ThrottleError.invalidArgument("Duplicate option: \(option)")
            }
            values[key] = arguments[valueIndex]
            index += 2
        }

        guard let download = values["download"],
              let upload = values["upload"],
              let latency = values["latency"],
              let packetLoss = values["packet-loss"] else {
            throw ThrottleError.invalidCommand(
                "Usage: throttle custom --download <rate> --upload <rate> --latency <ms> --packet-loss <percent>"
            )
        }

        return NetworkProfile(
            name: "Custom",
            download: try Bandwidth(download),
            upload: try Bandwidth(upload),
            latency: try Latency(latency),
            packetLoss: try PacketLoss(rawValue: packetLoss)
        )
    }

    public static let usage = """
    Usage:
      throttle list
      throttle apply <profile>
      throttle custom --download <rate> --upload <rate> --latency <ms> --packet-loss <percent>
      throttle status
      throttle off
      throttle save <name>
      throttle delete <name>

    Examples:
      throttle apply LTE
      throttle custom --download 5mbit --upload 1mbit --latency 150ms --packet-loss 1
    """
}
