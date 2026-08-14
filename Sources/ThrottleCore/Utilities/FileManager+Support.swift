import Foundation
import Darwin

extension FileManager {
    func throttleApplicationSupportDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        if let sudoUser = environment["SUDO_USER"],
           !sudoUser.isEmpty,
           sudoUser != "root",
           let homeDirectory = Self.homeDirectory(forUser: sudoUser) {
            return URL(fileURLWithPath: homeDirectory)
                .appendingPathComponent("Library/Application Support/throttle", isDirectory: true)
        }

        guard let base = urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ThrottleError.fileSystem("Unable to locate Application Support.")
        }
        return base.appendingPathComponent("throttle", isDirectory: true)
    }

    private static func homeDirectory(forUser username: String) -> String? {
        username.withCString { pointer in
            guard let passwd = getpwnam(pointer),
                  let directory = passwd.pointee.pw_dir else {
                return nil
            }
            return String(cString: directory)
        }
    }
}
