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

# Build and create app bundle (unsigned)
make app

# Full signed build with PKG and DMG
cp .env.example .env
# Edit .env with signing credentials
make release

# Run tests
swift test

# Run tests with make
make test
```

### Build Targets

The Makefile provides several targets:

| Target | Description |
|--------|-------------|
| `make build` | Build Swift package (release) |
| `make app` | Create unsigned app bundle |
| `make sign` | Code sign app bundle |
| `make pkg` | Create signed installer package |
| `make dmg` | Create signed DMG |
| `make notarize` | Submit for notarization |
| `make release` | Full pipeline (build, sign, pkg, dmg, notarize) |
| `make test` | Run unit tests |
| `make clean` | Clean build artifacts |
| `make run` | Build and run |

### Signing Configuration

To build signed releases, create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```bash
SIGNING_IDENTITY=Developer ID Application: Your Name (TEAMID)
INSTALLER_IDENTITY=Developer ID Installer: Your Name (TEAMID)
KEYCHAIN=${HOME}/Library/Keychains/signing.keychain
NOTARIZATION_PROFILE=notarization_credentials
```

Setup notarization profile:

```bash
xcrun notarytool store-credentials notarization_credentials \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
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
      ca.ecuad.macadmins.plinth.agent.plist

Tests/PlinthTests/
  PlinthTests.swift         - Unit tests
```

### Code Style

- Use Swift 6.2 strict concurrency
- All actors and MainActor annotations as appropriate
- No emojis in code or documentation
- Prefer async/await over completion handlers
- Use Swift Testing framework (@Test, #expect)
