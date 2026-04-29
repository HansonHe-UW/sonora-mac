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

  private let cacheStore: LyricsCacheStore
  private let localLRCProvider: LocalLRCProvider
  private let lrclibProvider: LRCLIBProvider
  private let neteaseProvider: NeteaseProvider
  private var loadTask: Task<Void, Never>?
  private var activeRequestID = UUID()

  init(
    cacheStore: LyricsCacheStore = LyricsCacheStore(),
    localLRCProvider: LocalLRCProvider = LocalLRCProvider(),
    lrclibProvider: LRCLIBProvider = LRCLIBProvider(),
    neteaseProvider: NeteaseProvider = NeteaseProvider()
  ) {
    self.cacheStore = cacheStore
    self.localLRCProvider = localLRCProvider
    self.lrclibProvider = lrclibProvider
    self.neteaseProvider = neteaseProvider
  }

  func loadLyrics(for track: Track?, ignoring providers: Set<String> = []) {
    loadTask?.cancel()
    activeRequestID = UUID()
    let requestID = activeRequestID

    guard let track else {
      state = .empty
      return
    }

    loadTask = Task { [weak self] in
      guard let self else { return }
      await self.loadLyricsPipeline(for: track, requestID: requestID, ignoring: providers)
    }
  }

  func reloadLyrics(for track: Track?, ignoring providers: Set<String> = []) {
    guard let track else { return }
    cacheStore.remove(for: track.fileFingerprint)
    loadLyrics(for: track, ignoring: providers)
  }

  private func loadLyricsPipeline(for track: Track, requestID: UUID, ignoring providers: Set<String>) async {
    guard isActive(requestID) else { return }
    state = .loading("Matching lyrics for \(track.title)...")

    if let cached = cacheStore.load(for: track.fileFingerprint) {
      guard isActive(requestID) else { return }
      state = .ready(cached)
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
      state = .unavailable(.downloadDisabled)
      return
    }

    let normalizedIdentity = TrackMetadataNormalizer.normalize(track.identity)

    do {
      do {
        if !providers.contains(neteaseProvider.name),
           let neteaseCandidate = try await bestCandidate(from: neteaseProvider, identity: normalizedIdentity) {
          let result = try await neteaseProvider.fetchLyrics(for: neteaseCandidate)
          guard isActive(requestID) else { return }
          try? cacheStore.save(result, for: track.fileFingerprint)
          state = .ready(result)
          return
        }
      } catch is CancellationError {
        return
      } catch {
        // NetEase unavailable, fall through to LRCLIB
      }

      if !providers.contains(lrclibProvider.name),
         let lrclibCandidate = try await bestCandidate(from: lrclibProvider, identity: normalizedIdentity) {
        let result = try await lrclibProvider.fetchLyrics(for: lrclibCandidate)
        guard isActive(requestID) else { return }
        try? cacheStore.save(result, for: track.fileFingerprint)
        state = .ready(result)
        return
      }

      guard isActive(requestID) else { return }
      state = .unavailable(.noMatch)
    } catch is CancellationError {
      return
    } catch {
      guard isActive(requestID) else { return }
      let reason: LyricsUnavailableReason
      if (error as? URLError) != nil {
        reason = .networkFailure
      } else {
        reason = .providerError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
      }
      state = .unavailable(reason)
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

  private var isAutoDownloadEnabled: Bool {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: "autoDownloadLyrics") != nil else { return true }
    return defaults.bool(forKey: "autoDownloadLyrics")
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
    let best = candidates.max(by: { $0.confidence < $1.confidence })
    if let best = best, best.confidence >= 0.5 {
      return best
    }
    return nil
  }

  private func isActive(_ requestID: UUID) -> Bool {
    activeRequestID == requestID
  }
}
