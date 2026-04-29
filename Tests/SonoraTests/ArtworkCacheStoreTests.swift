import Foundation
import Testing
@testable import Sonora

struct ArtworkCacheStoreTests {
  @Test
  func roundTripsArtworkByFingerprint() {
    let cacheDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    let data = Data("fake-image-bytes".utf8)

    store.save(data, for: "fp-abc")
    let loaded = store.load(for: "fp-abc")

    #expect(loaded == data)

    try? FileManager.default.removeItem(at: cacheDir)
  }

  @Test
  func returnsNilForUnknownFingerprint() {
    let cacheDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)

    #expect(store.load(for: "unknown-fp") == nil)
  }

  @Test
  func separateInstancesShareTheSameCache() {
    let cacheDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let data = Data("persisted-art".utf8)

    let writer = ArtworkCacheStore(cacheDirectory: cacheDir)
    writer.save(data, for: "fp-persist")

    let reader = ArtworkCacheStore(cacheDirectory: cacheDir)
    #expect(reader.load(for: "fp-persist") == data)

    try? FileManager.default.removeItem(at: cacheDir)
  }
}
