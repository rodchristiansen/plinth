import SwiftUI
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    
    var body: some View {
        Group {
            if viewModel.isKioskActive {
                KioskContentView(viewModel: viewModel)
            } else {
                ConfigurationView(viewModel: viewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .plinthAutoStart)) { _ in
            Task {
                await viewModel.startKiosk()
            }
        }
    }
}

// MARK: - Content View Model

@Observable
@MainActor
final class ContentViewModel {
    var contentPath: String = ""
    var contentType: ContentType?
    var selectedPlayer: PlayerInfo?
    var availablePlayers: [PlayerInfo] = []
    var loopContent: Bool = true
    var slideshowInterval: Int = 5
    var webRefreshInterval: Int = 0
    
    var displayIndex: Int = 0
    var spanAllDisplays: Bool = false
    var displays: [DisplayInfo] = []
    
    var enableLockdown: Bool = false
    var autoStart: Bool = false
    var hideCursor: Bool = false
    
    var isKioskActive: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    
    private let config = PlinthConfiguration.shared
    
    init() {
        loadConfiguration()
        Task {
            await loadDisplays()
        }
    }
    
    // MARK: - Configuration Loading
    
    func loadConfiguration() {
        contentPath = config.contentPath ?? ""
        contentType = config.contentType
        loopContent = config.loopContent
        slideshowInterval = config.slideshowInterval
        webRefreshInterval = config.webRefreshInterval
        displayIndex = config.displayIndex
        spanAllDisplays = config.spanAllDisplays
        enableLockdown = config.enableLockdown
        autoStart = config.autoStart
        hideCursor = config.hideCursor
        
        if let type = contentType {
            Task {
                await loadPlayers(for: type)
            }
        }
    }
    
    func saveConfiguration() {
        config.contentPath = contentPath.isEmpty ? nil : contentPath
        config.contentType = contentType
        config.playerBundleID = selectedPlayer?.id ?? "native"
        config.loopContent = loopContent
        config.slideshowInterval = slideshowInterval
        config.webRefreshInterval = webRefreshInterval
        config.displayIndex = displayIndex
        config.spanAllDisplays = spanAllDisplays
        config.enableLockdown = enableLockdown
        config.autoStart = autoStart
        config.hideCursor = hideCursor
    }
    
    // MARK: - Content Detection
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                Task { @MainActor in
                    self.handleFileURL(url)
                }
            }
            return true
        }
        
        return false
    }
    
    func handleFileURL(_ url: URL) {
        contentPath = url.path
        
        if let type = ContentType.detect(from: url) {
            contentType = type
            Task {
                await loadPlayers(for: type)
            }
        }
    }
    
    func handleURLInput() {
        guard let type = ContentType.detect(from: contentPath) else {
            errorMessage = "Could not detect content type from URL"
            showError = true
            return
        }
        
        contentType = type
        Task {
            await loadPlayers(for: type)
        }
    }
    
    // MARK: - Players
    
    func loadPlayers(for type: ContentType) async {
        availablePlayers = await PlayerRegistry.shared.installedPlayers(for: type)
        
        // Select saved player or default to first
        let savedPlayerID = config.playerBundleID
        selectedPlayer = availablePlayers.first { $0.id == savedPlayerID } ?? availablePlayers.first
    }
    
    // MARK: - Displays
    
    func loadDisplays() async {
        displays = await DisplayService.shared.listDisplays()
    }
    
    // MARK: - Kiosk Control
    
    func startKiosk() async {
        guard !contentPath.isEmpty, contentType != nil else {
            errorMessage = "No content configured"
            showError = true
            return
        }
        
        saveConfiguration()
        
        // Enable lockdown if configured
        if enableLockdown {
            do {
                try await KioskService.shared.enableLockdown(config: config.kioskConfiguration)
            } catch {
                errorMessage = "Failed to enable lockdown: \(error.localizedDescription)"
                showError = true
                return
            }
        }
        
        // Launch external player if needed
        if let contentConfig = config.contentConfiguration, !contentConfig.isNativePlayer {
            do {
                try await ContentService.shared.launch(config: contentConfig)
            } catch {
                errorMessage = "Failed to launch content: \(error.localizedDescription)"
                showError = true
                return
            }
        }
        
        isKioskActive = true
    }
    
    func stopKiosk() async {
        isKioskActive = false
        
        await ContentService.shared.stop()
        await KioskService.shared.disableLockdown()
    }
    
    // MARK: - Validation
    
    var isValidConfiguration: Bool {
        !contentPath.isEmpty && contentType != nil && selectedPlayer != nil
    }
}

#Preview {
    ContentView()
}
