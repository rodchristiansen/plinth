import SwiftUI

@main
struct PlinthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .plinthWebZoomIn, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .plinthWebZoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .plinthWebZoomReset, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
