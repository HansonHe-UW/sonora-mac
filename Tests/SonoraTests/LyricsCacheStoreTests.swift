import Foundation
import Testing
@testable import Sonora

struct LyricsCacheStoreTests {
  @Test
  func roundTripsCachedLyricsResult() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cacheURL = tempDirectory.appendingPathComponent("lyrics-cache.json")
    let store = LyricsCacheStore(fileURL: cacheURL)

    let result = LyricsResult(
      content: .plain("cached lyrics"),
      attribution: LyricsAttribution(
        providerName: "musixmatch",
        displayName: "Musixmatch",
        copyrightText: "copyright",
        backlinkURLString: "https://example.com",
        pixelTrackingURLString: "https://tracking.example.com"
      ),
      artworkURLString: "https://example.com/art.jpg"
    )

    try store.save(result, for: "fingerprint-1")
    let loaded = store.load(for: "fingerprint-1")

    #expect(loaded == result)

    try? FileManager.default.removeItem(at: tempDirectory)
  }
}
