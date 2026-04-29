import SwiftUI

struct NowPlayingView: View {
  var track: Track?
  var lyricsState: LyricsLookupState
  var currentTime: TimeInterval

  var body: some View {
    Group {
      if let track {
        ScrollView {
          VStack(alignment: .leading, spacing: 28) {
            TrackHeaderView(track: track)
            LyricsPanelView(state: lyricsState, currentTime: currentTime)
          }
          .padding(32)
          .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
      RoundedRectangle(cornerRadius: 8)
        .fill(.quaternary)
        .frame(width: 112, height: 112)
        .overlay {
          Image(systemName: "music.note")
            .font(.system(size: 38, weight: .medium))
            .foregroundStyle(.secondary)
        }

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
      Text("Import local music to start building your Sonora library.")
    }
  }
}
