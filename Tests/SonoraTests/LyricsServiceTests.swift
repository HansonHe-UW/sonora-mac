import Foundation
import Testing
@testable import Sonora

@MainActor
@Suite(.serialized)
struct LyricsServiceTests {
  @Test
  func upgradesCachedLRCLIBResultToNetEaseWhenPreferredResultExists() async throws {
    let restoreAutoDownload = forceAutoDownloadLyricsEnabled()
    defer { restoreAutoDownload() }

    let cacheURL = makeCacheURL()
    let cacheStore = LyricsCacheStore(fileURL: cacheURL)
    let track = makeTrack(fingerprint: "cached-lrclib")
    let cachedResult = LyricsResult(
      content: .plain("cached lrclib lyrics"),
      attribution: LyricsAttribution(
        providerName: "lrclib",
        displayName: "LRCLIB",
        copyrightText: nil,
        backlinkURLString: nil,
        pixelTrackingURLString: nil
      ),
      artworkURLString: nil
    )
    try cacheStore.save(cachedResult, for: track.fileFingerprint)

    let session = makeMockSession { request in
      guard let url = request.url else {
        throw URLError(.badURL)
      }

      switch url.path {
      case "/api/search/suggest/web":
        return """
        {
          "result": {
            "songs": [
              {
                "id": 42,
                "name": "Star Song",
                "artists": [{ "name": "Singer" }],
                "album": { "name": "Album" },
                "duration": 180000
              }
            ]
          }
        }
        """
      case "/api/song/lyric":
        return """
        {
          "lrc": {
            "lyric": "[00:10.00]netease synced line"
          }
        }
        """
      default:
        throw URLError(.unsupportedURL)
      }
    }

    let service = LyricsService(
      cacheStore: cacheStore,
      localLRCProvider: LocalLRCProvider(),
      lrclibProvider: LRCLIBProvider(session: session),
      neteaseProvider: NeteaseProvider(session: session)
    )

    service.loadLyrics(for: track)
    await waitForReadyState(on: service)

    let result = try #require(readyResult(from: service.state))
    #expect(result.attribution.providerName == "netease")

    let cachedAfterUpgrade = try #require(cacheStore.load(for: track.fileFingerprint))
    #expect(cachedAfterUpgrade.attribution.providerName == "netease")

    try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent())
  }

  @Test
  func keepsCachedLRCLIBResultWhenNetEaseIsExplicitlyIgnored() async throws {
    let restoreAutoDownload = forceAutoDownloadLyricsEnabled()
    defer { restoreAutoDownload() }

    let cacheURL = makeCacheURL()
    let cacheStore = LyricsCacheStore(fileURL: cacheURL)
    let track = makeTrack(fingerprint: "ignored-netease")
    let cachedResult = LyricsResult(
      content: .plain("cached lrclib lyrics"),
      attribution: LyricsAttribution(
        providerName: "lrclib",
        displayName: "LRCLIB",
        copyrightText: nil,
        backlinkURLString: nil,
        pixelTrackingURLString: nil
      ),
      artworkURLString: nil
    )
    try cacheStore.save(cachedResult, for: track.fileFingerprint)

    let session = makeMockSession { _ in
      Issue.record("NetEase should not be queried when explicitly ignored.")
      throw URLError(.unsupportedURL)
    }

    let service = LyricsService(
      cacheStore: cacheStore,
      localLRCProvider: LocalLRCProvider(),
      lrclibProvider: LRCLIBProvider(session: session),
      neteaseProvider: NeteaseProvider(session: session)
    )

    service.loadLyrics(for: track, ignoring: ["netease"])
    await waitForReadyState(on: service)

    let result = try #require(readyResult(from: service.state))
    #expect(result.attribution.providerName == "lrclib")

    try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent())
  }

  private func waitForReadyState(on service: LyricsService) async {
    for _ in 0..<50 {
      if case .ready = service.state {
        try? await Task.sleep(for: .milliseconds(20))
      }

      if case .ready(let result) = service.state, result.attribution.providerName == "netease" {
        return
      }

      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  private func readyResult(from state: LyricsLookupState) -> LyricsResult? {
    guard case .ready(let result) = state else { return nil }
    return result
  }

  private func makeTrack(fingerprint: String) -> Track {
    Track(
      title: "Star Song",
      artist: "Singer",
      album: "Album",
      duration: 180,
      fileExtension: "m4a",
      fileURL: nil,
      fileFingerprint: fingerprint
    )
  }

  private func makeCacheURL() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return directory.appendingPathComponent("lyrics-cache.json")
  }

  private func makeMockSession(
    handler: @escaping @Sendable (URLRequest) throws -> String
  ) -> URLSession {
    MockLyricsURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockLyricsURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private func forceAutoDownloadLyricsEnabled() -> () -> Void {
    let defaults = UserDefaults.standard
    let key = "autoDownloadLyrics"
    let previousValue = defaults.object(forKey: key)
    defaults.set(true, forKey: key)

    return {
      if let previousValue {
        defaults.set(previousValue, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }
}

private final class MockLyricsURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> String)?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let body = try handler(request)
      let response = HTTPURLResponse(
        url: try #require(request.url),
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(body.utf8))
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
