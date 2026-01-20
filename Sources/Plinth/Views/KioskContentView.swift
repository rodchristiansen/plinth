import SwiftUI

// MARK: - Kiosk Content View

struct KioskContentView: View {
    @Bindable var viewModel: ContentViewModel
    @State private var showExitConfirmation = false
    
    var body: some View {
        ZStack {
            // Content
            contentView
            
            // Exit overlay (triple-click to show)
            exitOverlay
        }
        .ignoresSafeArea()
        .onTapGesture(count: 3) {
            showExitConfirmation = true
        }
        .confirmationDialog("Exit Kiosk Mode?", isPresented: $showExitConfirmation) {
            Button("Exit", role: .destructive) {
                Task {
                    await viewModel.stopKiosk()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the current presentation and return to configuration.")
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
    
    // MARK: - Exit Overlay
    
    @ViewBuilder
    private var exitOverlay: some View {
        if showExitConfirmation {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
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
                
                Text("Triple-click to exit kiosk mode")
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
