import Foundation
import Security

// MARK: - Authentication Service

final class AuthenticationService: Sendable {
    static let shared = AuthenticationService()

    /// Presents the macOS admin authentication dialog.
    /// Returns true if the user successfully authenticates as an administrator.
    func requestAdminAuthentication() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.performAuth())
            }
        }
    }

    private static func performAuth() -> Bool {
        var authRef: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &authRef)
        guard createStatus == errAuthorizationSuccess, let auth = authRef else {
            return false
        }
        defer { AuthorizationFree(auth, []) }

        return "system.privilege.admin".withCString { rightName in
            var item = AuthorizationItem(
                name: rightName,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                let flags: AuthorizationFlags = [.interactionAllowed, .extendRights]
                let status = AuthorizationCopyRights(auth, &rights, nil, flags, nil)
                return status == errAuthorizationSuccess
            }
        }
    }
}
