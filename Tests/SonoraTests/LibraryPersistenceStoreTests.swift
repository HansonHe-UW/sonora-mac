import Foundation
import Testing
@testable import Sonora

struct LibraryPersistenceStoreTests {
  @Test
  func roundTripsSnapshotToDisk() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = tempDirectory.appendingPathComponent("library.json")
    let store = LibraryPersistenceStore(fileURL: fileURL)

    let snapshot = LibrarySnapshot(
      tracks: [
        Track(
          title: "Persisted",
          artist: "Artist",
          album: "Album",
          duration: 123,
          fileExtension: "mp3",
          fileURL: URL(fileURLWithPath: "/tmp/persisted.mp3"),
          fileFingerprint: "fingerprint-1",
          bookmarkData: Data("bookmark".utf8),
          artworkData: Data("art".utf8),
          accessState: .available
        )
      ],
      selectedTrackID: nil
    )

    try store.saveSnapshot(snapshot)
    let loadedSnapshot = store.loadSnapshot()

    #expect(loadedSnapshot == snapshot)

    try? FileManager.default.removeItem(at: tempDirectory)
  }
}
