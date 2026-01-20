import Foundation

// MARK: - Kiosk Configuration

struct KioskConfiguration: Codable, Sendable {
    var enableLockdown: Bool
    var hideDock: Bool
    var hideMenuBar: Bool
    var disableProcessSwitching: Bool
    var preventSleep: Bool
    var hideCursor: Bool
    var disableScreensaver: Bool
    
    init(
        enableLockdown: Bool = false,
        hideDock: Bool = true,
        hideMenuBar: Bool = true,
        disableProcessSwitching: Bool = true,
        preventSleep: Bool = true,
        hideCursor: Bool = false,
        disableScreensaver: Bool = true
    ) {
        self.enableLockdown = enableLockdown
        self.hideDock = hideDock
        self.hideMenuBar = hideMenuBar
        self.disableProcessSwitching = disableProcessSwitching
        self.preventSleep = preventSleep
        self.hideCursor = hideCursor
        self.disableScreensaver = disableScreensaver
    }
    
    static var disabled: KioskConfiguration {
        KioskConfiguration(enableLockdown: false)
    }
    
    static var fullLockdown: KioskConfiguration {
        KioskConfiguration(
            enableLockdown: true,
            hideDock: true,
            hideMenuBar: true,
            disableProcessSwitching: true,
            preventSleep: true,
            hideCursor: true,
            disableScreensaver: true
        )
    }
}

// MARK: - Kiosk Errors

enum KioskError: Error, LocalizedError, Sendable {
    case powerManagementFailed
    case dockConfigurationFailed
    case screensaverConfigurationFailed
    case lockdownFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .powerManagementFailed:
            return "Failed to configure power management"
        case .dockConfigurationFailed:
            return "Failed to configure Dock"
        case .screensaverConfigurationFailed:
            return "Failed to configure screensaver"
        case .lockdownFailed(let reason):
            return "Lockdown failed: \(reason)"
        }
    }
}
