# Plinth

A modern macOS kiosk application for exhibitions, digital signage, and public displays.

Plinth is a macOS app that transforms any Mac into a dedicated kiosk displaying videos, PDFs, websites, or Keynote presentations in fullscreen mode with automatic recovery and system lockdown capabilities.

## Features

### Content Support

- **Video**: Loop video files using QuickTime, IINA, or VLC
- **PDF**: Display PDF slideshows with configurable timing using Preview or other PDF viewers
- **Website**: Show web content using Safari, Chrome (with --kiosk flag), or native WebKit
- **Keynote**: Run Keynote presentations in slideshow mode with looping

### Kiosk Capabilities

- **Drop-to-Configure**: Drag and drop any supported file or enter a URL to configure
- **Player Selection**: Choose which application handles each content type
- **Auto-Launch**: Register as a login item with crash recovery via embedded LaunchAgent
- **Display Management**: Native multi-display support with mirroring and spanning options
- **System Lockdown**: Hide Dock, menu bar, and disable process switching without MDM
- **Power Management**: Prevent sleep and screensaver activation

### Enterprise Features

- **MDM Integration**: Supports managed preferences for zero-touch deployment
- **Configuration Profiles**: Works alongside MDM profiles for full lockdown
- **Notarized**: Signed and notarized for Gatekeeper compliance

## Requirements

- macOS 15.0 Sequoia or later
- Swift 6.2 runtime

## Installation

### Download

Download the latest release from the [Releases](https://github.com/emilycarru-its-infra/plinth/releases) page.

### Homebrew (Coming Soon)

```bash
brew install --cask plinth
```

### Building from Source

```bash
git clone https://github.com/emilycarru-its-infra/plinth.git
cd plinth

# Quick build (unsigned)
make build

# Full signed release (requires signing certificates)
cp .env.example .env
# Edit .env with your signing credentials
make release
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed build instructions.

## Usage

### Interactive Mode

1. Launch Plinth.app
2. Drag and drop a file (video, PDF, Keynote) or enter a URL
3. Select the player application for that content type
4. Configure display and kiosk options
5. Click "Start Kiosk" to begin fullscreen playback

### Command Line

```bash
# Start with a video file
open -a Plinth --args --file /path/to/video.mp4

# Start with a URL
open -a Plinth --args --url "https://example.com"

# Start with a specific player
open -a Plinth --args --file /path/to/video.mp4 --player iina
```

### Configuration File

Plinth stores its configuration in:

```
~/Library/Preferences/ca.ecuad.macadmins.Plinth.plist
```

Key settings:

| Key | Type | Description |
|-----|------|-------------|
| `ContentPath` | String | Path to content file or URL |
| `ContentType` | String | `video`, `pdf`, `website`, or `keynote` |
| `PlayerApp` | String | Bundle identifier of player application |
| `DisplayIndex` | Integer | Target display (0 = primary, -1 = span all) |
| `EnableLockdown` | Boolean | Enable kiosk lockdown mode |
| `AutoStart` | Boolean | Start playback automatically on launch |
| `LoopContent` | Boolean | Loop video/slideshow content |
| `SlideshowInterval` | Integer | Seconds between PDF pages |

### MDM Deployment

Deploy configuration via MDM profile targeting `ca.ecuad.macadmins.Plinth`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>ca.ecuad.macadmins.Plinth</string>
            <key>PayloadIdentifier</key>
            <string>ca.ecuad.macadmins.Plinth.config</string>
            <key>PayloadUUID</key>
            <string>YOUR-UUID-HERE</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>ContentPath</key>
            <string>https://example.com/kiosk</string>
            <key>ContentType</key>
            <string>website</string>
            <key>EnableLockdown</key>
            <true/>
            <key>AutoStart</key>
            <true/>
        </dict>
    </array>
    <!-- ... standard profile wrapper ... -->
</dict>
</plist>
```

## Architecture

Plinth is built with modern Swift 6.2 using:

- **SwiftUI** for the configuration interface
- **AppKit** for window management and kiosk mode
- **AVFoundation** for native video playback
- **PDFKit** for native PDF rendering
- **WebKit** for native web content
- **CoreGraphics** for native display management
- **ServiceManagement** (SMAppService) for login item registration

### Project Structure

```
Plinth/
  Plinth.xcodeproj/
  Sources/
    App/
      PlinthApp.swift           # Main app entry point
      AppDelegate.swift         # NSApplicationDelegate for kiosk mode
    Models/
      ContentConfiguration.swift # Content and player settings
      DisplayConfiguration.swift # Display arrangement settings
      KioskConfiguration.swift   # Lockdown settings
    Views/
      ConfigurationView.swift    # Main drop target / config UI
      ContentPreviewView.swift   # Preview of configured content
      SettingsView.swift         # Player and display settings
    Services/
      ContentService.swift       # Content type detection and launching
      DisplayService.swift       # Native display management
      KioskService.swift         # Lockdown and power management
      LaunchAgentService.swift   # SMAppService registration
      KeynoteService.swift       # Keynote automation via osascript
    Utilities/
      ProcessUtilities.swift     # App launching helpers
      PowerUtilities.swift       # caffeinate/pmset wrappers
  Resources/
    Assets.xcassets/
  LaunchAgent/
    ca.ecuad.macadmins.Plinth.Agent.plist
```

## Supported Players

### Video

| Player | Bundle ID | Notes |
|--------|-----------|-------|
| QuickTime Player | com.apple.QuickTimePlayerX | Built-in, reliable |
| IINA | com.colliderli.iina | Modern, feature-rich |
| VLC | org.videolan.vlc | Universal format support |
| Native | - | Built-in AVPlayer |

### PDF

| Player | Bundle ID | Notes |
|--------|-----------|-------|
| Preview | com.apple.Preview | Built-in |
| Native | - | Built-in PDFKit with timer |

### Website

| Player | Bundle ID | Notes |
|--------|-----------|-------|
| Safari | com.apple.Safari | Built-in |
| Chrome | com.google.Chrome | Supports --kiosk flag |
| Native | - | Built-in WKWebView |

### Keynote

| Player | Bundle ID | Notes |
|--------|-----------|-------|
| Keynote | com.apple.iWork.Keynote | AppleScript automation |

## Contributing

Contributions are welcome. Please read [IMPLEMENTATION.md](IMPLEMENTATION.md) for architecture details and development guidelines.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

This project consolidates and modernizes kiosk tooling originally developed for Emily Carr University of Art + Design IT Services.

Related legacy components being replaced:

- KioskApps (Automator workflows)
- LoginScripts (shell/AppleScript login items)
- KioskDock (Dock configuration)
- Various MDM profiles for system lockdown
