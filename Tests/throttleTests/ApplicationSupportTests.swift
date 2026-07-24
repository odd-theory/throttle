import Foundation
import Testing
@testable import ThrottleCore

@Test func applicationSupportUsesInvokingUserWhenRunWithSudo() throws {
    let username = NSUserName()
    let directory = try FileManager.default.throttleApplicationSupportDirectory(
        environment: ["SUDO_USER": username]
    )

    #expect(directory.path.hasSuffix("/Library/Application Support/throttle"))
    #expect(!directory.path.hasPrefix("/var/root/"))
}
