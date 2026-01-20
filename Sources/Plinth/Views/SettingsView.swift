import SwiftUI
import ServiceManagement

// MARK: - Settings View

struct SettingsView: View {
    @State private var launchAgentStatus: SMAppService.Status = .notRegistered
    @State private var loginItemStatus: SMAppService.Status = .notRegistered
    @State private var showResetConfirmation = false
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            startupTab
                .tabItem {
                    Label("Startup", systemImage: "power")
                }
            
            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 450, height: 350)
        .task {
            await refreshStatus()
        }
    }
    
    // MARK: - General Tab
    
    private var generalTab: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
                
                LabeledContent("Build") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                }
            }
            
            Section("Configuration") {
                LabeledContent("Preferences File") {
                    Button("Show in Finder") {
                        showPreferencesInFinder()
                    }
                    .buttonStyle(.link)
                }
                
                LabeledContent("MDM Managed") {
                    Text(PlinthConfiguration.shared.isManagedConfiguration() ? "Yes" : "No")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Startup Tab
    
    private var startupTab: some View {
        Form {
            Section("Login Item") {
                HStack {
                    Text("Status:")
                    Spacer()
                    statusBadge(for: loginItemStatus)
                }
                
                HStack {
                    Button("Enable") {
                        Task {
                            try? await LaunchAgentService.shared.registerAsLoginItem()
                            await refreshStatus()
                        }
                    }
                    .disabled(loginItemStatus == .enabled)
                    
                    Button("Disable") {
                        Task {
                            try? await LaunchAgentService.shared.unregisterLoginItem()
                            await refreshStatus()
                        }
                    }
                    .disabled(loginItemStatus != .enabled)
                }
                
                if loginItemStatus == .requiresApproval {
                    Button("Open Login Items Settings") {
                        LaunchAgentService.shared.openLoginItemsSettings()
                    }
                    .buttonStyle(.link)
                }
            }
            
            Section("LaunchAgent") {
                HStack {
                    Text("Status:")
                    Spacer()
                    statusBadge(for: launchAgentStatus)
                }
                
                if launchAgentStatus == .notFound {
                    Text("LaunchAgent plist not found in app bundle. This is expected for development builds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Advanced Tab
    
    private var advancedTab: some View {
        Form {
            Section("Debug") {
                Toggle("Enable Debug Logging", isOn: .constant(false))
                    .disabled(true)
                
                Button("View Logs in Console") {
                    openConsoleApp()
                }
                .buttonStyle(.link)
            }
            
            Section("Reset") {
                Button("Reset All Settings", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                PlinthConfiguration.shared.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all saved configuration. This cannot be undone.")
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func statusBadge(for status: SMAppService.Status) -> some View {
        switch status {
        case .enabled:
            Text("Enabled")
                .foregroundStyle(.green)
        case .notRegistered:
            Text("Not Registered")
                .foregroundStyle(.secondary)
        case .requiresApproval:
            Text("Requires Approval")
                .foregroundStyle(.orange)
        case .notFound:
            Text("Not Found")
                .foregroundStyle(.red)
        @unknown default:
            Text("Unknown")
                .foregroundStyle(.secondary)
        }
    }
    
    private func refreshStatus() async {
        launchAgentStatus = await LaunchAgentService.shared.status
        loginItemStatus = await LaunchAgentService.shared.loginItemStatus
    }
    
    private func showPreferencesInFinder() {
        let prefsPath = NSHomeDirectory() + "/Library/Preferences/ca.ecuad.macadmins.plinth.plist"
        let url = URL(fileURLWithPath: prefsPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func openConsoleApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
}

#Preview {
    SettingsView()
}
