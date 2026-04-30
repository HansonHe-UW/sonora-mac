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
        .onAppear {
          appDelegate.onTogglePlayPause = { [weak playerCore] in
            playerCore?.togglePlayPause()
          }
        }
        .frame(minWidth: 920, minHeight: 620)
    }
    .windowResizability(.contentSize)
    .commands {
      CommandMenu("Playback") {
        Button(playerCore.playbackState == .playing ? "Pause" : "Play") {
          playerCore.togglePlayPause()
        }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(playerCore.currentTrack == nil)
      }
    }

    Settings {
      SettingsView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var onTogglePlayPause: (() -> Void)?
  private var keyMonitor: Any?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard event.keyCode == 49,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
        return event
      }

      if Self.isTextInputActive() {
        return event
      }

      self?.onTogglePlayPause?()
      return nil
    }
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
  private static func isTextInputActive() -> Bool {
    guard let responder = NSApp.keyWindow?.firstResponder else { return false }

    if responder is NSTextView {
      return true
    }

    if responder.responds(to: #selector(NSTextInputClient.insertText(_:replacementRange:))) {
      return true
    }

    return false
  }
}
