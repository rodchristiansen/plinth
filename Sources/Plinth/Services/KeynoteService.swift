import Foundation

// MARK: - Keynote Service

actor KeynoteService {
    static let shared = KeynoteService()
    
    private var loopTask: Task<Void, Never>?
    
    // MARK: - Open and Play
    
    func openAndPlay(file: URL, loop: Bool = true) async throws {
        let openScript = """
        tell application "Keynote"
            activate
            open POSIX file "\(file.path)"
            delay 2
            tell document 1
                start from first slide
            end tell
        end tell
        """
        
        try await runAppleScript(openScript)
        
        if loop {
            startLoopMonitor()
        }
    }
    
    // MARK: - Stop
    
    func stop() async throws {
        loopTask?.cancel()
        loopTask = nil
        
        let stopScript = """
        tell application "Keynote"
            tell document 1
                if playing then
                    stop
                end if
            end tell
        end tell
        """
        
        try await runAppleScript(stopScript)
    }
    
    // MARK: - Loop Monitor
    
    private func startLoopMonitor() {
        loopTask?.cancel()
        
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                
                guard !Task.isCancelled else { break }
                
                // Check if slideshow ended and restart
                let checkScript = """
                tell application "Keynote"
                    if (count of documents) > 0 then
                        tell document 1
                            if not playing then
                                start from first slide
                            end if
                        end tell
                    end if
                end tell
                """
                
                try? await runAppleScript(checkScript)
            }
        }
    }
    
    // MARK: - Advance Slide
    
    func nextSlide() async throws {
        let script = """
        tell application "Keynote"
            tell document 1
                if playing then
                    show next
                end if
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    func previousSlide() async throws {
        let script = """
        tell application "Keynote"
            tell document 1
                if playing then
                    show previous
                end if
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - Slide Count
    
    func slideCount() async throws -> Int {
        let script = """
        tell application "Keynote"
            tell document 1
                count of slides
            end tell
        end tell
        """
        
        let result = try await runAppleScriptWithResult(script)
        return Int(result) ?? 0
    }
    
    // MARK: - AppleScript Helpers
    
    private func runAppleScript(_ source: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                script?.executeAndReturnError(&error)
                
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: KeynoteError.scriptFailed(message))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func runAppleScriptWithResult(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global().async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)
                
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: KeynoteError.scriptFailed(message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }
}

// MARK: - Keynote Errors

enum KeynoteError: Error, LocalizedError, Sendable {
    case scriptFailed(String)
    case documentNotOpen
    case notPlaying
    
    var errorDescription: String? {
        switch self {
        case .scriptFailed(let message):
            return "Keynote script error: \(message)"
        case .documentNotOpen:
            return "No Keynote document is open"
        case .notPlaying:
            return "Keynote is not playing"
        }
    }
}
