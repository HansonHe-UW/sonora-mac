import Foundation

struct ExperimentalLyricsProxyProvider: LyricsProvider {
  let name = "experimental-proxy"

  private let baseURL: URL
  private let session: URLSession

  init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate] {
    let response: ExperimentalProxyLyricsResponse = try await performRequest(
      path: "v2/musixmatch/lyrics",
      queryItems: [
        URLQueryItem(name: "title", value: identity.title),
        URLQueryItem(name: "artist", value: identity.artist)
      ]
    )

    guard !(response.lyrics?.trimmedForMetadata.isEmpty ?? true) else {
      return []
    }

    return [
      LyricsCandidate(
        id: identity.title + "|" + identity.artist,
        providerName: name,
        title: identity.title,
        artist: identity.artist,
        album: identity.album,
        duration: identity.duration,
        hasSyncedLyrics: !(response.syncedLyrics?.trimmedForMetadata.isEmpty ?? true),
        confidence: 0.7,
        artworkURLString: response.artworkURLString,
        backlinkURLString: nil
      )
    ]
  }

  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsResult {
    let components = candidate.id.components(separatedBy: "|")
    let title = components.first ?? candidate.title
    let artist = components.dropFirst().first ?? candidate.artist

    let response: ExperimentalProxyLyricsResponse = try await performRequest(
      path: "v2/musixmatch/lyrics",
      queryItems: [
        URLQueryItem(name: "title", value: title),
        URLQueryItem(name: "artist", value: artist)
      ]
    )

    if let syncedLyrics = response.syncedLyrics?.trimmedForMetadata, !syncedLyrics.isEmpty {
      let parsed = LRCParser.parse(syncedLyrics)
      if !parsed.isEmpty {
        return LyricsResult(
          content: .synced(parsed),
          attribution: LyricsAttribution(
            providerName: name,
            displayName: "Experimental Proxy",
            copyrightText: nil,
            backlinkURLString: nil,
            pixelTrackingURLString: nil
          ),
          artworkURLString: response.artworkURLString
        )
      }
    }

    guard let lyrics = response.lyrics?.trimmedForMetadata, !lyrics.isEmpty else {
      throw ExperimentalLyricsProxyError.noLyricsFound
    }

    return LyricsResult(
      content: .plain(lyrics),
      attribution: LyricsAttribution(
        providerName: name,
        displayName: "Experimental Proxy",
        copyrightText: nil,
        backlinkURLString: nil,
        pixelTrackingURLString: nil
      ),
      artworkURLString: response.artworkURLString
    )
  }

  private func performRequest<Response: Decodable>(
    path: String,
    queryItems: [URLQueryItem]
  ) async throws -> Response {
    guard let url = URL(string: path, relativeTo: baseURL) else {
      throw ExperimentalLyricsProxyError.invalidBaseURL
    }

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      throw ExperimentalLyricsProxyError.invalidBaseURL
    }

    components.queryItems = queryItems

    guard let requestURL = components.url else {
      throw ExperimentalLyricsProxyError.invalidBaseURL
    }

    var request = URLRequest(url: requestURL)
    request.setValue("Sonora/0.1 (+https://github.com/HansonHe-UW/sonora-mac)", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ExperimentalLyricsProxyError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw ExperimentalLyricsProxyError.requestFailed(httpResponse.statusCode)
    }

    return try JSONDecoder().decode(Response.self, from: data)
  }
}

enum ExperimentalLyricsProxyError: LocalizedError {
  case invalidBaseURL
  case invalidResponse
  case requestFailed(Int)
  case noLyricsFound

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      return "Experimental lyrics proxy URL is invalid."
    case .invalidResponse:
      return "Experimental lyrics proxy returned an invalid response."
    case .requestFailed(let statusCode):
      return "Experimental lyrics proxy failed with status \(statusCode)."
    case .noLyricsFound:
      return "Experimental lyrics proxy returned no lyrics."
    }
  }
}

private struct ExperimentalProxyLyricsResponse: Decodable {
  let lyrics: String?
  let syncedLyrics: String?
  let artworkURLString: String?

  private enum RootCodingKeys: String, CodingKey {
    case data
    case lyrics
    case syncedLyrics = "syncedLyrics"
    case artworkURLString = "artworkUrl"
  }

  private enum DataCodingKeys: String, CodingKey {
    case lyrics
    case syncedLyrics = "syncedLyrics"
    case artworkURLString = "artworkUrl"
  }

  init(from decoder: Decoder) throws {
    let root = try decoder.container(keyedBy: RootCodingKeys.self)

    if root.contains(.data) {
      let nested = try root.nestedContainer(keyedBy: DataCodingKeys.self, forKey: .data)
      lyrics = try nested.decodeIfPresent(String.self, forKey: .lyrics)
      syncedLyrics = try nested.decodeIfPresent(String.self, forKey: .syncedLyrics)
      artworkURLString = try nested.decodeIfPresent(String.self, forKey: .artworkURLString)
      return
    }

    lyrics = try root.decodeIfPresent(String.self, forKey: .lyrics)
    syncedLyrics = try root.decodeIfPresent(String.self, forKey: .syncedLyrics)
    artworkURLString = try root.decodeIfPresent(String.self, forKey: .artworkURLString)
  }
}
