import SwiftUI
import AppKit

// MARK: - Kiosk Key Monitor

private enum KioskKeyMonitor {
    nonisolated(unsafe) static var monitor: Any?

    @MainActor
    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains([.control, .option, .command]),
               event.charactersIgnoringModifiers?.lowercased() == "e" {
                NotificationCenter.default.post(name: .plinthExitKioskRequested, object: nil)
                return nil
            }
            return event
        }
    }

    @MainActor
    static func remove() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

// MARK: - Kiosk Content View

struct KioskContentView: View {
    @Bindable var viewModel: ContentViewModel
    @State private var showAuthPrompt = false
    @State private var isAuthenticating = false
    @State private var authFailed = false
    
    var body: some View {
        ZStack {
            // Content
            contentView
            
            // Auth overlay
            if showAuthPrompt {
                exitAuthOverlay
            }
        }
        .ignoresSafeArea()
        .onAppear { KioskKeyMonitor.install() }
        .onDisappear { KioskKeyMonitor.remove() }
        .onReceive(NotificationCenter.default.publisher(for: .plinthExitKioskRequested)) { _ in
            showAuthPrompt = true
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if let config = PlinthConfiguration.shared.contentConfiguration,
           config.isNativePlayer,
           let url = config.contentURL {
            
            switch config.contentType {
            case .video:
                VideoPlayerView(
                    url: url,
                    loop: config.loopContent
                )
                
            case .pdf:
                PDFViewerView(
                    url: url,
                    slideshowInterval: config.slideshowInterval,
                    loop: config.loopContent
                )
                
            case .website:
                WebViewerView(
                    url: url,
                    refreshInterval: config.webRefreshInterval
                )
                
            case .keynote:
                // Keynote uses external app via AppleScript
                ExternalPlayerPlaceholder(message: "Keynote presentation running...")
            }
        } else {
            // External player is running
            ExternalPlayerPlaceholder(message: "External player running...")
        }
    }
    
    // MARK: - Exit Auth Overlay
    
    private var exitAuthOverlay: some View {
        Color.black.opacity(0.6)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    
                    Text("Exit Kiosk Mode")
                        .font(.title2.bold())
                    
                    Text("Administrator authentication is required\nto exit kiosk mode and modify settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if authFailed {
                        Text("Authentication failed. Please try again.")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showAuthPrompt = false
                            authFailed = false
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Authenticate") {
                            // Ensure cursor is visible for the auth dialog
                            NSCursor.unhide()
                            Task {
                                isAuthenticating = true
                                authFailed = false
                                let success = await AuthenticationService.shared.requestAdminAuthentication()
                                isAuthenticating = false
                                if success {
                                    showAuthPrompt = false
                                    await viewModel.stopKiosk()
                                } else {
                                    authFailed = true
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isAuthenticating)
                    }
                    
                    if isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(radius: 20)
                )
            }
    }
}

// MARK: - External Player Placeholder

struct ExternalPlayerPlaceholder: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Press ⌃⌥⌘E to exit kiosk mode")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    KioskContentView(viewModel: ContentViewModel())
}
