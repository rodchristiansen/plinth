# Plinth

## Build Status
[![Build and Release](https://github.com/emilycarru-its-infra/plinth/actions/workflows/build.yml/badge.svg)](https://github.com/emilycarru-its-infra/plinth/actions/workflows/build.yml)

## Development

### Prerequisites

- macOS 15.0 or later
- Xcode 16 or later
- Swift 6.2

### Building

```bash
# Build debug
swift build

# Build release
swift build -c release

# Run tests
swift test
```

### Project Structure

```
Sources/Plinth/
  App/
    PlinthApp.swift         - SwiftUI app entry point
    AppDelegate.swift       - NSApplicationDelegate for kiosk mode
  Models/
    ContentConfiguration.swift   - Content types and player definitions
    DisplayConfiguration.swift   - Display settings
    KioskConfiguration.swift     - Kiosk lockdown settings
    PlinthConfiguration.swift    - UserDefaults-backed preferences
  Services/
    ContentService.swift    - Content launching and management
    DisplayService.swift    - Native CoreGraphics display APIs
    KeynoteService.swift    - Keynote AppleScript automation
    KioskService.swift      - System lockdown and power management
    LaunchAgentService.swift - SMAppService registration
  Views/
    ContentView.swift       - Main view router
    ConfigurationView.swift - Drop target and settings UI
    KioskContentView.swift  - Fullscreen content display
    SettingsView.swift      - App preferences
    Renderers/
      VideoPlayerView.swift - AVPlayer-based video
      PDFViewerView.swift   - PDFKit-based slideshow
      WebViewerView.swift   - WKWebView-based browser
  Resources/
    Info.plist
    Plinth.entitlements
    Assets.xcassets/
    LaunchAgents/
      com.github.macadmins.Plinth.Agent.plist

Tests/PlinthTests/
  PlinthTests.swift         - Unit tests
```

### Code Style

- Use Swift 6.2 strict concurrency
- All actors and MainActor annotations as appropriate
- No emojis in code or documentation
- Prefer async/await over completion handlers
- Use Swift Testing framework (@Test, #expect)
