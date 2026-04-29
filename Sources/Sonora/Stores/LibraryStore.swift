import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
  @Published var tracks: [Track]
  @Published var selectedTrackID: Track.ID? {
    didSet {
      persistSnapshot()
    }
  }
  @Published private(set) var isImporting = false
  @Published private(set) var lastImportSummary: TrackImportSummary?
  @Published var activeImportSummary: TrackImportSummary?

  private let importer: TrackImporter
  private let persistenceStore: LibraryPersistenceStore

  var selectedTrack: Track? {
    tracks.first { $0.id == selectedTrackID }
  }

  init(
    tracks: [Track] = [],
    importer: TrackImporter = TrackImporter(),
    persistenceStore: LibraryPersistenceStore = LibraryPersistenceStore()
  ) {
    self.importer = importer
    self.persistenceStore = persistenceStore

    if tracks.isEmpty {
      let snapshot = persistenceStore.loadSnapshot()
      let refreshedTracks = snapshot.tracks.map(TrackAccessResolver.refresh(_:))
      self.tracks = refreshedTracks
      self.selectedTrackID = snapshot.selectedTrackID.flatMap { selectedTrackID in
        refreshedTracks.contains(where: { $0.id == selectedTrackID }) ? selectedTrackID : refreshedTracks.first?.id
      }
      persistSnapshot()
    } else {
      self.tracks = tracks
      self.selectedTrackID = tracks.first?.id
    }
  }

  func importFiles() {
    let panel = NSOpenPanel()
    panel.title = "Import Local Music"
    panel.message = "Choose audio files or folders for Sonora."
    panel.prompt = "Import"
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = AudioFormatPolicy.supportedContentTypes

    guard panel.runModal() == .OK else { return }

    isImporting = true
    let selectedURLs = ImportSourceCollector.collectCandidateFiles(from: panel.urls)

    Task {
      let batch = await importer.importTracks(from: selectedURLs)
      applyImportBatch(batch)
      isImporting = false
    }
  }

  func dismissImportSummary() {
    activeImportSummary = nil
  }

  func presentImportSummary() {
    guard let lastImportSummary else { return }
    activeImportSummary = lastImportSummary
  }

  func updateArtwork(for trackID: Track.ID, artworkData: Data) {
    guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
    tracks[index].artworkData = artworkData
    persistSnapshot()
  }

  func removeSelectedTrack() {
    guard let selectedTrackID else { return }
    removeTracks(withIDs: [selectedTrackID])
  }

  func removeTracks(withIDs trackIDs: [Track.ID]) {
    guard !trackIDs.isEmpty else { return }

    let trackIDSet = Set(trackIDs)
    let previousSelectionIndex = selectedTrackID.flatMap { selectedTrackID in
      tracks.firstIndex(where: { $0.id == selectedTrackID })
    }

    tracks.removeAll { trackIDSet.contains($0.id) }

    if let selectedTrackID, trackIDSet.contains(selectedTrackID) {
      if tracks.isEmpty {
        self.selectedTrackID = nil
      } else if let previousSelectionIndex {
        let fallbackIndex = min(previousSelectionIndex, tracks.count - 1)
        self.selectedTrackID = tracks[fallbackIndex].id
      } else {
        self.selectedTrackID = tracks.first?.id
      }
    }

    persistSnapshot()
  }

  private func applyImportBatch(_ batch: TrackImportBatch) {
    var newTracks: [Track] = []
    var duplicateCount = 0
    var seenFingerprints = Set(tracks.map(\.fileFingerprint))

    for track in batch.importedTracks {
      guard seenFingerprints.insert(track.fileFingerprint).inserted else {
        duplicateCount += 1
        continue
      }

      newTracks.append(track)
    }

    if !newTracks.isEmpty {
      tracks.append(contentsOf: newTracks)
      if selectedTrackID == nil {
        selectedTrackID = tracks.first?.id
      }
    }

    let summary = TrackImportSummary(
      importedCount: newTracks.count,
      duplicateCount: duplicateCount,
      issues: batch.issues
    )

    lastImportSummary = summary
    if summary.totalProblemCount > 0 {
      activeImportSummary = summary
    }

    persistSnapshot()
  }

  private func persistSnapshot() {
    do {
      try persistenceStore.saveSnapshot(
        LibrarySnapshot(
          tracks: tracks,
          selectedTrackID: selectedTrackID
        )
      )
    } catch {
      // Keep persistence failures non-fatal for the UI workflow.
      NSLog("Failed to persist Sonora library: %@", error.localizedDescription)
    }
  }
}
