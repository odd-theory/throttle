import Foundation
import Testing
@testable import ThrottleCore

private final class RecordingRunner: ShellRunning {
    var commands: [String] = []
    var outputs: [String] = []
    var statuses: [Int32] = []

    func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        commands.append(ProcessShellRunner.commandLine(executable, arguments))
        let output = outputs.isEmpty ? "" : outputs.removeFirst()
        let status = statuses.isEmpty ? 0 : statuses.removeFirst()
        return ShellResult(
            command: ProcessShellRunner.commandLine(executable, arguments),
            status: status,
            output: output
        )
    }
}

@Test func appliesDummynetPipesAndPfAnchor() throws {
    let runner = RecordingRunner()
    runner.outputs = ["", "", "", "", "", "", "Token : 12345\n"]
    let controller = DummynetNetworkController(runner: runner)
    let profile = NetworkProfile(
        name: "Test",
        download: try Bandwidth("5mbit"),
        upload: try Bandwidth("1mbit"),
        latency: try Latency("150ms"),
        packetLoss: try PacketLoss(rawValue: "2")
    )

    let token = try controller.apply(profile)

    #expect(token == "12345")
    #expect(runner.commands.contains("/usr/sbin/dnctl pipe 12001 config bw 5Mbit/s delay 150ms plr 0.020000"))
    #expect(runner.commands.contains("/usr/sbin/dnctl pipe 12002 config bw 1Mbit/s delay 150ms plr 0.020000"))
    #expect(runner.commands.contains { $0.hasPrefix("/sbin/pfctl -a com.apple/throttle -f ") })
    #expect(runner.commands.contains("/sbin/pfctl -E"))
}

@Test func removeAllIgnoresMissingThrottlePipes() throws {
    let runner = RecordingRunner()
    runner.statuses = [0, 1, 1]
    runner.outputs = [
        "",
        "dnctl: rule 12001: setsockopt(IP_DUMMYNET_DEL): Invalid argument\n",
        "dnctl: rule 12002: setsockopt(IP_DUMMYNET_DEL): Invalid argument\n"
    ]
    let controller = DummynetNetworkController(runner: runner)

    try controller.removeAll(pfToken: nil)

    #expect(runner.commands == [
        "/sbin/pfctl -a com.apple/throttle -F all",
        "/usr/sbin/dnctl pipe delete 12001",
        "/usr/sbin/dnctl pipe delete 12002"
    ])
}

@Test func generatedPfRulesEndWithTrailingNewline() {
    let rules = DummynetNetworkController().generatedRules()

    #expect(rules.hasSuffix("\n"))
    #expect(rules.contains("dummynet in quick all pipe 12001\n"))
    #expect(rules.contains("dummynet out quick all pipe 12002\n"))
}

@Test func extractsPfEnableToken() {
    #expect(DummynetNetworkController.extractToken(from: "Token : 12345\n") == "12345")
}
