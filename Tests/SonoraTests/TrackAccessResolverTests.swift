import Foundation
import Testing
@testable import Sonora

struct TrackAccessResolverTests {
  @Test
  func fallsBackToStoredFileURLWhenBookmarkCannotBeResolved() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let fileURL = tempDirectory.appendingPathComponent("sample.mp3")
    try Data("audio".utf8).write(to: fileURL)

    let track = Track(
      title: "Sample",
      artist: "Artist",
      fileExtension: "mp3",
      fileURL: fileURL,
      fileFingerprint: "fingerprint",
      bookmarkData: Data("invalid-bookmark".utf8)
    )

    let refreshed = TrackAccessResolver.refresh(track)

    #expect(refreshed.accessState == .available)
    #expect(refreshed.fileURL == fileURL)

    try? FileManager.default.removeItem(at: tempDirectory)
  }
}
