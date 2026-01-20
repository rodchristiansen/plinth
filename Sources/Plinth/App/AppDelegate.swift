import AppKit
import IOKit.pwr_mgt

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var powerAssertion: IOPMAssertionID = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureForKioskMode()
        
        Task {
            await handleAutoStart()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        releasePowerAssertion()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Kiosk Configuration
    
    private func configureForKioskMode() {
        let config = PlinthConfiguration.shared
        
        if config.enableLockdown {
            enableKioskPresentationOptions()
            createPowerAssertion()
        }
    }
    
    private func enableKioskPresentationOptions() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
            .disableMenuBarTransparency
        ]
    }
    
    private func createPowerAssertion() {
        let reason = "Plinth Kiosk Mode" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &powerAssertion
        )
        
        if result != kIOReturnSuccess {
            print("Failed to create power assertion: \(result)")
        }
    }
    
    private func releasePowerAssertion() {
        if powerAssertion != 0 {
            IOPMAssertionRelease(powerAssertion)
            powerAssertion = 0
        }
    }
    
    // MARK: - Auto Start
    
    private func handleAutoStart() async {
        let config = PlinthConfiguration.shared
        
        guard config.autoStart,
              let contentPath = config.contentPath,
              !contentPath.isEmpty else {
            return
        }
        
        // Small delay to ensure window is ready
        try? await Task.sleep(for: .milliseconds(500))
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .plinthAutoStart,
                object: nil
            )
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let plinthAutoStart = Notification.Name("ca.ecuad.macadmins.Plinth.autoStart")
    static let plinthStartKiosk = Notification.Name("ca.ecuad.macadmins.Plinth.startKiosk")
    static let plinthStopKiosk = Notification.Name("ca.ecuad.macadmins.Plinth.stopKiosk")
}
