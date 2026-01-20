import SwiftUI
import UniformTypeIdentifiers

// MARK: - Configuration View

struct ConfigurationView: View {
    @Bindable var viewModel: ContentViewModel
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Drop zone
                    dropZone
                    
                    // URL input
                    urlInputSection
                    
                    // Content settings (shown when content is configured)
                    if viewModel.contentType != nil {
                        Divider()
                        contentSettingsSection
                        Divider()
                        displaySettingsSection
                        Divider()
                        kioskSettingsSection
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer with actions
            footerSection
        }
        .frame(minWidth: 500, minHeight: 600)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plinth")
                    .font(.title.bold())
                Text("Kiosk Display Configuration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if PlinthConfiguration.shared.isManagedConfiguration() {
                Label("MDM Managed", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                
                VStack(spacing: 12) {
                    Image(systemName: contentTypeIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(viewModel.contentType != nil ? .primary : .secondary)
                    
                    if let type = viewModel.contentType {
                        Text(viewModel.contentPath)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        Text(type.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Drop a file here")
                            .font(.headline)
                        
                        Text("Video, PDF, Keynote, or .webloc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(32)
            }
            .frame(height: 200)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                viewModel.handleDrop(providers: providers)
            }
        }
    }
    
    private var contentTypeIcon: String {
        switch viewModel.contentType {
        case .video:
            return "film"
        case .pdf:
            return "doc.richtext"
        case .website:
            return "globe"
        case .keynote:
            return "play.rectangle"
        case nil:
            return "square.and.arrow.down"
        }
    }
    
    // MARK: - URL Input
    
    private var urlInputSection: some View {
        HStack {
            TextField("Or enter a URL...", text: $viewModel.contentPath)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.handleURLInput()
                }
            
            Button("Load") {
                viewModel.handleURLInput()
            }
            .disabled(viewModel.contentPath.isEmpty)
        }
    }
    
    // MARK: - Content Settings
    
    private var contentSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Settings")
                .font(.headline)
            
            // Player selection
            if !viewModel.availablePlayers.isEmpty {
                Picker("Player", selection: $viewModel.selectedPlayer) {
                    ForEach(viewModel.availablePlayers) { player in
                        Text(player.name).tag(Optional(player))
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Loop toggle
            Toggle("Loop content", isOn: $viewModel.loopContent)
            
            // Slideshow interval (for PDFs)
            if viewModel.contentType == .pdf {
                HStack {
                    Text("Slide interval:")
                    Stepper("\(viewModel.slideshowInterval) seconds", value: $viewModel.slideshowInterval, in: 1...300)
                }
            }
            
            // Web refresh interval
            if viewModel.contentType == .website {
                HStack {
                    Text("Refresh interval:")
                    Stepper(
                        viewModel.webRefreshInterval == 0 ? "Never" : "\(viewModel.webRefreshInterval) seconds",
                        value: $viewModel.webRefreshInterval,
                        in: 0...3600,
                        step: 30
                    )
                }
            }
        }
    }
    
    // MARK: - Display Settings
    
    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display Settings")
                .font(.headline)
            
            if viewModel.displays.count > 1 {
                Toggle("Span all displays", isOn: $viewModel.spanAllDisplays)
                
                if !viewModel.spanAllDisplays {
                    Picker("Target display", selection: $viewModel.displayIndex) {
                        ForEach(Array(viewModel.displays.enumerated()), id: \.element.id) { index, display in
                            Text(display.displayDescription).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                Text("Single display detected")
                    .foregroundStyle(.secondary)
            }
            
            Button("Refresh Displays") {
                Task {
                    await viewModel.loadDisplays()
                }
            }
            .buttonStyle(.link)
        }
    }
    
    // MARK: - Kiosk Settings
    
    private var kioskSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kiosk Settings")
                .font(.headline)
            
            Toggle("Enable lockdown mode", isOn: $viewModel.enableLockdown)
            
            if viewModel.enableLockdown {
                Text("Hides Dock, menu bar, and disables process switching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Toggle("Start automatically at login", isOn: $viewModel.autoStart)
            
            Toggle("Hide cursor", isOn: $viewModel.hideCursor)
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        HStack {
            Button("Reset") {
                PlinthConfiguration.shared.reset()
                viewModel.loadConfiguration()
            }
            
            Spacer()
            
            Button("Start Kiosk") {
                Task {
                    await viewModel.startKiosk()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isValidConfiguration)
        }
        .padding()
    }
}

#Preview {
    ConfigurationView(viewModel: ContentViewModel())
}
