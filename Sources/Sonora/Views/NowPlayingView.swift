import SwiftUI

struct NowPlayingView: View {
  var track: Track?
  var lyricsState: LyricsLookupState
  var currentTime: TimeInterval
  @Binding var lyricsOffset: TimeInterval
  var onSeek: ((TimeInterval) -> Void)? = nil
  var onReloadLyrics: (() -> Void)? = nil
  var onSwitchSource: ((String) -> Void)? = nil

  var body: some View {
    Group {
      if let track {
        VStack(alignment: .leading, spacing: 28) {
          TrackHeaderView(track: track)
          LyricsPanelView(
            state: lyricsState,
            currentTime: currentTime,
            lyricsOffset: $lyricsOffset,
            onSeek: onSeek,
            onReload: onReloadLyrics,
            onSwitchSource: onSwitchSource
          )
        }
        .padding(32)
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
      } else {
        EmptyLibraryView()
      }
    }
  }
}

private struct TrackHeaderView: View {
  var track: Track

  var body: some View {
    HStack(alignment: .center, spacing: 20) {
      TrackArtworkView(
        artworkData: track.artworkData,
        cornerRadius: 8,
        iconSize: 38
      )
        .frame(width: 112, height: 112)

      VStack(alignment: .leading, spacing: 8) {
        Text(track.title)
          .font(.system(.largeTitle, design: .rounded, weight: .semibold))
          .lineLimit(2)

        Text(track.artist)
          .font(.title3)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        HStack(spacing: 12) {
          Label(track.fileExtension.uppercased(), systemImage: "waveform")
          Label(TimeFormatter.playbackTime(track.duration), systemImage: "clock")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }
}

private struct EmptyLibraryView: View {
  var body: some View {
    ContentUnavailableView {
      Label("No Track Selected", systemImage: "music.note.list")
    } description: {
      Text("Import local music to start building your Sonora library. Sonora will read metadata from supported files and prepare them for playback and lyric matching.")
    }
  }
}
