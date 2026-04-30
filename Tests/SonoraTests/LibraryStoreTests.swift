import Foundation
import Testing
@testable import Sonora

@MainActor
struct LibraryStoreTests {
  @Test
  func removeSelectedTrackFallsBackToNextTrack() {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = LibraryStore(
      tracks: [
        Track(title: "First", artist: "Artist", fileExtension: "mp3", fileFingerprint: "1"),
        Track(title: "Second", artist: "Artist", fileExtension: "mp3", fileFingerprint: "2"),
        Track(title: "Third", artist: "Artist", fileExtension: "mp3", fileFingerprint: "3")
      ],
      persistenceStore: LibraryPersistenceStore(fileURL: tempDirectory.appendingPathComponent("library.json"))
    )

    store.selectedTrackID = store.tracks[1].id
    store.removeSelectedTrack()

    #expect(store.tracks.map(\.title) == ["First", "Third"])
    #expect(store.selectedTrack?.title == "Third")

    try? FileManager.default.removeItem(at: tempDirectory)
  }

  @Test
  func preservesManualTrackOrder() {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let orderedTracks = [
      Track(title: "Track 01", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "1"),
      Track(title: "Track 02", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "2"),
      Track(title: "Track 03", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "3")
    ]

    let store = LibraryStore(
      tracks: orderedTracks,
      persistenceStore: LibraryPersistenceStore(fileURL: tempDirectory.appendingPathComponent("library.json"))
    )

    #expect(store.tracks.map(\.title) == ["Track 01", "Track 02", "Track 03"])

    try? FileManager.default.removeItem(at: tempDirectory)
  }

  @Test
  func movesTrackBeforeAnotherTrack() {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let orderedTracks = [
      Track(title: "Track 01", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "1"),
      Track(title: "Track 02", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "2"),
      Track(title: "Track 03", artist: "Album Artist", fileExtension: "mp3", fileFingerprint: "3")
    ]

    let store = LibraryStore(
      tracks: orderedTracks,
      persistenceStore: LibraryPersistenceStore(fileURL: tempDirectory.appendingPathComponent("library.json"))
    )

    store.moveTrack(withID: orderedTracks[2].id, before: orderedTracks[0].id)

    #expect(store.tracks.map(\.title) == ["Track 03", "Track 01", "Track 02"])

    try? FileManager.default.removeItem(at: tempDirectory)
  }
}
