import Foundation

public final class ThrottleService {
    private let profiles: ProfileRepository
    private let stateStore: StateStore
    private let networkController: NetworkControlling
    private let privileges: PrivilegeChecking
    private let formatter: OutputFormatter

    public init(
        profiles: ProfileRepository,
        stateStore: StateStore,
        networkController: NetworkControlling,
        privileges: PrivilegeChecking,
        formatter: OutputFormatter = OutputFormatter()
    ) {
        self.profiles = profiles
        self.stateStore = stateStore
        self.networkController = networkController
        self.privileges = privileges
        self.formatter = formatter
    }

    public static func live() throws -> ThrottleService {
        try ThrottleService(
            profiles: .live(),
            stateStore: .live(),
            networkController: DummynetNetworkController(),
            privileges: RootPrivilegeChecker()
        )
    }

    public func run(_ command: CLICommand) throws -> String {
        switch command {
        case .list:
            return formatter.list(try profiles.allProfiles())
        case .apply(let name):
            return try applyProfile(named: name)
        case .custom(let profile):
            return try apply(profile: profile, source: .custom)
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

    private func applyProfile(named name: String) throws -> String {
        guard let record = try profiles.findProfile(named: name) else {
            throw ThrottleError.invalidProfile(name)
        }
        let source: ThrottleStatus.Source = record.source == .saved ? .saved : .bundled
        return try apply(profile: record.profile, source: source)
    }

    private func apply(profile: NetworkProfile, source: ThrottleStatus.Source) throws -> String {
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
        return formatter.applied(profile)
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
            throw ThrottleError.missingPrivileges(command: command)
        }
    }
}
