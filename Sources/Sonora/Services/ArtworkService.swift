import Foundation

protocol ArtworkProvider: Sendable {
  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> ArtworkProviderResult?
}

struct ArtworkProviderResult: Sendable {
  var artworkData: Data?
  var releaseYear: String?
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
    guard track.artworkData == nil || track.releaseYear?.isEmpty != false else { return }

    var resolvedArtworkData = track.artworkData

    if let cached = cacheStore.load(for: track.fileFingerprint) {
      resolvedArtworkData = cached
      latestArtworkSuggestion = ArtworkSuggestion(
        trackID: track.id,
        artworkData: cached,
      releaseYear: track.releaseYear
      )

      if track.releaseYear?.isEmpty == false {
        return
      }
    }

    let identity = TrackMetadataNormalizer.normalize(track.identity)
    guard let result = try? await provider.fetchArtwork(for: identity) else { return }

    let artworkData = result.artworkData
    let releaseYear = normalizedReleaseYear(result.releaseYear)

    guard (artworkData?.isEmpty == false) || releaseYear != nil else { return }

    if let artworkData, !artworkData.isEmpty {
      resolvedArtworkData = artworkData
      cacheStore.save(artworkData, for: track.fileFingerprint)
    }

    latestArtworkSuggestion = ArtworkSuggestion(
      trackID: track.id,
      artworkData: resolvedArtworkData,
      releaseYear: releaseYear
    )
  }

  private func normalizedReleaseYear(_ rawValue: String?) -> String? {
    guard let rawValue else { return nil }
    let digits = rawValue.filter(\.isNumber)
    guard digits.count >= 4 else { return nil }
    return String(digits.prefix(4))
  }
}
