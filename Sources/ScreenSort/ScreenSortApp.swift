import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Configure the main window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApplication.shared.windows.first {
                // Set minimum window size
                window.minSize = NSSize(width: 900, height: 650)
                
                // Make window level normal (won't appear over fullscreen apps)
                window.level = .normal
                
                // Allow window to be resized
                window.styleMask.insert(.resizable)
                
                // Prevent fullscreen activation for compatibility
                if #available(macOS 10.15, *) {
                    window.collectionBehavior = [.managed, .participatesInCycle]
                }
                
                // Center the window
                window.center()
            }
        }
    }
}

@main
struct ScreenSortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ScreenshotViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 650)
                .environmentObject(viewModel)
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
