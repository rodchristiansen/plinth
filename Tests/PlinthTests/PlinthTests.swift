import Testing
import Foundation
@testable import Plinth

// MARK: - Content Type Detection Tests

@Suite("Content Type Detection")
struct ContentTypeTests {
    
    @Test("Detects video file extensions")
    func detectsVideoExtensions() {
        let videoExtensions = ["mp4", "m4v", "mov", "avi", "mkv", "webm"]
        
        for ext in videoExtensions {
            let url = URL(fileURLWithPath: "/test/video.\(ext)")
            #expect(ContentType.detect(from: url) == .video, "Failed for extension: \(ext)")
        }
    }
    
    @Test("Detects PDF files")
    func detectsPDF() {
        let url = URL(fileURLWithPath: "/test/document.pdf")
        #expect(ContentType.detect(from: url) == .pdf)
    }
    
    @Test("Detects Keynote files")
    func detectsKeynote() {
        let keyURL = URL(fileURLWithPath: "/test/presentation.key")
        #expect(ContentType.detect(from: keyURL) == .keynote)
        
        let keynoteURL = URL(fileURLWithPath: "/test/presentation.keynote")
        #expect(ContentType.detect(from: keynoteURL) == .keynote)
    }
    
    @Test("Detects website URLs")
    func detectsWebsiteURLs() {
        let httpURL = URL(string: "http://example.com")!
        #expect(ContentType.detect(from: httpURL) == .website)
        
        let httpsURL = URL(string: "https://example.com")!
        #expect(ContentType.detect(from: httpsURL) == .website)
    }
    
    @Test("Detects webloc files")
    func detectsWebloc() {
        let url = URL(fileURLWithPath: "/test/bookmark.webloc")
        #expect(ContentType.detect(from: url) == .website)
    }
    
    @Test("Returns nil for unknown types")
    func returnsNilForUnknown() {
        let url = URL(fileURLWithPath: "/test/file.xyz")
        #expect(ContentType.detect(from: url) == nil)
    }
    
    @Test("Detects from string path")
    func detectsFromStringPath() {
        #expect(ContentType.detect(from: "https://example.com") == .website)
        #expect(ContentType.detect(from: "/path/to/video.mp4") == .video)
    }
}

// MARK: - Player Info Tests

@Suite("Player Registry")
struct PlayerRegistryTests {
    
    @Test("Returns players for video type")
    func videoPlayers() async {
        let players = await PlayerRegistry.shared.availablePlayers(for: .video)
        #expect(!players.isEmpty)
        #expect(players.contains { $0.id == "native" })
        #expect(players.contains { $0.id == "com.apple.QuickTimePlayerX" })
    }
    
    @Test("Returns players for PDF type")
    func pdfPlayers() async {
        let players = await PlayerRegistry.shared.availablePlayers(for: .pdf)
        #expect(!players.isEmpty)
        #expect(players.contains { $0.id == "native" })
    }
    
    @Test("Returns players for website type")
    func websitePlayers() async {
        let players = await PlayerRegistry.shared.availablePlayers(for: .website)
        #expect(!players.isEmpty)
        #expect(players.contains { $0.id == "com.google.Chrome" })
    }
    
    @Test("Chrome player has kiosk arguments")
    func chromeKioskArguments() {
        #expect(PlayerInfo.chrome.launchArguments.contains("--kiosk"))
        #expect(PlayerInfo.chrome.launchArguments.contains("--noerrdialogs"))
    }
}

// MARK: - Content Configuration Tests

@Suite("Content Configuration")
struct ContentConfigurationTests {
    
    @Test("Creates valid URL from file path")
    func filePathURL() {
        let config = ContentConfiguration(
            contentPath: "/path/to/video.mp4",
            contentType: .video
        )
        
        #expect(config.contentURL?.path == "/path/to/video.mp4")
    }
    
    @Test("Creates valid URL from web URL")
    func webURL() {
        let config = ContentConfiguration(
            contentPath: "https://example.com",
            contentType: .website
        )
        
        #expect(config.contentURL?.absoluteString == "https://example.com")
    }
    
    @Test("Identifies native player")
    func nativePlayerIdentification() {
        let nativeConfig = ContentConfiguration(
            contentPath: "/test.mp4",
            contentType: .video,
            playerID: "native"
        )
        #expect(nativeConfig.isNativePlayer)
        
        let externalConfig = ContentConfiguration(
            contentPath: "/test.mp4",
            contentType: .video,
            playerID: "com.colliderli.iina"
        )
        #expect(!externalConfig.isNativePlayer)
    }
}

// MARK: - Display Configuration Tests

@Suite("Display Configuration")
struct DisplayConfigurationTests {
    
    @Test("Primary display is index 0")
    func primaryDisplayIndex() {
        let config = DisplayConfiguration.primaryDisplay
        #expect(config.displayIndex == 0)
        #expect(!config.spanAllDisplays)
    }
    
    @Test("Span all configuration")
    func spanAllConfiguration() {
        let config = DisplayConfiguration.spanAll
        #expect(config.spanAllDisplays)
    }
}

// MARK: - Kiosk Configuration Tests

@Suite("Kiosk Configuration")
struct KioskConfigurationTests {
    
    @Test("Disabled configuration")
    func disabledConfiguration() {
        let config = KioskConfiguration.disabled
        #expect(!config.enableLockdown)
    }
    
    @Test("Full lockdown configuration")
    func fullLockdownConfiguration() {
        let config = KioskConfiguration.fullLockdown
        #expect(config.enableLockdown)
        #expect(config.hideDock)
        #expect(config.hideMenuBar)
        #expect(config.disableProcessSwitching)
        #expect(config.preventSleep)
        #expect(config.hideCursor)
        #expect(config.disableScreensaver)
    }
}
