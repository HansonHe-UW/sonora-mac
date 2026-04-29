import SwiftUI

struct SidebarView: View {
  @ObservedObject var libraryStore: LibraryStore

  var body: some View {
    VStack(spacing: 0) {
      List(selection: $libraryStore.selectedTrackID) {
        if let summary = libraryStore.lastImportSummary {
          Section {
            ImportStatusRow(summary: summary) {
              libraryStore.presentImportSummary()
            }
          }
        }

        Section("Library") {
          if libraryStore.tracks.isEmpty {
            Text("No local music imported yet.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(libraryStore.tracks) { track in
              TrackRow(track: track)
                .tag(track.id as Track.ID?)
                .contextMenu {
                  Button(role: .destructive) {
                    libraryStore.removeTracks(withIDs: [track.id])
                  } label: {
                    Label("Remove from Library", systemImage: "trash")
                  }
                }
            }
          }
        }
      }
      .overlay {
        if libraryStore.isImporting {
          ProgressView("Importing...")
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)

      Divider()

      HStack(spacing: 10) {
        Button {
          libraryStore.importFiles()
        } label: {
          Label("Import Music", systemImage: "plus")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .disabled(libraryStore.isImporting)
        .help("Import local audio files")

        Button(role: .destructive) {
          libraryStore.removeSelectedTrack()
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .disabled(libraryStore.selectedTrackID == nil)
        .help("Remove selected track")
      }
      .padding(12)
    }
  }
}

private struct TrackRow: View {
  var track: Track

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: track.accessState == .available ? "music.note" : "exclamationmark.circle")
        .foregroundStyle(track.accessState == .available ? Color.secondary : Color.orange)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(track.title)
          .lineLimit(1)

        Text(track.accessState.statusText ?? track.artist)
          .font(.caption)
          .foregroundStyle(track.accessState == .available ? Color.secondary : Color.orange)
          .lineLimit(1)
      }
    }
  }
}

private struct ImportStatusRow: View {
  var summary: TrackImportSummary
  var showDetails: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: summary.totalProblemCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
        .foregroundStyle(summary.totalProblemCount == 0 ? .green : .orange)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 4) {
        Text(summary.statusText)
          .font(.caption.weight(.medium))

        if summary.totalProblemCount > 0 {
          Button("Review import issues", action: showDetails)
            .buttonStyle(.link)
            .font(.caption)
        }
      }
    }
    .padding(.vertical, 2)
  }
}
