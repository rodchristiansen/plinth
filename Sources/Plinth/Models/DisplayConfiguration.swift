import CoreGraphics
import Foundation

// MARK: - Display Info

struct DisplayInfo: Identifiable, Sendable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let bounds: CGRect
    let isMain: Bool
    let isBuiltIn: Bool
    let resolution: CGSize
    let refreshRate: Double
    
    var displayDescription: String {
        let prefix = isMain ? "(Main) " : ""
        let builtIn = isBuiltIn ? " [Built-in]" : ""
        return "\(prefix)\(name)\(builtIn) - \(Int(resolution.width))x\(Int(resolution.height))"
    }
}

// MARK: - Display Configuration

struct DisplayConfiguration: Codable, Sendable {
    var displayIndex: Int
    var spanAllDisplays: Bool
    var mirrorDisplays: Bool
    
    init(
        displayIndex: Int = 0,
        spanAllDisplays: Bool = false,
        mirrorDisplays: Bool = false
    ) {
        self.displayIndex = displayIndex
        self.spanAllDisplays = spanAllDisplays
        self.mirrorDisplays = mirrorDisplays
    }
    
    static var primaryDisplay: DisplayConfiguration {
        DisplayConfiguration(displayIndex: 0)
    }
    
    static var spanAll: DisplayConfiguration {
        DisplayConfiguration(spanAllDisplays: true)
    }
}

// MARK: - Display Mode

struct DisplayMode: Identifiable, Sendable {
    let id: Int32
    let width: Int
    let height: Int
    let refreshRate: Double
    let isNative: Bool
    
    var description: String {
        let refresh = refreshRate > 0 ? " @ \(Int(refreshRate))Hz" : ""
        let native = isNative ? " (Native)" : ""
        return "\(width) x \(height)\(refresh)\(native)"
    }
}

// MARK: - Display Errors

enum DisplayError: Error, LocalizedError, Sendable {
    case configurationFailed
    case noDisplaysFound
    case invalidDisplayIndex
    case noModesAvailable
    case modeNotFound
    case mirroringFailed
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Failed to configure display"
        case .noDisplaysFound:
            return "No displays found"
        case .invalidDisplayIndex:
            return "Invalid display index"
        case .noModesAvailable:
            return "No display modes available"
        case .modeNotFound:
            return "Requested display mode not found"
        case .mirroringFailed:
            return "Failed to configure display mirroring"
        }
    }
}
