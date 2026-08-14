import Darwin

public protocol PrivilegeChecking {
    var isRoot: Bool { get }
}

public struct RootPrivilegeChecker: PrivilegeChecking {
    public init() {}

    public var isRoot: Bool {
        geteuid() == 0
    }
}
