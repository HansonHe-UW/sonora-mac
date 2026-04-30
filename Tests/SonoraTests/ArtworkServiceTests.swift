import Foundation
import Testing
@testable import Sonora

@MainActor
struct ArtworkServiceTests {
  @Test
  func skipsProviderWhenTrackAlreadyHasArtworkAndReleaseYear() async {
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: Data("fetched".utf8), releaseYear: "2013"))
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp1", artworkData: Data("embedded".utf8), releaseYear: "2010")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion == nil)
    #expect(provider.callCount == 0)
  }

  @Test
  func fetchesFromProviderWhenNoEmbeddedArtwork() async {
    let artworkData = Data("artwork-bytes".utf8)
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: artworkData, releaseYear: "2013"))
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp2")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.trackID == track.id)
    #expect(service.latestArtworkSuggestion?.artworkData == artworkData)
    #expect(service.latestArtworkSuggestion?.releaseYear == "2013")
  }

  @Test
  func usesCachedArtworkWithoutCallingProviderWhenReleaseYearAlreadyExists() async {
    let cachedData = Data("cached-art".utf8)
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: Data("fresh-art".utf8), releaseYear: "2013"))
    let cacheDir = tempDir()
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    store.save(cachedData, for: "fp-cached")
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-cached", releaseYear: "2010")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.artworkData == cachedData)
    #expect(provider.callCount == 0)
  }

  @Test
  func refinesCachedArtworkWithReleaseYearWhenMissingLocally() async {
    let cachedData = Data("cached-art".utf8)
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: nil, releaseYear: "2013"))
    let cacheDir = tempDir()
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    store.save(cachedData, for: "fp-cached-year")
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-cached-year")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.artworkData == cachedData)
    #expect(service.latestArtworkSuggestion?.releaseYear == "2013")
    #expect(provider.callCount == 1)
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
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: artworkData, releaseYear: nil))
    let cacheDir = tempDir()
    let store = ArtworkCacheStore(cacheDirectory: cacheDir)
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-cache-write")
    await service.fetchArtwork(for: track)

    #expect(store.load(for: "fp-cache-write") == artworkData)
    #expect(provider.callCount == 1)
  }

  @Test
  func publishesReleaseYearWithoutArtworkWhenProviderSuppliesOnlyMetadata() async {
    let provider = StubArtworkProvider(result: ArtworkProviderResult(artworkData: nil, releaseYear: "2010"))
    let store = ArtworkCacheStore(cacheDirectory: tempDir())
    let service = ArtworkService(provider: provider, cacheStore: store)

    let track = makeTrack(fingerprint: "fp-year-only")
    await service.fetchArtwork(for: track)

    #expect(service.latestArtworkSuggestion?.trackID == track.id)
    #expect(service.latestArtworkSuggestion?.artworkData == nil)
    #expect(service.latestArtworkSuggestion?.releaseYear == "2010")
  }
}

private func tempDir() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func makeTrack(fingerprint: String, artworkData: Data? = nil, releaseYear: String? = nil) -> Track {
  Track(
    title: "Song",
    artist: "Artist",
    releaseYear: releaseYear,
    fileExtension: "mp3",
    fileFingerprint: fingerprint,
    artworkData: artworkData
  )
}

private final class StubArtworkProvider: ArtworkProvider, @unchecked Sendable {
  let result: ArtworkProviderResult?
  private(set) var callCount = 0

  init(result: ArtworkProviderResult?) {
    self.result = result
  }

  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> ArtworkProviderResult? {
    callCount += 1
    return result
  }
}
