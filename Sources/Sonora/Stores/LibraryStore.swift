import Combine
import Foundation

@MainActor
final class LibraryStore: ObservableObject {
  @Published var tracks: [Track]
  @Published var selectedTrackID: Track.ID?

  var selectedTrack: Track? {
    tracks.first { $0.id == selectedTrackID }
  }

  init(tracks: [Track] = []) {
    self.tracks = tracks
    self.selectedTrackID = tracks.first?.id
  }

  func importFiles() {
    // Real file picking and metadata import land in the local import milestone.
  }

  static func preview() -> LibraryStore {
    LibraryStore(tracks: [
      Track(
        title: "Midnight Local",
        artist: "Sonora Demo",
        album: "Preview Library",
        duration: 214,
        fileExtension: "m4a",
        fileFingerprint: "preview-midnight-local"
      ),
      Track(
        title: "Static Waves",
        artist: "Sonora Demo",
        album: "Preview Library",
        duration: 188,
        fileExtension: "flac",
        fileFingerprint: "preview-static-waves"
      ),
      Track(
        title: "First Light",
        artist: "Sonora Demo",
        album: "Preview Library",
        duration: 242,
        fileExtension: "mp3",
        fileFingerprint: "preview-first-light"
      )
    ])
  }
}
