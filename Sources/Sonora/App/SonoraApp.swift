import AppKit
import SwiftUI

@main
struct SonoraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("Sonora", id: "main") {
      ContentView()
        .frame(minWidth: 920, minHeight: 620)
    }
    .windowResizability(.contentSize)

    Settings {
      SettingsView()
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    guard !flag else { return false }

    if let window = sender.windows.first {
      window.makeKeyAndOrderFront(nil)
      sender.activate(ignoringOtherApps: true)
      return true
    }

    return false
  }
}
