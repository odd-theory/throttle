import Foundation
import Dispatch
import Darwin

public protocol ForegroundSessionRunning {
    func run(profile: NetworkProfile, startedAt: Date, stop: @escaping () throws -> Void) throws -> String
}

public final class ConsoleForegroundSession: ForegroundSessionRunning {
    private let writeOutput: (String) -> Void
    private let now: () -> Date

    public init(
        writeOutput: @escaping (String) -> Void = {
            fputs($0, stdout)
            fflush(stdout)
        },
        now: @escaping () -> Date = { Date() }
    ) {
        self.writeOutput = writeOutput
        self.now = now
    }

    public func run(
        profile: NetworkProfile,
        startedAt: Date,
        stop: @escaping () throws -> Void
    ) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "throttle.foreground-session")

        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        let terminateSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)
        interruptSource.setEventHandler { semaphore.signal() }
        terminateSource.setEventHandler { semaphore.signal() }
        interruptSource.resume()
        terminateSource.resume()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [writeOutput, now] in
            writeOutput(Self.render(profile: profile, startedAt: startedAt, now: now()))
        }
        timer.resume()

        semaphore.wait()

        timer.cancel()
        interruptSource.cancel()
        terminateSource.cancel()

        writeOutput("\u{001B}[2J\u{001B}[HStopping throttle...\n")
        try stop()
        return "Throttling disabled."
    }

    public static func render(profile: NetworkProfile, startedAt: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
        return """
        \u{001B}[2J\u{001B}[Hthrottle
        Status: active
        Profile: \(profile.name)
        Elapsed: \(formatElapsed(seconds: elapsed))

        Download: \(profile.download)
        Upload: \(profile.upload)
        Latency: \(profile.latency)
        Packet Loss: \(profile.packetLoss)

        Press Ctrl-C to disable throttling.
        """
    }

    private static func formatElapsed(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
