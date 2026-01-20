import CoreGraphics
import Foundation
import IOKit

// MARK: - Display Service

actor DisplayService {
    static let shared = DisplayService()
    
    // MARK: - Display Enumeration
    
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
                    width: CGFloat(mode?.width ?? Int(bounds.width)),
                    height: CGFloat(mode?.height ?? Int(bounds.height))
                ),
                refreshRate: mode?.refreshRate ?? 0
            )
        }
    }
    
    func mainDisplay() -> DisplayInfo? {
        listDisplays().first { $0.isMain }
    }
    
    func display(at index: Int) -> DisplayInfo? {
        let displays = listDisplays()
        guard index >= 0, index < displays.count else { return nil }
        return displays[index]
    }
    
    // MARK: - Display Name via IOKit
    
    private func displayName(for displayID: CGDirectDisplayID) -> String {
        let vendorNumber = CGDisplayVendorNumber(displayID)
        let modelNumber = CGDisplayModelNumber(displayID)
        
        // Try to get EDID name via IOKit
        if let name = edidDisplayName(vendorNumber: vendorNumber, modelNumber: modelNumber) {
            return name
        }
        
        // Fallback names
        if CGDisplayIsBuiltin(displayID) == 1 {
            return "Built-in Display"
        }
        
        return "Display \(displayID)"
    }
    
    private func edidDisplayName(vendorNumber: UInt32, modelNumber: UInt32) -> String? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            guard let infoDict = IODisplayCreateInfoDictionary(
                service,
                IOOptionBits(kIODisplayOnlyPreferredName)
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }
            
            // Check vendor and model match
            guard let displayVendor = infoDict[kDisplayVendorID] as? UInt32,
                  let displayModel = infoDict[kDisplayProductID] as? UInt32,
                  displayVendor == vendorNumber,
                  displayModel == modelNumber else {
                continue
            }
            
            // Get localized name
            if let names = infoDict[kDisplayProductName] as? [String: String],
               let name = names.values.first {
                return name
            }
        }
        
        return nil
    }
    
    // MARK: - Display Modes
    
    func availableModes(for displayID: CGDirectDisplayID) -> [DisplayMode] {
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] else {
            return []
        }
        
        let currentMode = CGDisplayCopyDisplayMode(displayID)
        
        return modes.enumerated().map { index, mode in
            DisplayMode(
                id: Int32(index),
                width: mode.width,
                height: mode.height,
                refreshRate: mode.refreshRate,
                isNative: mode.width == currentMode?.width && mode.height == currentMode?.height
            )
        }
    }
    
    // MARK: - Display Configuration
    
    func setResolution(
        displayID: CGDirectDisplayID,
        width: Int,
        height: Int,
        refreshRate: Double = 0
    ) async throws {
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
    
    // MARK: - Mirroring
    
    func setMirroring(primary: CGDirectDisplayID, mirrors: [CGDirectDisplayID]) async throws {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            throw DisplayError.configurationFailed
        }
        
        for mirrorID in mirrors {
            guard mirrorID != primary else { continue }
            CGConfigureDisplayMirrorOfDisplay(config, mirrorID, primary)
        }
        
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.mirroringFailed
        }
    }
    
    func disableMirroring() async throws {
        let displays = listDisplays()
        
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else {
            throw DisplayError.configurationFailed
        }
        
        for display in displays {
            CGConfigureDisplayMirrorOfDisplay(config, display.id, kCGNullDirectDisplay)
        }
        
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        guard result == .success else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError.configurationFailed
        }
    }
    
    // MARK: - Spanning
    
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
    
    func frame(for config: DisplayConfiguration) -> CGRect {
        if config.spanAllDisplays {
            return spanningFrame()
        }
        
        guard let display = display(at: config.displayIndex) else {
            return mainDisplay()?.bounds ?? .zero
        }
        
        return display.bounds
    }
}
