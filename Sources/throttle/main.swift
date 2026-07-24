import Foundation
import ThrottleCore

do {
    let command = try CommandParser().parse(Array(CommandLine.arguments.dropFirst()))
    let service = try ThrottleService.live(executableName: CommandLine.arguments.first ?? "throttle")
    let output = try service.run(command)
    print(output)
} catch let error as ThrottleError {
    fputs("throttle: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("throttle: \(error.localizedDescription)\n", stderr)
    exit(1)
}
