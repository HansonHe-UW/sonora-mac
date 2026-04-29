import SwiftUI

struct ContentView: View {
  @StateObject private var libraryStore = LibraryStore.preview()
  @StateObject private var playerCore = PlayerCore()
  @StateObject private var lyricsService = LyricsService()

  var body: some View {
    VStack(spacing: 0) {
      NavigationSplitView {
        SidebarView(libraryStore: libraryStore)
      } detail: {
        NowPlayingView(
          track: libraryStore.selectedTrack,
          lyricsState: lyricsService.state,
          currentTime: playerCore.currentTime
        )
      }

      Divider()

      PlayerBarView(playerCore: playerCore)
    }
    .onAppear {
      playerCore.load(libraryStore.selectedTrack)
      lyricsService.loadPlaceholder(for: libraryStore.selectedTrack)
    }
    .onChange(of: libraryStore.selectedTrackID) { _, _ in
      playerCore.load(libraryStore.selectedTrack)
      lyricsService.loadPlaceholder(for: libraryStore.selectedTrack)
    }
  }
}
