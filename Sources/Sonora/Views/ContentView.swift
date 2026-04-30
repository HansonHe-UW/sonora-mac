import SwiftUI

struct ContentView: View {
  @ObservedObject var libraryStore: LibraryStore
  @ObservedObject var playerCore: PlayerCore
  @ObservedObject var lyricsService: LyricsService
  @ObservedObject var artworkService: ArtworkService
  @AppStorage("autoDownloadLyrics") private var autoDownloadLyrics = true
  @AppStorage("defaultLyricsOffset") private var defaultLyricsOffset = 0.0

  var body: some View {
    VStack(spacing: 0) {
      NavigationSplitView {
        SidebarView(libraryStore: libraryStore)
      } detail: {
        NowPlayingView(
          track: playerCore.currentTrack,
          lyricsState: lyricsService.state,
          currentTime: playerCore.currentTime,
          lyricsOffset: $defaultLyricsOffset,
          onSeek: { time in
            guard let duration = playerCore.currentTrack?.duration, duration > 0 else { return }
            let adjustedTime = LyricsTiming.seekTime(forLyricTime: time, offset: defaultLyricsOffset)
            playerCore.seek(to: adjustedTime / duration)
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

      if playerCore.currentTrack == nil {
        playerCore.load(libraryStore.selectedTrack)
      } else if libraryStore.selectedTrackID != playerCore.currentTrack?.id {
        libraryStore.selectedTrackID = playerCore.currentTrack?.id
      }

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
      libraryStore.applyArtworkSuggestion(suggestion)
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
