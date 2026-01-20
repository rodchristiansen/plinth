import Foundation

// MARK: - Plinth Configuration

@Observable
@MainActor
final class PlinthConfiguration: Sendable {
    static let shared = PlinthConfiguration()
    
    private let defaults = UserDefaults.standard
    private let domain = "com.github.macadmins.Plinth"
    
    // MARK: - Content Settings
    
    var contentPath: String? {
        get { defaults.string(forKey: Keys.contentPath) }
        set { defaults.set(newValue, forKey: Keys.contentPath) }
    }
    
    var contentType: ContentType? {
        get {
            guard let raw = defaults.string(forKey: Keys.contentType) else { return nil }
            return ContentType(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: Keys.contentType) }
    }
    
    var playerBundleID: String {
        get { defaults.string(forKey: Keys.playerApp) ?? "native" }
        set { defaults.set(newValue, forKey: Keys.playerApp) }
    }
    
    var loopContent: Bool {
        get { defaults.bool(forKey: Keys.loopContent) }
        set { defaults.set(newValue, forKey: Keys.loopContent) }
    }
    
    var slideshowInterval: Int {
        get {
            let value = defaults.integer(forKey: Keys.slideshowInterval)
            return value > 0 ? value : 5
        }
        set { defaults.set(max(1, newValue), forKey: Keys.slideshowInterval) }
    }
    
    var webRefreshInterval: Int {
        get { defaults.integer(forKey: Keys.webRefreshInterval) }
        set { defaults.set(max(0, newValue), forKey: Keys.webRefreshInterval) }
    }
    
    // MARK: - Display Settings
    
    var displayIndex: Int {
        get { defaults.integer(forKey: Keys.displayIndex) }
        set { defaults.set(newValue, forKey: Keys.displayIndex) }
    }
    
    var spanAllDisplays: Bool {
        get { defaults.bool(forKey: Keys.spanAllDisplays) }
        set { defaults.set(newValue, forKey: Keys.spanAllDisplays) }
    }
    
    var mirrorDisplays: Bool {
        get { defaults.bool(forKey: Keys.mirrorDisplays) }
        set { defaults.set(newValue, forKey: Keys.mirrorDisplays) }
    }
    
    // MARK: - Kiosk Settings
    
    var enableLockdown: Bool {
        get { defaults.bool(forKey: Keys.enableLockdown) }
        set { defaults.set(newValue, forKey: Keys.enableLockdown) }
    }
    
    var autoStart: Bool {
        get { defaults.bool(forKey: Keys.autoStart) }
        set { defaults.set(newValue, forKey: Keys.autoStart) }
    }
    
    var hideCursor: Bool {
        get { defaults.bool(forKey: Keys.hideCursor) }
        set { defaults.set(newValue, forKey: Keys.hideCursor) }
    }
    
    var preventSleep: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Keys.preventSleep) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.preventSleep)
        }
        set { defaults.set(newValue, forKey: Keys.preventSleep) }
    }
    
    // MARK: - MDM Management
    
    func isManaged(_ key: String) -> Bool {
        CFPreferencesAppValueIsForced(key as CFString, domain as CFString)
    }
    
    func isManagedConfiguration() -> Bool {
        isManaged(Keys.contentPath) || isManaged(Keys.contentType)
    }
    
    // MARK: - Configuration Objects
    
    var contentConfiguration: ContentConfiguration? {
        guard let path = contentPath,
              let type = contentType else {
            return nil
        }
        
        return ContentConfiguration(
            contentPath: path,
            contentType: type,
            playerID: playerBundleID,
            loopContent: loopContent,
            slideshowInterval: slideshowInterval,
            webRefreshInterval: webRefreshInterval
        )
    }
    
    var displayConfiguration: DisplayConfiguration {
        DisplayConfiguration(
            displayIndex: displayIndex,
            spanAllDisplays: spanAllDisplays,
            mirrorDisplays: mirrorDisplays
        )
    }
    
    var kioskConfiguration: KioskConfiguration {
        KioskConfiguration(
            enableLockdown: enableLockdown,
            hideDock: enableLockdown,
            hideMenuBar: enableLockdown,
            disableProcessSwitching: enableLockdown,
            preventSleep: preventSleep,
            hideCursor: hideCursor,
            disableScreensaver: enableLockdown
        )
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let contentPath = "ContentPath"
        static let contentType = "ContentType"
        static let playerApp = "PlayerApp"
        static let loopContent = "LoopContent"
        static let slideshowInterval = "SlideshowInterval"
        static let webRefreshInterval = "WebRefreshInterval"
        static let displayIndex = "DisplayIndex"
        static let spanAllDisplays = "SpanAllDisplays"
        static let mirrorDisplays = "MirrorDisplays"
        static let enableLockdown = "EnableLockdown"
        static let autoStart = "AutoStart"
        static let hideCursor = "HideCursor"
        static let preventSleep = "PreventSleep"
    }
    
    // MARK: - Reset
    
    func reset() {
        let keys = [
            Keys.contentPath,
            Keys.contentType,
            Keys.playerApp,
            Keys.loopContent,
            Keys.slideshowInterval,
            Keys.webRefreshInterval,
            Keys.displayIndex,
            Keys.spanAllDisplays,
            Keys.mirrorDisplays,
            Keys.enableLockdown,
            Keys.autoStart,
            Keys.hideCursor,
            Keys.preventSleep
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
