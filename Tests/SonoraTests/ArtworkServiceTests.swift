import Foundation
import Testing
@testable import Sonora

@MainActor
struct ArtworkServiceTests {
  @Test
  func skipsTrackWithEmbeddedArtwork() async {
    let provider = StubArtworkProvider(result: Data("fetched".utf8))
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp1", artworkData: Data("embedded".utf8))
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion == nil)
    #expect(provider.callCount == 0)
  }

  @Test
  func fetchesFromProviderWhenNoEmbeddedArtwork() async {
    let artworkData = Data("artwork-bytes".utf8)
    let provider = StubArtworkProvider(result: artworkData)
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp2")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.trackID == track.id)
    #expect(service.latestArtworkSuggestion?.artworkData == artworkData)
  }

  @Test
  func usesCachedArtworkWithoutCallingProvider() async {
    let cachedData = Data("cached-art".utf8)
    let provider = StubArtworkProvider(result: Data("fresh-art".utf8))
    let cacheDir = tempDir()
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    store.save(cachedData, for: "fp-cached")
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-cached")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.artworkData == cachedData)
    #expect(provider.callCount == 0)
  }

  @Test
  func publishesNoSuggestionWhenProviderFindsNothing() async {
    let provider = StubArtworkProvider(result: nil)
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-miss")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion == nil)
  }

  @Test
  func cachesProviderResultForSubsequentLookups() async {
    let artworkData = Data("art".utf8)
    let provider = StubArtworkProvider(result: artworkData)
    let cacheDir = tempDir()
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-cache-write")
    await service.fetchArtwork(for: track)

    #expect(store.load(for: "fp-cache-write") == artworkData)
    #expect(provider.callCount == 1)
  }
}

private func tempDir() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func makeTrack(fingerprint: String, artworkData: Data? = nil) -> Track {
  Track(
    title: "Song",
    artist: "Artist",
    fileExtension: "mp3",
    fileFingerprint: fingerprint,
    artworkData: artworkData
  )
}

private final class StubArtworkProvider: ArtworkProvider, @unchecked Sendable {
  let result: Data?
  private(set) var callCount = 0

  init(result: Data?) {
    self.result = result
  }

  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> Data? {
    callCount += 1
    return result
  }
}
