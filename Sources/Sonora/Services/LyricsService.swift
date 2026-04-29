import Combine
import Foundation

protocol LyricsProvider: Sendable {
  var name: String { get }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate]
  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsResult
}

@MainActor
final class LyricsService: ObservableObject {
  @Published private(set) var state: LyricsLookupState = .empty
  @Published private(set) var latestArtworkSuggestion: ArtworkSuggestion?

  private let cacheStore: LyricsCacheStore
  private let localLRCProvider: LocalLRCProvider
  private let lrclibProvider: LRCLIBProvider
  private var loadTask: Task<Void, Never>?
  private var activeRequestID = UUID()

  init(
    cacheStore: LyricsCacheStore = LyricsCacheStore(),
    localLRCProvider: LocalLRCProvider = LocalLRCProvider(),
    lrclibProvider: LRCLIBProvider = LRCLIBProvider()
  ) {
    self.cacheStore = cacheStore
    self.localLRCProvider = localLRCProvider
    self.lrclibProvider = lrclibProvider
  }

  func loadLyrics(for track: Track?) {
    loadTask?.cancel()
    latestArtworkSuggestion = nil
    activeRequestID = UUID()
    let requestID = activeRequestID

    guard let track else {
      state = .empty
      return
    }

    loadTask = Task { [weak self] in
      guard let self else { return }
      await self.loadLyricsPipeline(for: track, requestID: requestID)
    }
  }

  private func loadLyricsPipeline(for track: Track, requestID: UUID) async {
    guard isActive(requestID) else { return }
    state = .loading("Matching lyrics for \(track.title)...")

    if let cached = cacheStore.load(for: track.fileFingerprint) {
      guard isActive(requestID) else { return }
      state = .ready(cached)
      await fetchArtworkIfNeeded(for: track, result: cached)
      trackLyricsViewIfNeeded(from: cached)
      return
    }

    if let localLyrics = localLRCProvider.loadLyrics(for: track) {
      guard isActive(requestID) else { return }
      state = .ready(localLyrics)
      try? cacheStore.save(localLyrics, for: track.fileFingerprint)
      return
    }

    guard isAutoDownloadEnabled else {
      guard isActive(requestID) else { return }
      state = .unavailable("Automatic lyrics download is disabled in Settings.")
      return
    }

    let normalizedIdentity = TrackMetadataNormalizer.normalize(track.identity)

    do {
      if let lrclibCandidate = try await bestCandidate(from: lrclibProvider, identity: normalizedIdentity) {
        let result = try await lrclibProvider.fetchLyrics(for: lrclibCandidate)
        guard isActive(requestID) else { return }
        try? cacheStore.save(result, for: track.fileFingerprint)
        state = .ready(result)

        if let experimentalProvider = experimentalProviderIfConfigured,
           let experimentalCandidate = try await bestCandidate(from: experimentalProvider, identity: normalizedIdentity) {
          let experimentalResult = try await experimentalProvider.fetchLyrics(for: experimentalCandidate)
          guard isActive(requestID) else { return }
          let merged = LyricsResult(
            content: result.content,
            attribution: result.attribution,
            artworkURLString: experimentalResult.artworkURLString ?? result.artworkURLString
          )
          await fetchArtworkIfNeeded(for: track, result: merged)
        }

        if let musixmatchProvider = musixmatchProviderIfConfigured,
           let musixmatchCandidate = try await bestCandidate(from: musixmatchProvider, identity: normalizedIdentity) {
          guard isActive(requestID) else { return }
          let artworkResult = LyricsResult(
            content: result.content,
            attribution: result.attribution,
            artworkURLString: musixmatchCandidate.artworkURLString
          )
          await fetchArtworkIfNeeded(for: track, result: artworkResult)
        }

        return
      }

      if let musixmatchProvider = musixmatchProviderIfConfigured,
         let musixmatchCandidate = try await bestCandidate(from: musixmatchProvider, identity: normalizedIdentity) {
        let result = try await musixmatchProvider.fetchLyrics(for: musixmatchCandidate)
        guard isActive(requestID) else { return }
        try? cacheStore.save(result, for: track.fileFingerprint)
        state = .ready(result)
        await fetchArtworkIfNeeded(for: track, result: result)
        trackLyricsViewIfNeeded(from: result)
        return
      }

      guard isActive(requestID) else { return }
      state = .unavailable("No online lyrics match found.")
    } catch is CancellationError {
      return
    } catch {
      guard isActive(requestID) else { return }
      state = .unavailable((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }
  }

  private func trackLyricsViewIfNeeded(from result: LyricsResult) {
    guard let trackingURLString = result.attribution.pixelTrackingURLString,
          let trackingURL = URL(string: trackingURLString) else {
      return
    }

    let request = URLRequest(url: trackingURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    URLSession.shared.dataTask(with: request).resume()
  }

  private func fetchArtworkIfNeeded(for track: Track, result: LyricsResult) async {
    guard track.artworkData == nil,
          let artworkURLString = result.artworkURLString,
          let artworkURL = URL(string: artworkURLString) else {
      return
    }

    guard let (data, response) = try? await URLSession.shared.data(from: artworkURL),
          let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200,
          !data.isEmpty else {
      return
    }

    latestArtworkSuggestion = ArtworkSuggestion(trackID: track.id, artworkData: data)
  }

  private var isAutoDownloadEnabled: Bool {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: "autoDownloadLyrics") != nil else { return true }
    return defaults.bool(forKey: "autoDownloadLyrics")
  }

  private var musixmatchProviderIfConfigured: MusixmatchProvider? {
    let apiKey = UserDefaults.standard.string(forKey: "musixmatchAPIKey")?.trimmedForMetadata ?? ""
    guard !apiKey.isEmpty else { return nil }
    return MusixmatchProvider(apiKey: apiKey)
  }

  private var experimentalProviderIfConfigured: ExperimentalLyricsProxyProvider? {
    let defaults = UserDefaults.standard
    let enabled = defaults.object(forKey: "experimentalLyricsProxyEnabled") as? Bool ?? false
    guard enabled else { return nil }

    let urlString = defaults.string(forKey: "experimentalLyricsProxyBaseURL")?.trimmedForMetadata ?? ""
    guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }
    return ExperimentalLyricsProxyProvider(baseURL: url)
  }

  private func bestCandidate(
    from provider: LyricsProvider,
    identity: NormalizedTrackIdentity
  ) async throws -> LyricsCandidate? {
    let candidates = try await provider.search(identity)
    return candidates.max(by: { $0.confidence < $1.confidence })
  }

  private func isActive(_ requestID: UUID) -> Bool {
    activeRequestID == requestID
  }
}
