import AppKit
import IOKit.pwr_mgt

// MARK: - Kiosk Service

actor KioskService {
    static let shared = KioskService()
    
    private var powerAssertion: IOPMAssertionID = 0
    private var isLocked = false
    private var originalDockSettings: DockSettings?
    
    // MARK: - Lockdown
    
    func enableLockdown(config: KioskConfiguration) async throws {
        guard config.enableLockdown else { return }
        
        await MainActor.run {
            // Set presentation options
            var options: NSApplication.PresentationOptions = []
        
        if config.hideDock {
            options.insert(.hideDock)
        }
        
        if config.hideMenuBar {
            options.insert(.hideMenuBar)
            options.insert(.disableMenuBarTransparency)
        }
        
        if config.disableProcessSwitching {
            options.insert(.disableProcessSwitching)
            options.insert(.disableForceQuit)
            options.insert(.disableSessionTermination)
            options.insert(.disableHideApplication)
        }
        
        NSApp.presentationOptions = options
        }
        
        if config.hideCursor {
            await hideCursor()
        }
        
        // Screensaver
        if config.disableScreensaver {
            try await disableScreensaver()
        }
    }
    
    func disableLockdown() async {
        await MainActor.run {
            NSApp.presentationOptions = []
        }
        isLocked = false
        
        await allowSleep()
        await showCursor()
        await restoreDockSettings()
    }
    
    // MARK: - Power Management
    
    func preventSleep(reason: String = "Plinth Kiosk Mode") async throws {
        guard powerAssertion == 0 else { return }
        
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &powerAssertion
        )
        
        guard result == kIOReturnSuccess else {
            throw KioskError.powerManagementFailed
        }
    }
    
    func allowSleep() async {
        if powerAssertion != 0 {
            IOPMAssertionRelease(powerAssertion)
            powerAssertion = 0
        }
    }
    
    // MARK: - Cursor
    
    @MainActor
    func hideCursor() async {
        NSCursor.hide()
    }
    
    @MainActor
    func showCursor() async {
        NSCursor.unhide()
    }
    
    // MARK: - Dock Configuration
    
    private struct DockSettings: Sendable {
        let autohide: Bool
        let autohideDelay: Double
    }
    
    func configureDock(hidden: Bool, autohideDelay: Double = 0) async throws {
        // Save original settings
        if originalDockSettings == nil {
            let currentAutohide = UserDefaults.standard.bool(forKey: "com.apple.dock.autohide")
            let currentDelay = UserDefaults.standard.double(forKey: "com.apple.dock.autohide-delay")
            originalDockSettings = DockSettings(autohide: currentAutohide, autohideDelay: currentDelay)
        }
        
        // Apply new settings via defaults command
        try await runDefaults(["write", "com.apple.dock", "autohide", "-bool", hidden ? "true" : "false"])
        
        if hidden {
            try await runDefaults(["write", "com.apple.dock", "autohide-delay", "-float", String(autohideDelay)])
            try await runDefaults(["write", "com.apple.dock", "autohide-time-modifier", "-float", "0"])
        }
        
        // Restart Dock
        try await runCommand("/usr/bin/killall", arguments: ["Dock"])
    }
    
    private func restoreDockSettings() async {
        guard let settings = originalDockSettings else { return }
        
        try? await runDefaults(["write", "com.apple.dock", "autohide", "-bool", settings.autohide ? "true" : "false"])
        try? await runDefaults(["write", "com.apple.dock", "autohide-delay", "-float", String(settings.autohideDelay)])
        try? await runDefaults(["delete", "com.apple.dock", "autohide-time-modifier"])
        try? await runCommand("/usr/bin/killall", arguments: ["Dock"])
        
        originalDockSettings = nil
    }
    
    // MARK: - Screensaver
    
    func disableScreensaver() async throws {
        try await runDefaults(["-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", "0"])
    }
    
    func enableScreensaver(idleTime: Int = 600) async throws {
        try await runDefaults(["-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", String(idleTime)])
    }
    
    // MARK: - Hot Corners
    
    func disableHotCorners() async throws {
        for corner in ["wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner"] {
            try await runDefaults(["write", "com.apple.dock", corner, "-int", "0"])
        }
        try await runCommand("/usr/bin/killall", arguments: ["Dock"])
    }
    
    // MARK: - Helpers
    
    private func runDefaults(_ arguments: [String]) async throws {
        try await runCommand("/usr/bin/defaults", arguments: arguments)
    }
    
    private func runCommand(_ path: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: KioskError.lockdownFailed("Command failed: \(path)"))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
