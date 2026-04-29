import AppKit
import SwiftUI

@main
struct SonoraApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var libraryStore = LibraryStore()
  @StateObject private var playerCore = PlayerCore()
  @StateObject private var lyricsService = LyricsService()
  @StateObject private var artworkService = ArtworkService()

  var body: some Scene {
    WindowGroup("Sonora", id: "main") {
      ContentView(
        libraryStore: libraryStore,
        playerCore: playerCore,
        lyricsService: lyricsService,
        artworkService: artworkService
      )
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

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
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
