import SwiftUI

struct SidebarView: View {
  @ObservedObject var libraryStore: LibraryStore

  var body: some View {
    List(selection: $libraryStore.selectedTrackID) {
      Section("Library") {
        ForEach(libraryStore.tracks) { track in
          TrackRow(track: track)
            .tag(track.id as Track.ID?)
        }
      }
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom) {
      Button {
        libraryStore.importFiles()
      } label: {
        Label("Import Music", systemImage: "plus")
      }
      .buttonStyle(.borderless)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .help("Import local audio files")
    }
    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
  }
}

private struct TrackRow: View {
  var track: Track

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "music.note")
        .foregroundStyle(.secondary)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(track.title)
          .lineLimit(1)

        Text(track.artist)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
