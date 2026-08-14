import Foundation

public final class ThrottleService {
    private let profiles: ProfileRepository
    private let stateStore: StateStore
    private let networkController: NetworkControlling
    private let privileges: PrivilegeChecking
    private let formatter: OutputFormatter
    private let executableName: String
    private let profileSelector: ProfileSelecting
    private let foregroundSession: ForegroundSessionRunning

    public init(
        profiles: ProfileRepository,
        stateStore: StateStore,
        networkController: NetworkControlling,
        privileges: PrivilegeChecking,
        formatter: OutputFormatter = OutputFormatter(),
        executableName: String = "throttle",
        profileSelector: ProfileSelecting = ConsoleProfileSelector(),
        foregroundSession: ForegroundSessionRunning = ConsoleForegroundSession()
    ) {
        self.profiles = profiles
        self.stateStore = stateStore
        self.networkController = networkController
        self.privileges = privileges
        self.formatter = formatter
        self.executableName = executableName
        self.profileSelector = profileSelector
        self.foregroundSession = foregroundSession
    }

    public static func live(executableName: String = "throttle") throws -> ThrottleService {
        try ThrottleService(
            profiles: .live(),
            stateStore: .live(),
            networkController: DummynetNetworkController(),
            privileges: RootPrivilegeChecker(),
            executableName: executableName
        )
    }

    public func run(_ command: CLICommand) throws -> String {
        switch command {
        case .list:
            return formatter.list(try profiles.allProfiles())
        case .apply(let name, let mode):
            return try applyProfile(named: name, mode: mode)
        case .custom(let profile, let mode):
            return try apply(profile: profile, source: .custom, mode: mode)
        case .off:
            return try off()
        case .status:
            return formatter.status(try stateStore.load())
        case .save(let name):
            return try saveActiveCustomProfile(as: name)
        case .delete(let name):
            try profiles.deleteProfile(named: name)
            return formatter.deleted(name)
        case .help:
            return CommandParser.usage
        }
    }

    private func applyProfile(named name: String?, mode: ApplyMode) throws -> String {
        let record: ProfileRecord
        if let name {
            guard let foundRecord = try profiles.findProfile(named: name) else {
                throw ThrottleError.invalidProfile(name)
            }
            record = foundRecord
        } else {
            try requireRoot(command: "apply")
            let records = try profiles.allProfiles()
            guard let selectedRecord = try profileSelector.selectProfile(from: records) else {
                throw ThrottleError.invalidCommand("No profile selected.")
            }
            record = selectedRecord
        }

        let source: ThrottleStatus.Source = record.source == .saved ? .saved : .bundled
        return try apply(profile: record.profile, source: source, mode: mode)
    }

    private func apply(profile: NetworkProfile, source: ThrottleStatus.Source, mode: ApplyMode) throws -> String {
        try requireRoot(command: source == .custom ? "custom" : "apply \(profile.name)")
        let previousStatus = try stateStore.load()
        if previousStatus.isActive {
            try networkController.removeAll(pfToken: previousStatus.pfToken)
        }
        let token = try networkController.apply(profile)
        try stateStore.save(ThrottleStatus(
            isActive: true,
            profile: profile,
            source: source,
            appliedAt: Date(),
            pfToken: token
        ))

        if mode == .detached {
            return formatter.applied(profile)
        }

        return try foregroundSession.run(profile: profile, startedAt: Date()) { [networkController, stateStore] in
            try networkController.removeAll(pfToken: token)
            try stateStore.save(.inactive)
        }
    }

    private func off() throws -> String {
        try requireRoot(command: "off")
        let status = try stateStore.load()
        try networkController.removeAll(pfToken: status.pfToken)
        try stateStore.save(.inactive)
        return formatter.disabled()
    }

    private func saveActiveCustomProfile(as name: String) throws -> String {
        let status = try stateStore.load()
        guard status.isActive,
              status.source == .custom,
              let profile = status.profile else {
            throw ThrottleError.noActiveCustomProfile
        }
        let record = try profiles.save(profile: profile, as: name)
        return formatter.saved(record.profile)
    }

    private func requireRoot(command: String) throws {
        guard privileges.isRoot else {
            throw ThrottleError.missingPrivileges(command: command, executable: executableName)
        }
    }
}
