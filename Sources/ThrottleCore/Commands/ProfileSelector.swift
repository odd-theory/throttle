import Foundation
import Darwin

public enum ProfileSelectionKey: Equatable {
    case up
    case down
    case enter
    case digit(Int)
    case quit
    case escape
    case other
}

public protocol ProfileSelecting {
    func selectProfile(from records: [ProfileRecord]) throws -> ProfileRecord?
}

public struct ConsoleProfileSelector: ProfileSelecting {
    private let readLineInput: () -> String?
    private let readKeyInput: () -> ProfileSelectionKey
    private let writeOutput: (String) -> Void
    private let isInteractiveTerminal: () -> Bool
    private let usesRawMode: Bool

    public init(
        readLineInput: @escaping () -> String? = { readLine() },
        readKeyInput: @escaping () -> ProfileSelectionKey = { Self.readTerminalKey() },
        writeOutput: @escaping (String) -> Void = {
            fputs($0, stdout)
            fflush(stdout)
        },
        isInteractiveTerminal: @escaping () -> Bool = { isatty(STDIN_FILENO) == 1 },
        usesRawMode: Bool = true
    ) {
        self.readLineInput = readLineInput
        self.readKeyInput = readKeyInput
        self.writeOutput = writeOutput
        self.isInteractiveTerminal = isInteractiveTerminal
        self.usesRawMode = usesRawMode
    }

    public func selectProfile(from records: [ProfileRecord]) throws -> ProfileRecord? {
        guard !records.isEmpty else {
            return nil
        }

        if isInteractiveTerminal() {
            let selection = {
                try Self.selectInteractively(
                    from: records,
                    readKey: readKeyInput,
                    writeOutput: writeOutput
                )
            }
            return usesRawMode ? try Self.withRawTerminal(selection) : try selection()
        }

        return try selectFromLineInput(records)
    }

    private func selectFromLineInput(_ records: [ProfileRecord]) throws -> ProfileRecord? {
        writeOutput("Available profiles:\n")
        for (index, record) in records.enumerated() {
            writeOutput("  \(index + 1). \(record.profile.name)\n")
        }
        writeOutput("Choose a profile by number or name: ")

        guard let input = readLineInput()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else {
            return nil
        }

        if let selectedIndex = Int(input),
           records.indices.contains(selectedIndex - 1) {
            return records[selectedIndex - 1]
        }

        return try Self.matchProfile(named: input, in: records)
    }

    public static func selectInteractively(
        from records: [ProfileRecord],
        readKey: () -> ProfileSelectionKey,
        writeOutput: (String) -> Void
    ) throws -> ProfileRecord? {
        var selectedIndex = 0
        var renderedLineCount = 0
        var numericBuffer = ""

        func render() {
            let lineEnding = "\r\n"

            if renderedLineCount > 0 {
                writeOutput("\r\u{001B}[\(renderedLineCount)A")
                writeOutput("\u{001B}[J")
            }

            var lines: [String] = [
                "Available profiles",
                "Use Up/Down, number keys, and Enter. Press q to cancel.",
                ""
            ]

            for (index, record) in records.enumerated() {
                let prefix = index == selectedIndex ? "> " : "  "
                lines.append("\(prefix)\(index + 1). \(record.profile.name)")
            }

            if !numericBuffer.isEmpty {
                lines.append("")
                lines.append("Selected number: \(numericBuffer)")
            }

            let output = lines.joined(separator: lineEnding) + lineEnding
            renderedLineCount = lines.count
            writeOutput(output)
        }

        render()

        while true {
            switch readKey() {
            case .up:
                numericBuffer = ""
                selectedIndex = max(records.startIndex, selectedIndex - 1)
                render()
            case .down:
                numericBuffer = ""
                selectedIndex = min(records.index(before: records.endIndex), selectedIndex + 1)
                render()
            case .digit(let digit):
                numericBuffer.append(String(digit))
                if let index = Int(numericBuffer), (1...records.count).contains(index) {
                    selectedIndex = index - 1
                } else {
                    numericBuffer = String(digit)
                    if let index = Int(numericBuffer), (1...records.count).contains(index) {
                        selectedIndex = index - 1
                    }
                }
                render()
            case .enter:
                writeOutput("\r\n")
                return records[selectedIndex]
            case .quit, .escape:
                writeOutput("\r\n")
                return nil
            case .other:
                break
            }
        }
    }

    public static func matchProfile(named name: String, in records: [ProfileRecord]) throws -> ProfileRecord? {
        let normalizedName = name.normalizedProfileName
        guard !normalizedName.isEmpty else {
            return nil
        }

        if let exactMatch = records.first(where: { $0.profile.normalizedName == normalizedName }) {
            return exactMatch
        }

        let partialMatches = records.filter {
            $0.profile.normalizedName.contains(normalizedName)
        }

        if partialMatches.count == 1 {
            return partialMatches[0]
        }

        if partialMatches.count > 1 {
            throw ThrottleError.ambiguousProfile(
                name: name,
                matches: partialMatches.map(\.profile.name)
            )
        }

        return nil
    }

    private static func withRawTerminal<T>(_ body: () throws -> T) throws -> T {
        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            return try body()
        }

        var raw = original
        cfmakeraw(&raw)
        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else {
            return try body()
        }

        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &original)
        }

        return try body()
    }

    public static func readTerminalKey() -> ProfileSelectionKey {
        guard let byte = readByte() else {
            return .other
        }

        switch byte {
        case 10, 13:
            return .enter
        case 27:
            guard let first = readByte(timeoutMilliseconds: 50) else {
                return .escape
            }
            guard first == 91, let second = readByte(timeoutMilliseconds: 50) else {
                return .escape
            }
            switch second {
            case 65:
                return .up
            case 66:
                return .down
            default:
                return .other
            }
        case 48...57:
            return .digit(Int(byte - 48))
        case 81, 113:
            return .quit
        default:
            return .other
        }
    }

    private static func readByte(timeoutMilliseconds: Int32? = nil) -> UInt8? {
        if let timeoutMilliseconds {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, timeoutMilliseconds) > 0 else {
                return nil
            }
        }

        var byte: UInt8 = 0
        guard Darwin.read(STDIN_FILENO, &byte, 1) == 1 else {
            return nil
        }
        return byte
    }
}
