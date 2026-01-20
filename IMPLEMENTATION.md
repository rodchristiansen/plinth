# Plinth Implementation Guide

This document provides detailed technical information for developers contributing to Plinth.

## Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Swift | 6.2 |
| UI Framework | SwiftUI | macOS 15+ |
| Minimum OS | macOS 15.0 Sequoia | - |
| Build System | Xcode | 16+ |
| Concurrency | Swift Concurrency | async/await, actors |

## Architecture Overview

Plinth follows a service-oriented architecture with clear separation between UI, business logic, and system integration layers.

```
+------------------------------------------------------------------+
|                         PlinthApp                                 |
|                     (SwiftUI App Lifecycle)                       |
+------------------------------------------------------------------+
         |                    |                    |
         v                    v                    v
+------------------+  +------------------+  +------------------+
|  Configuration   |  |    Preview       |  |    Settings      |
|      View        |  |     View         |  |      View        |
+------------------+  +------------------+  +------------------+
         |                    |                    |
         +--------------------+--------------------+
                              |
                              v
+------------------------------------------------------------------+
|                      AppDelegate                                  |
|            (NSApplicationDelegate for Kiosk Mode)                 |
+------------------------------------------------------------------+
         |                    |                    |
         v                    v                    v
+------------------+  +------------------+  +------------------+
|  ContentService  |  | DisplayService   |  |  KioskService    |
+------------------+  +------------------+  +------------------+
         |                    |                    |
         v                    v                    v
+------------------+  +------------------+  +------------------+
|  AVFoundation    |  |  CoreGraphics    |  |  IOKit/AppKit    |
|  PDFKit/WebKit   |  |  (CGDisplay*)    |  |  (Presentation)  |
+------------------+  +------------------+  +------------------+
```

## Core Components

### 1. Content Detection and Configuration

The `ContentService` actor handles content type detection and player management.

#### Content Types

```swift
enum ContentType: String, Codable, CaseIterable, Sendable {
    case video
    case pdf
    case website
    case keynote
    
    static func detect(from url: URL) -> ContentType? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "m4v", "mov", "avi", "mkv", "webm":
            return .video
        case "pdf":
            return .pdf
        case "key", "keynote":
            return .keynote
        case "webloc", "url", "html", "htm":
            return .website
        default:
            if url.scheme == "http" || url.scheme == "https" {
                return .website
            }
            return nil
        }
    }
}
```

#### Player Registry

```swift
struct PlayerInfo: Codable, Sendable, Identifiable {
    let id: String  // Bundle identifier
    let name: String
    let supportsNative: Bool
    let launchArguments: [String]
}

actor PlayerRegistry {
    static let shared = PlayerRegistry()
    
    private let players: [ContentType: [PlayerInfo]] = [
        .video: [
            PlayerInfo(id: "native", name: "Built-in Player", supportsNative: true, launchArguments: []),
            PlayerInfo(id: "com.apple.QuickTimePlayerX", name: "QuickTime Player", supportsNative: false, launchArguments: []),
            PlayerInfo(id: "com.colliderli.iina", name: "IINA", supportsNative: false, launchArguments: ["--pip=no"]),
            PlayerInfo(id: "org.videolan.vlc", name: "VLC", supportsNative: false, launchArguments: ["--fullscreen", "--loop"])
        ],
        .pdf: [
            PlayerInfo(id: "native", name: "Built-in Viewer", supportsNative: true, launchArguments: []),
            PlayerInfo(id: "com.apple.Preview", name: "Preview", supportsNative: false, launchArguments: [])
        ],
        .website: [
            PlayerInfo(id: "native", name: "Built-in Browser", supportsNative: true, launchArguments: []),
            PlayerInfo(id: "com.apple.Safari", name: "Safari", supportsNative: false, launchArguments: []),
            PlayerInfo(id: "com.google.Chrome", name: "Chrome (Kiosk)", supportsNative: false, launchArguments: ["--kiosk", "--noerrdialogs", "--disable-infobars", "--no-first-run", "--disable-translate"])
        ],
        .keynote: [
            PlayerInfo(id: "com.apple.iWork.Keynote", name: "Keynote", supportsNative: false, launchArguments: [])
        ]
    ]
    
    func availablePlayers(for type: ContentType) -> [PlayerInfo] {
        players[type] ?? []
    }
    
    func installedPlayers(for type: ContentType) async -> [PlayerInfo] {
        let all = players[type] ?? []
        return all.filter { info in
            info.id == "native" || NSWorkspace.shared.urlForApplication(withBundleIdentifier: info.id) != nil
        }
    }
}
```

### 2. Display Management

The `DisplayService` actor provides native display management using CoreGraphics APIs, replacing the need for external tools like displayplacer.

#### Display Enumeration

```swift
import CoreGraphics

struct DisplayInfo: Identifiable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let bounds: CGRect
    let isMain: Bool
    let isBuiltIn: Bool
    let resolution: CGSize
    let refreshRate: Double
}

actor DisplayService {
    static let shared = DisplayService()
    
    func listDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        
        guard CGGetActiveDisplayList(16, &displayIDs, &displayCount) == .success else {
            return []
        }
        
        return displayIDs.prefix(Int(displayCount)).map { displayID in
            let bounds = CGDisplayBounds(displayID)
            let mode = CGDisplayCopyDisplayMode(displayID)
            
            return DisplayInfo(
                id: displayID,
                name: displayName(for: displayID),
                bounds: bounds,
                isMain: CGDisplayIsMain(displayID) == 1,
                isBuiltIn: CGDisplayIsBuiltin(displayID) == 1,
                resolution: CGSize(
                    width: CGFloat(mode?.width ?? 0),
                    height: CGFloat(mode?.height ?? 0)
                ),
                refreshRate: mode?.refreshRate ?? 0
            )
        }
    }
    
    private func displayName(for displayID: CGDirectDisplayID) -> String {
        // Use IOKit to get display name from EDID
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return "Display \(displayID)"
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            if let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName))?.takeRetainedValue() as? [String: Any],
               let names = info[kDisplayProductName] as? [String: String],
               let name = names.values.first {
                return name
            }
        }
        
        return "Display \(displayID)"
    }
}
```

#### Display Configuration

```swift
extension DisplayService {
    
    /// Configure mirroring between displays
    func setMirroring(primary: CGDirectDisplayID, mirrors: [CGDirectDisplayID]) async throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            throw DisplayError.configurationFailed
        }
        
        for mirrorID in mirrors {
            CGConfigureDisplayMirrorOfDisplay(config, mirrorID, primary)
        }
        
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configurationFailed
        }
    }
    
    /// Set display resolution
    func setResolution(displayID: CGDirectDisplayID, width: Int, height: Int, refreshRate: Double = 0) async throws {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            throw DisplayError.noModesAvailable
        }
        
        guard let targetMode = modes.first(where: { mode in
            mode.width == width && 
            mode.height == height && 
            (refreshRate == 0 || mode.refreshRate == refreshRate)
        }) else {
            throw DisplayError.modeNotFound
        }
        
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            throw DisplayError.configurationFailed
        }
        
        CGConfigureDisplayWithDisplayMode(config, displayID, targetMode, nil)
        
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configurationFailed
        }
    }
    
    /// Get the frame for spanning all displays
    func spanningFrame() -> CGRect {
        let displays = listDisplays()
        guard !displays.isEmpty else { return .zero }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for display in displays {
            minX = min(minX, display.bounds.minX)
            minY = min(minY, display.bounds.minY)
            maxX = max(maxX, display.bounds.maxX)
            maxY = max(maxY, display.bounds.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

enum DisplayError: Error, LocalizedError {
    case configurationFailed
    case noModesAvailable
    case modeNotFound
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure display"
        case .noModesAvailable:
            return "No display modes available"
        case .modeNotFound:
            return "Requested display mode not found"
        }
    }
}
```

### 3. Kiosk Lockdown

The `KioskService` actor manages system lockdown without requiring MDM profiles.

#### Presentation Options

```swift
import AppKit

actor KioskService {
    static let shared = KioskService()
    
    private var powerAssertion: IOPMAssertionID = 0
    private var isLocked = false
    
    @MainActor
    func enableLockdown() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
            .disableMenuBarTransparency
        ]
        isLocked = true
    }
    
    @MainActor
    func disableLockdown() {
        NSApp.presentationOptions = []
        isLocked = false
    }
}
```

#### Power Management

```swift
import IOKit.pwr_mgt

extension KioskService {
    
    func preventSleep(reason: String = "Plinth Kiosk Mode") async throws {
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
    
    func hideCursor() async {
        await MainActor.run {
            NSCursor.hide()
        }
    }
    
    func showCursor() async {
        await MainActor.run {
            NSCursor.unhide()
        }
    }
}

enum KioskError: Error {
    case powerManagementFailed
}
```

#### Dock and Screensaver

```swift
extension KioskService {
    
    func configureDock(hidden: Bool, autohideDelay: Double = 0) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.dock", "autohide", "-bool", hidden ? "true" : "false"]
        try process.run()
        process.waitUntilExit()
        
        if hidden {
            let delayProcess = Process()
            delayProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            delayProcess.arguments = ["write", "com.apple.dock", "autohide-delay", "-float", String(autohideDelay)]
            try delayProcess.run()
            delayProcess.waitUntilExit()
        }
        
        // Restart Dock to apply changes
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProcess.arguments = ["Dock"]
        try killProcess.run()
        killProcess.waitUntilExit()
    }
    
    func disableScreensaver() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", "0"]
        try process.run()
        process.waitUntilExit()
    }
}
```

### 4. LaunchAgent Integration

The `LaunchAgentService` uses `SMAppService` for modern login item management.

```swift
import ServiceManagement

actor LaunchAgentService {
    static let shared = LaunchAgentService()
    
    private let agentIdentifier = "ca.ecuad.macadmins.plinth.agent"
    
    var isRegistered: Bool {
        get async {
            let service = SMAppService.agent(plistName: "\(agentIdentifier).plist")
            return service.status == .enabled
        }
    }
    
    func register() async throws {
        let service = SMAppService.agent(plistName: "\(agentIdentifier).plist")
        
        if service.status == .enabled {
            return // Already registered
        }
        
        try service.register()
    }
    
    func unregister() async throws {
        let service = SMAppService.agent(plistName: "\(agentIdentifier).plist")
        
        if service.status != .enabled {
            return // Not registered
        }
        
        try await service.unregister()
    }
    
    func status() -> SMAppService.Status {
        let service = SMAppService.agent(plistName: "\(agentIdentifier).plist")
        return service.status
    }
}
```

#### LaunchAgent Plist

The embedded LaunchAgent plist at `Contents/Library/LaunchAgents/ca.ecuad.macadmins.plinth.agent.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ca.ecuad.macadmins.plinth.agent</string>
    <key>BundleProgram</key>
    <string>Contents/MacOS/Plinth</string>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>ca.ecuad.macadmins.plinth</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
```

### 5. Keynote Automation

The `KeynoteService` handles Keynote presentation control via AppleScript.

```swift
import Foundation

actor KeynoteService {
    static let shared = KeynoteService()
    
    func openAndPlay(file: URL, loop: Bool = true) async throws {
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(file.path)"
            delay 1
            tell document 1
                start from first slide
            end tell
            \(loop ? loopScript() : "")
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    private func loopScript() -> String {
        return """
        
        -- Loop the slideshow
        repeat
            delay 1
            tell document 1
                if not playing then
                    start from first slide
                end if
            end tell
        end repeat
        """
    }
    
    func stop() async throws {
        let script = """
        tell application "Keynote"
            tell document 1
                stop
            end tell
        end tell
        """
        try await runAppleScript(script)
    }
    
    private func runAppleScript(_ source: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                script?.executeAndReturnError(&error)
                
                if let error = error {
                    continuation.resume(throwing: KeynoteError.scriptFailed(error.description))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum KeynoteError: Error {
    case scriptFailed(String)
}
```

### 6. Content Renderers

#### Native Video Player

```swift
import AVKit
import SwiftUI

struct NativeVideoPlayer: NSViewRepresentable {
    let url: URL
    let loop: Bool
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        
        let player = AVPlayer(url: url)
        playerView.player = player
        
        if loop {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
        }
        
        player.play()
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
```

#### Native PDF Viewer

```swift
import PDFKit
import SwiftUI

struct NativePDFViewer: NSViewRepresentable {
    let url: URL
    let interval: TimeInterval
    let loop: Bool
    
    @State private var currentPage = 0
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displaysPageBreaks = false
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            context.coordinator.startTimer(pdfView: pdfView, document: document)
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(interval: interval, loop: loop)
    }
    
    class Coordinator {
        let interval: TimeInterval
        let loop: Bool
        private var timer: Timer?
        private var currentIndex = 0
        
        init(interval: TimeInterval, loop: Bool) {
            self.interval = interval
            self.loop = loop
        }
        
        func startTimer(pdfView: PDFView, document: PDFDocument) {
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                self.currentIndex += 1
                
                if self.currentIndex >= document.pageCount {
                    if self.loop {
                        self.currentIndex = 0
                    } else {
                        self.timer?.invalidate()
                        return
                    }
                }
                
                if let page = document.page(at: self.currentIndex) {
                    pdfView.go(to: page)
                }
            }
        }
    }
}
```

#### Native Web View

```swift
import WebKit
import SwiftUI

struct NativeWebView: NSViewRepresentable {
    let url: URL
    let refreshInterval: TimeInterval?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
        
        if let interval = refreshInterval, interval > 0 {
            context.coordinator.startRefreshTimer(webView: webView, url: url, interval: interval)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        private var timer: Timer?
        
        func startRefreshTimer(webView: WKWebView, url: URL, interval: TimeInterval) {
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                webView.load(URLRequest(url: url))
            }
        }
    }
}
```

## Configuration Management

### Preferences Structure

```swift
import Foundation

@Observable
final class PlinthConfiguration: Sendable {
    static let shared = PlinthConfiguration()
    
    private let defaults = UserDefaults.standard
    private let domain = "ca.ecuad.macadmins.plinth"
    
    var contentPath: String? {
        get { defaults.string(forKey: "ContentPath") }
        set { defaults.set(newValue, forKey: "ContentPath") }
    }
    
    var contentType: ContentType? {
        get { 
            guard let raw = defaults.string(forKey: "ContentType") else { return nil }
            return ContentType(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: "ContentType") }
    }
    
    var playerBundleID: String? {
        get { defaults.string(forKey: "PlayerApp") }
        set { defaults.set(newValue, forKey: "PlayerApp") }
    }
    
    var displayIndex: Int {
        get { defaults.integer(forKey: "DisplayIndex") }
        set { defaults.set(newValue, forKey: "DisplayIndex") }
    }
    
    var enableLockdown: Bool {
        get { defaults.bool(forKey: "EnableLockdown") }
        set { defaults.set(newValue, forKey: "EnableLockdown") }
    }
    
    var autoStart: Bool {
        get { defaults.bool(forKey: "AutoStart") }
        set { defaults.set(newValue, forKey: "AutoStart") }
    }
    
    var loopContent: Bool {
        get { defaults.bool(forKey: "LoopContent") }
        set { defaults.set(newValue, forKey: "LoopContent") }
    }
    
    var slideshowInterval: Int {
        get { 
            let value = defaults.integer(forKey: "SlideshowInterval")
            return value > 0 ? value : 5
        }
        set { defaults.set(newValue, forKey: "SlideshowInterval") }
    }
    
    // Check if a value is managed by MDM (forced)
    func isManaged(_ key: String) -> Bool {
        CFPreferencesAppValueIsForced(key as CFString, domain as CFString)
    }
}
```

## Build Configuration

### Xcode Project Settings

| Setting | Value |
|---------|-------|
| Deployment Target | macOS 15.0 |
| Swift Language Version | 6.2 |
| Build Libraries for Distribution | No |
| Code Signing | Developer ID Application |
| Hardened Runtime | Yes |
| App Sandbox | Yes |

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.temporary-exception.apple-events</key>
    <array>
        <string>com.apple.iWork.Keynote</string>
        <string>com.apple.systemevents</string>
    </array>
</dict>
</plist>
```

### Code Signing for Notarization

```bash
# Build and archive
xcodebuild -scheme Plinth -configuration Release -archivePath build/Plinth.xcarchive archive

# Export for distribution
xcodebuild -exportArchive -archivePath build/Plinth.xcarchive -exportPath build/export -exportOptionsPlist ExportOptions.plist

# Submit for notarization
xcrun notarytool submit build/export/Plinth.app.zip --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" --wait

# Staple the ticket
xcrun stapler staple build/export/Plinth.app
```

## GitHub Actions CI/CD

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      
      - name: Build
        run: |
          xcodebuild -scheme Plinth -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO
      
      - name: Create DMG
        run: |
          mkdir -p dist
          cp -R "build/Build/Products/Release/Plinth.app" dist/
          hdiutil create -volname "Plinth" -srcfolder dist -ov -format UDZO Plinth.dmg
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: Plinth.dmg
          path: Plinth.dmg

  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: Plinth.dmg
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: Plinth.dmg
```

## Testing

### Unit Tests

```swift
import Testing
@testable import Plinth

@Test func contentTypeDetection() {
    #expect(ContentType.detect(from: URL(string: "file:///video.mp4")!) == .video)
    #expect(ContentType.detect(from: URL(string: "file:///doc.pdf")!) == .pdf)
    #expect(ContentType.detect(from: URL(string: "https://example.com")!) == .website)
    #expect(ContentType.detect(from: URL(string: "file:///pres.key")!) == .keynote)
}

@Test func displayServiceListsDisplays() async {
    let displays = await DisplayService.shared.listDisplays()
    #expect(!displays.isEmpty)
    #expect(displays.contains { $0.isMain })
}
```

### UI Tests

```swift
import XCTest

final class PlinthUITests: XCTestCase {
    func testDropTargetAcceptsVideo() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify drop target is visible
        XCTAssertTrue(app.staticTexts["Drop a file here or enter a URL"].exists)
    }
}
```

## MDM Companion Profiles

For full kiosk lockdown, deploy these MDM profiles alongside Plinth:

### Energy Settings Profile

```xml
<key>PayloadType</key>
<string>com.apple.MCX</string>
<key>com.apple.EnergySaver.desktop.ACPower</key>
<dict>
    <key>Display Sleep Timer</key>
    <integer>0</integer>
    <key>System Sleep Timer</key>
    <integer>0</integer>
    <key>Automatic Restart On Power Loss</key>
    <true/>
    <key>Wake On LAN</key>
    <true/>
</dict>
```

### Restrictions Profile

```xml
<key>PayloadType</key>
<string>com.apple.applicationaccess</string>
<key>allowScreenShot</key>
<false/>
<key>allowMusicService</key>
<false/>
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| App not starting at login | SMAppService not registered | Check System Settings > Login Items |
| Fullscreen not working | Window level too low | Verify presentationOptions are set |
| Chrome kiosk mode failing | Chrome not installed | Check bundle ID resolution |
| Display mirroring failing | Insufficient permissions | Run with admin privileges |

### Debug Logging

Enable verbose logging:

```bash
defaults write ca.ecuad.macadmins.plinth EnableDebugLogging -bool true
```

View logs:

```bash
log stream --predicate 'subsystem == "ca.ecuad.macadmins.plinth"'
```
