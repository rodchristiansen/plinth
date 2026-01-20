import Foundation
import ServiceManagement
import AppKit

// MARK: - LaunchAgent Service

actor LaunchAgentService {
    static let shared = LaunchAgentService()
    
    private let agentPlistName = "ca.ecuad.macadmins.plinth.agent.plist"
    
    // MARK: - Status
    
    var isRegistered: Bool {
        status == .enabled
    }
    
    var status: SMAppService.Status {
        let service = SMAppService.agent(plistName: agentPlistName)
        return service.status
    }
    
    var statusDescription: String {
        switch status {
        case .notRegistered:
            return "Not registered"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notFound:
            return "Agent plist not found in bundle"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Registration
    
    func register() async throws {
        let service = SMAppService.agent(plistName: agentPlistName)
        
        switch service.status {
        case .enabled:
            return // Already registered
        case .notFound:
            throw LaunchAgentError.plistNotFound
        default:
            break
        }
        
        do {
            try service.register()
        } catch {
            throw LaunchAgentError.registrationFailed(error.localizedDescription)
        }
    }
    
    func unregister() async throws {
        let service = SMAppService.agent(plistName: agentPlistName)
        
        guard service.status == .enabled else {
            return // Not registered
        }
        
        do {
            try await service.unregister()
        } catch {
            throw LaunchAgentError.unregistrationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Login Item (Alternative)
    
    func registerAsLoginItem() async throws {
        let service = SMAppService.mainApp
        
        guard service.status != .enabled else {
            return
        }
        
        do {
            try service.register()
        } catch {
            throw LaunchAgentError.registrationFailed(error.localizedDescription)
        }
    }
    
    func unregisterLoginItem() async throws {
        let service = SMAppService.mainApp
        
        guard service.status == .enabled else {
            return
        }
        
        do {
            try await service.unregister()
        } catch {
            throw LaunchAgentError.unregistrationFailed(error.localizedDescription)
        }
    }
    
    var loginItemStatus: SMAppService.Status {
        SMAppService.mainApp.status
    }
    
    // MARK: - Open System Settings
    
    @MainActor
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Errors

enum LaunchAgentError: Error, LocalizedError, Sendable {
    case plistNotFound
    case registrationFailed(String)
    case unregistrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .plistNotFound:
            return "LaunchAgent plist not found in application bundle"
        case .registrationFailed(let reason):
            return "Failed to register LaunchAgent: \(reason)"
        case .unregistrationFailed(let reason):
            return "Failed to unregister LaunchAgent: \(reason)"
        }
    }
}
