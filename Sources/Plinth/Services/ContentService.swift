import AppKit
import Foundation

// MARK: - Content Service

actor ContentService {
    static let shared = ContentService()
    
    private var runningProcess: Process?
    private var keynoteMonitorTask: Task<Void, Never>?
    
    // MARK: - Launch Content
    
    func launch(config: ContentConfiguration) async throws {
        guard let url = config.contentURL else {
            throw ContentError.invalidContentPath
        }
        
        if config.isNativePlayer {
            // Native players are handled by SwiftUI views
            return
        }
        
        // External player launch
        switch config.contentType {
        case .video:
            try await launchVideoPlayer(url: url, playerID: config.playerID, loop: config.loopContent)
        case .pdf:
            try await launchPDFViewer(url: url, playerID: config.playerID)
        case .website:
            try await launchWebBrowser(url: url, playerID: config.playerID)
        case .keynote:
            try await launchKeynote(url: url, loop: config.loopContent)
        }
    }
    
    func stop() async {
        runningProcess?.terminate()
        runningProcess = nil
        
        keynoteMonitorTask?.cancel()
        keynoteMonitorTask = nil
        
        // Try to stop Keynote slideshow
        try? await KeynoteService.shared.stop()
    }
    
    // MARK: - Video Players
    
    private func launchVideoPlayer(url: URL, playerID: String, loop: Bool) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: playerID) else {
            throw ContentError.playerNotInstalled(playerID)
        }
        
        var arguments: [String] = []
        
        switch playerID {
        case "com.colliderli.iina":
            arguments = ["--pip=no", "--fullscreen"]
            if loop {
                arguments.append("--mpv-loop=inf")
            }
            
        case "org.videolan.vlc":
            arguments = ["--fullscreen", "--no-video-title-show", "--play-and-exit"]
            if loop {
                arguments.append("--loop")
            }
            
        case "com.apple.QuickTimePlayerX":
            // QuickTime needs AppleScript for looping
            if loop {
                try await launchQuickTimeWithLoop(url: url)
                return
            }
            
        default:
            break
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = arguments + [url.path]
        config.activates = true
        
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }
    
    private func launchQuickTimeWithLoop(url: URL) async throws {
        let script = """
        tell application "QuickTime Player"
            activate
            open POSIX file "\(url.path)"
            delay 1
            tell document 1
                set looping to true
                play
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - PDF Viewer
    
    private func launchPDFViewer(url: URL, playerID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: playerID) else {
            throw ContentError.playerNotInstalled(playerID)
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
        
        // Preview slideshow mode via AppleScript
        if playerID == "com.apple.Preview" {
            try? await Task.sleep(for: .seconds(1))
            try await startPreviewSlideshow()
        }
    }
    
    private func startPreviewSlideshow() async throws {
        let script = """
        tell application "System Events"
            tell process "Preview"
                keystroke "f" using {option down, command down}
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - Web Browser
    
    private func launchWebBrowser(url: URL, playerID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: playerID) else {
            throw ContentError.playerNotInstalled(playerID)
        }
        
        if playerID == "com.google.Chrome" {
            try await launchChromeKiosk(url: url, appURL: appURL)
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
        
        // Safari fullscreen
        if playerID == "com.apple.Safari" {
            try? await Task.sleep(for: .seconds(2))
            try await enterSafariFullscreen()
        }
    }
    
    private func launchChromeKiosk(url: URL, appURL: URL) async throws {
        // Chrome requires command line arguments for kiosk mode
        let chromePath = appURL.appendingPathComponent("Contents/MacOS/Google Chrome").path
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chromePath)
        process.arguments = [
            "--kiosk",
            "--noerrdialogs",
            "--disable-infobars",
            "--no-first-run",
            "--disable-translate",
            "--disable-features=TranslateUI",
            "--check-for-update-interval=31536000",
            url.absoluteString
        ]
        
        try process.run()
        runningProcess = process
    }
    
    private func enterSafariFullscreen() async throws {
        let script = """
        tell application "System Events"
            tell process "Safari"
                keystroke "f" using {control down, command down}
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - Keynote
    
    private func launchKeynote(url: URL, loop: Bool) async throws {
        try await KeynoteService.shared.openAndPlay(file: url, loop: loop)
    }
    
    // MARK: - AppleScript Helper
    
    private func runAppleScript(_ source: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                script?.executeAndReturnError(&error)
                
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ContentError.appleScriptFailed(message))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Content Errors

enum ContentError: Error, LocalizedError, Sendable {
    case invalidContentPath
    case playerNotInstalled(String)
    case launchFailed(String)
    case appleScriptFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidContentPath:
            return "Invalid content path"
        case .playerNotInstalled(let bundleID):
            return "Player not installed: \(bundleID)"
        case .launchFailed(let reason):
            return "Failed to launch content: \(reason)"
        case .appleScriptFailed(let message):
            return "AppleScript error: \(message)"
        }
    }
}
