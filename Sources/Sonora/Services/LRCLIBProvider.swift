import Foundation

struct LRCLIBProvider: LyricsProvider {
  let name = "lrclib"

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate] {
    guard let match = try await fetchBestMatch(for: identity) else {
      return []
    }

    return [
      LyricsCandidate(
        id: String(match.id),
        providerName: name,
        title: match.trackName,
        artist: match.artistName,
        album: match.albumName,
        duration: TimeInterval(match.duration),
        hasSyncedLyrics: !(match.syncedLyrics?.trimmedForMetadata.isEmpty ?? true),
        confidence: 1.0,
        artworkURLString: nil,
        backlinkURLString: nil
      )
    ]
  }

  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsResult {
    guard let id = Int(candidate.id) else {
      throw LRCLIBProviderError.invalidIdentifier
    }

    let response: LRCLIBLyricsResponse = try await performRequest(path: "get/\(id)", queryItems: [])
    return makeLyricsResult(from: response)
  }

  func fetchBestMatch(for identity: NormalizedTrackIdentity) async throws -> LRCLIBLyricsResponse? {
    for variant in TrackMetadataNormalizer.searchVariants(for: identity) {
      let queryItems: [URLQueryItem] = [
        URLQueryItem(name: "track_name", value: variant.title),
        URLQueryItem(name: "artist_name", value: variant.artist),
        URLQueryItem(name: "album_name", value: variant.album),
        URLQueryItem(name: "duration", value: variant.duration.map { String(Int($0.rounded())) })
      ].compactMap { item -> URLQueryItem? in
        item.value == nil || item.value?.isEmpty == true ? nil : item
      }

      do {
        let response: LRCLIBLyricsResponse = try await performRequest(path: "get", queryItems: queryItems)
        return response
      } catch LRCLIBProviderError.notFound {
        continue
      }
    }

    for variant in TrackMetadataNormalizer.searchVariants(for: identity) {
      if let fallback = try await searchFallback(for: variant) {
        return fallback
      }
    }

    return nil
  }

  private func searchFallback(for identity: NormalizedTrackIdentity) async throws -> LRCLIBLyricsResponse? {
    let searchRequests: [[URLQueryItem]] = [
      [
        URLQueryItem(name: "track_name", value: identity.title),
        URLQueryItem(name: "artist_name", value: identity.artist),
        URLQueryItem(name: "album_name", value: identity.album)
      ],
      [
        URLQueryItem(name: "track_name", value: identity.title),
        URLQueryItem(name: "artist_name", value: identity.artist)
      ],
      [
        URLQueryItem(name: "q", value: "\(identity.title) \(identity.artist)")
      ],
      [
        URLQueryItem(name: "track_name", value: identity.title)
      ]
    ].map { items in
      items.compactMap { item -> URLQueryItem? in
        item.value == nil || item.value?.isEmpty == true ? nil : item
      }
    }

    for queryItems in searchRequests {
      let response: [LRCLIBLyricsResponse] = try await performRequest(
        path: "search",
        queryItems: queryItems
      )

      if let best = response.max(by: { score($0, identity: identity) < score($1, identity: identity) }),
         score(best, identity: identity) >= 1.0 {
        return best
      }
    }

    return nil
  }

  private func score(_ response: LRCLIBLyricsResponse, identity: NormalizedTrackIdentity) -> Double {
    var score = 0.0

    if response.trackName.compare(identity.title, options: .caseInsensitive) == .orderedSame {
      score += 1.0
    }

    if response.artistName.compare(identity.artist, options: .caseInsensitive) == .orderedSame {
      score += 1.0
    }

    if let expectedDuration = identity.duration {
      let delta = abs(expectedDuration - TimeInterval(response.duration))
      score += max(0, 1 - min(delta / 12, 1))
    }

    if !(response.syncedLyrics?.trimmedForMetadata.isEmpty ?? true) {
      score += 0.5
    }

    if let albumName = response.albumName,
       let expectedAlbum = identity.album,
       albumName.compare(expectedAlbum, options: .caseInsensitive) == .orderedSame {
      score += 0.5
    }

    return score
  }

  private func makeLyricsResult(from response: LRCLIBLyricsResponse) -> LyricsResult {
    if let syncedLyrics = response.syncedLyrics?.trimmedForMetadata, !syncedLyrics.isEmpty {
      let parsed = LRCParser.parse(syncedLyrics)
      if !parsed.isEmpty {
        return LyricsResult(
          content: .synced(parsed),
          attribution: LyricsAttribution(
            providerName: name,
            displayName: "LRCLIB",
            copyrightText: nil,
            backlinkURLString: "https://lrclib.net",
            pixelTrackingURLString: nil
          ),
          artworkURLString: nil
        )
      }
    }

    return LyricsResult(
      content: .plain(response.plainLyrics?.trimmedForMetadata ?? ""),
      attribution: LyricsAttribution(
        providerName: name,
        displayName: "LRCLIB",
        copyrightText: nil,
        backlinkURLString: "https://lrclib.net",
        pixelTrackingURLString: nil
      ),
      artworkURLString: nil
    )
  }

  private func performRequest<Response: Decodable>(
    path: String,
    queryItems: [URLQueryItem]
  ) async throws -> Response {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "lrclib.net"
    components.path = "/api/\(path)"
    components.queryItems = queryItems.isEmpty ? nil : queryItems

    guard let url = components.url else {
      throw LRCLIBProviderError.invalidRequest
    }

    var request = URLRequest(url: url)
    request.setValue("Sonora/0.1 (+https://github.com/HansonHe-UW/sonora-mac)", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw LRCLIBProviderError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200:
      break
    case 404:
      throw LRCLIBProviderError.notFound
    default:
      throw LRCLIBProviderError.requestFailed(httpResponse.statusCode)
    }

    return try JSONDecoder().decode(Response.self, from: data)
  }
}

enum LRCLIBProviderError: LocalizedError {
  case invalidRequest
  case invalidResponse
  case requestFailed(Int)
  case notFound
  case invalidIdentifier

  var errorDescription: String? {
    switch self {
    case .invalidRequest:
      return "Could not build the LRCLIB request."
    case .invalidResponse:
      return "LRCLIB returned an invalid response."
    case .requestFailed(let statusCode):
      return "LRCLIB request failed with status \(statusCode)."
    case .notFound:
      return "LRCLIB did not find lyrics for this track."
    case .invalidIdentifier:
      return "Invalid LRCLIB track identifier."
    }
  }
}

struct LRCLIBLyricsResponse: Decodable {
  let id: Int
  let trackName: String
  let artistName: String
  let albumName: String?
  let duration: Double
  let plainLyrics: String?
  let syncedLyrics: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case trackName
    case artistName
    case albumName
    case duration
    case plainLyrics
    case syncedLyrics
  }
}
