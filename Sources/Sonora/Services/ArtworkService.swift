import Foundation

protocol ArtworkProvider: Sendable {
  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> Data?
}

@MainActor
final class ArtworkService: ObservableObject {
  @Published private(set) var latestArtworkSuggestion: ArtworkSuggestion?

  private let provider: ArtworkProvider
  private let cacheStore: ArtworkCacheStore

  init(
    provider: ArtworkProvider = iTunesArtworkProvider(),
    cacheStore: ArtworkCacheStore = ArtworkCacheStore()
  ) {
    self.provider = provider
    self.cacheStore = cacheStore
  }

  func fetchArtwork(for track: Track?) async {
    guard let track else { return }
    guard track.artworkData == nil else { return }

    if let cached = cacheStore.load(for: track.fileFingerprint) {
      latestArtworkSuggestion = ArtworkSuggestion(trackID: track.id, artworkData: cached)
      return
    }

    let identity = TrackMetadataNormalizer.normalize(track.identity)
    guard let data = try? await provider.fetchArtwork(for: identity), !data.isEmpty else { return }

    cacheStore.save(data, for: track.fileFingerprint)
    latestArtworkSuggestion = ArtworkSuggestion(trackID: track.id, artworkData: data)
  }
}
