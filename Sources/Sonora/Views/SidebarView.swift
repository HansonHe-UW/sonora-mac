import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
  @ObservedObject var libraryStore: LibraryStore
  @State private var searchText = ""
  @State private var showClearConfirmation = false

  var body: some View {
    let canReorder = searchText.trimmingCharacters(in: .whitespaces).isEmpty

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
          let visible = SidebarView.filterTracks(libraryStore.tracks, query: searchText)
          if libraryStore.tracks.isEmpty {
            Text("No local music imported yet.")
              .foregroundStyle(.secondary)
          } else if visible.isEmpty {
            Text(verbatim: "No results for \"\(searchText)\".")
              .foregroundStyle(.secondary)
          } else if canReorder {
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
            .onMove { offsets, destination in
              libraryStore.moveTracks(fromOffsets: offsets, toOffset: destination)
            }
          } else {
            ForEach(visible) { track in
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
      .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
        handleDroppedFiles(providers)
      }
      .listStyle(.sidebar)
      .searchable(text: $searchText, placement: .sidebar, prompt: "Search Library")
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

        Button(role: .destructive) {
          showClearConfirmation = true
        } label: {
          Image(systemName: "trash.slash")
        }
        .buttonStyle(.borderless)
        .disabled(libraryStore.tracks.isEmpty)
        .help("Clear all tracks")
      }
      .padding(12)
    }
    .alert("Clear Library", isPresented: $showClearConfirmation) {
      Button("Clear All", role: .destructive) {
        libraryStore.removeAllTracks()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will remove all \(libraryStore.tracks.count) tracks from your library. This cannot be undone.")
    }
  }

  nonisolated static func filterTracks(_ tracks: [Track], query: String) -> [Track] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return tracks }
    let q = trimmed.lowercased()
    return tracks.filter {
      $0.title.lowercased().contains(q) ||
      $0.artist.lowercased().contains(q) ||
      ($0.album?.lowercased().contains(q) ?? false)
    }
  }

  private func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
    let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
    guard !fileProviders.isEmpty else { return false }

    Task {
      let urls = await droppedFileURLs(from: fileProviders)
      guard !urls.isEmpty else { return }
      await MainActor.run {
        libraryStore.importFiles(from: urls)
      }
    }

    return true
  }

  private func droppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
    var urls: [URL] = []

    for provider in providers {
      if let url = await loadFileURL(from: provider) {
        urls.append(url)
      }
    }

    return urls
  }

  private func loadFileURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil) {
          continuation.resume(returning: url)
          return
        }

        if let url = item as? URL {
          continuation.resume(returning: url)
          return
        }

        continuation.resume(returning: nil)
      }
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
