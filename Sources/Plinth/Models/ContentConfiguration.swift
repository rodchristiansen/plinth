import Foundation

// MARK: - Content Type

enum ContentType: String, Codable, CaseIterable, Sendable, Identifiable {
    case video
    case pdf
    case website
    case keynote
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .pdf: return "PDF"
        case .website: return "Website"
        case .keynote: return "Keynote"
        }
    }
    
    var supportedExtensions: [String] {
        switch self {
        case .video:
            return ["mp4", "m4v", "mov", "avi", "mkv", "webm", "wmv", "flv"]
        case .pdf:
            return ["pdf"]
        case .website:
            return ["webloc", "url", "html", "htm"]
        case .keynote:
            return ["key", "keynote"]
        }
    }
    
    static func detect(from url: URL) -> ContentType? {
        // Check URL scheme first
        if url.scheme == "http" || url.scheme == "https" {
            return .website
        }
        
        let ext = url.pathExtension.lowercased()
        
        for type in ContentType.allCases {
            if type.supportedExtensions.contains(ext) {
                return type
            }
        }
        
        return nil
    }
    
    static func detect(from path: String) -> ContentType? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return .website
        }
        
        let url = URL(fileURLWithPath: path)
        return detect(from: url)
    }
}

// MARK: - Player Info

struct PlayerInfo: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let isNative: Bool
    let launchArguments: [String]
    
    static let nativeVideo = PlayerInfo(
        id: "native",
        name: "Built-in Player",
        isNative: true,
        launchArguments: []
    )
    
    static let quicktime = PlayerInfo(
        id: "com.apple.QuickTimePlayerX",
        name: "QuickTime Player",
        isNative: false,
        launchArguments: []
    )
    
    static let iina = PlayerInfo(
        id: "com.colliderli.iina",
        name: "IINA",
        isNative: false,
        launchArguments: ["--pip=no", "--fullscreen"]
    )
    
    static let vlc = PlayerInfo(
        id: "org.videolan.vlc",
        name: "VLC",
        isNative: false,
        launchArguments: ["--fullscreen", "--loop", "--no-video-title-show"]
    )
    
    static let nativePDF = PlayerInfo(
        id: "native",
        name: "Built-in Viewer",
        isNative: true,
        launchArguments: []
    )
    
    static let preview = PlayerInfo(
        id: "com.apple.Preview",
        name: "Preview",
        isNative: false,
        launchArguments: []
    )
    
    static let nativeWeb = PlayerInfo(
        id: "native",
        name: "Built-in Browser",
        isNative: true,
        launchArguments: []
    )
    
    static let safari = PlayerInfo(
        id: "com.apple.Safari",
        name: "Safari",
        isNative: false,
        launchArguments: []
    )
    
    static let chrome = PlayerInfo(
        id: "com.google.Chrome",
        name: "Chrome (Kiosk Mode)",
        isNative: false,
        launchArguments: [
            "--kiosk",
            "--noerrdialogs",
            "--disable-infobars",
            "--no-first-run",
            "--disable-translate",
            "--disable-features=TranslateUI",
            "--check-for-update-interval=31536000"
        ]
    )
    
    static let keynote = PlayerInfo(
        id: "com.apple.iWork.Keynote",
        name: "Keynote",
        isNative: false,
        launchArguments: []
    )
}

// MARK: - Player Registry

actor PlayerRegistry {
    static let shared = PlayerRegistry()
    
    private let players: [ContentType: [PlayerInfo]] = [
        .video: [.nativeVideo, .quicktime, .iina, .vlc],
        .pdf: [.nativePDF, .preview],
        .website: [.nativeWeb, .safari, .chrome],
        .keynote: [.keynote]
    ]
    
    func availablePlayers(for type: ContentType) -> [PlayerInfo] {
        players[type] ?? []
    }
    
    func installedPlayers(for type: ContentType) async -> [PlayerInfo] {
        let all = players[type] ?? []
        return all.filter { info in
            info.isNative || isAppInstalled(bundleID: info.id)
        }
    }
    
    func defaultPlayer(for type: ContentType) -> PlayerInfo? {
        players[type]?.first
    }
    
    private nonisolated func isAppInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
}

// MARK: - Content Configuration

struct ContentConfiguration: Codable, Sendable {
    var contentPath: String
    var contentType: ContentType
    var playerID: String
    var loopContent: Bool
    var slideshowInterval: Int
    var webRefreshInterval: Int
    
    init(
        contentPath: String,
        contentType: ContentType,
        playerID: String = "native",
        loopContent: Bool = true,
        slideshowInterval: Int = 5,
        webRefreshInterval: Int = 0
    ) {
        self.contentPath = contentPath
        self.contentType = contentType
        self.playerID = playerID
        self.loopContent = loopContent
        self.slideshowInterval = slideshowInterval
        self.webRefreshInterval = webRefreshInterval
    }
    
    var contentURL: URL? {
        if contentPath.hasPrefix("http://") || contentPath.hasPrefix("https://") {
            return URL(string: contentPath)
        }
        return URL(fileURLWithPath: contentPath)
    }
    
    var isNativePlayer: Bool {
        playerID == "native"
    }
}
