import SwiftUI

struct ContentView: View {
  @StateObject private var libraryStore = LibraryStore()
  @StateObject private var playerCore = PlayerCore()
  @StateObject private var lyricsService = LyricsService()
  @StateObject private var artworkService = ArtworkService()
  @AppStorage("autoDownloadLyrics") private var autoDownloadLyrics = true

  var body: some View {
    VStack(spacing: 0) {
      NavigationSplitView {
        SidebarView(libraryStore: libraryStore)
      } detail: {
        NowPlayingView(
          track: playerCore.currentTrack,
          lyricsState: lyricsService.state,
          currentTime: playerCore.currentTime,
          onSeek: { time in
            guard let duration = playerCore.currentTrack?.duration, duration > 0 else { return }
            playerCore.seek(to: time / duration)
          },
          onReloadLyrics: {
            lyricsService.reloadLyrics(for: playerCore.currentTrack)
          },
          onSwitchSource: { providerName in
            lyricsService.reloadLyrics(for: playerCore.currentTrack, ignoring: [providerName])
          }
        )
      }

      Divider()

      PlayerBarView(playerCore: playerCore)
    }
    .onAppear {
      playerCore.updateQueue(libraryStore.tracks)
      playerCore.load(libraryStore.selectedTrack)
      lyricsService.loadLyrics(for: playerCore.currentTrack)
      Task { await artworkService.fetchArtwork(for: playerCore.currentTrack) }
    }
    .onChange(of: libraryStore.tracks) { _, tracks in
      playerCore.updateQueue(tracks)
    }
    .onChange(of: libraryStore.selectedTrackID) { _, _ in
      if playerCore.currentTrack?.id != libraryStore.selectedTrackID {
        playerCore.load(libraryStore.selectedTrack)
      }
    }
    .onChange(of: playerCore.currentTrack?.id) { _, trackID in
      if libraryStore.selectedTrackID != trackID {
        libraryStore.selectedTrackID = trackID
      }

      lyricsService.loadLyrics(for: playerCore.currentTrack)
      Task { await artworkService.fetchArtwork(for: playerCore.currentTrack) }
    }
    .onChange(of: autoDownloadLyrics) { _, _ in
      lyricsService.loadLyrics(for: playerCore.currentTrack)
    }
    .onChange(of: artworkService.latestArtworkSuggestion) { _, suggestion in
      guard let suggestion else { return }
      libraryStore.updateArtwork(for: suggestion.trackID, artworkData: suggestion.artworkData)
    }
    .onDeleteCommand {
      libraryStore.removeSelectedTrack()
    }
    .sheet(
      item: Binding(
        get: { libraryStore.activeImportSummary },
        set: { libraryStore.activeImportSummary = $0 }
      )
    ) { summary in
      ImportSummaryView(
        summary: summary,
        dismiss: libraryStore.dismissImportSummary
      )
    }
  }
}
