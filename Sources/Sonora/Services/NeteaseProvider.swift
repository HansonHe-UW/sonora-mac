import Foundation

struct NeteaseProvider: LyricsProvider {
  let name = "netease"

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate] {
    let query = [identity.title, identity.artist].compactMap { $0 }.joined(separator: " ")
    guard !query.isEmpty else { return [] }

    var components = URLComponents()
    components.scheme = "https"
    components.host = "music.163.com"
    components.path = "/api/search/get/web"
    components.queryItems = [
      URLQueryItem(name: "s", value: query),
      URLQueryItem(name: "type", value: "1"),
      URLQueryItem(name: "limit", value: "10")
    ]

    guard let url = components.url else { return [] }

    var request = URLRequest(url: url)
    request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw NeteaseProviderError.requestFailed
    }

    let searchResponse = try JSONDecoder().decode(NeteaseSearchResponse.self, from: data)
    return searchResponse.result.songs.map { Self.makeCandidate(from: $0) }
  }

  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsResult {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "music.163.com"
    components.path = "/api/song/lyric"
    components.queryItems = [
      URLQueryItem(name: "id", value: candidate.id),
      URLQueryItem(name: "lv", value: "1"),
      URLQueryItem(name: "kv", value: "1"),
      URLQueryItem(name: "tv", value: "-1")
    ]

    guard let url = components.url else {
      throw NeteaseProviderError.requestFailed
    }

    var request = URLRequest(url: url)
    request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw NeteaseProviderError.requestFailed
    }

    let lyricsResponse = try JSONDecoder().decode(NeteaseLyricsResponse.self, from: data)

    let attribution = LyricsAttribution(
      providerName: name,
      displayName: "网易云音乐",
      copyrightText: nil,
      backlinkURLString: "https://music.163.com",
      pixelTrackingURLString: nil
    )

    if let lrcText = lyricsResponse.lrc?.lyric.trimmingCharacters(in: .whitespacesAndNewlines),
       !lrcText.isEmpty {
      let lines = LRCParser.parse(lrcText)
      if !lines.isEmpty {
        return LyricsResult(content: .synced(lines), attribution: attribution, artworkURLString: nil)
      }
    }

    throw NeteaseProviderError.noLyrics
  }

  static func makeCandidate(from song: NeteaseSearchResponse.Song) -> LyricsCandidate {
    LyricsCandidate(
      id: String(song.id),
      providerName: "netease",
      title: song.name,
      artist: song.artists.first?.name ?? "",
      album: song.album?.name,
      duration: TimeInterval(song.duration) / 1000.0,
      hasSyncedLyrics: true,
      confidence: 1.0,
      artworkURLString: nil,
      backlinkURLString: nil
    )
  }
}

enum NeteaseProviderError: LocalizedError {
  case requestFailed
  case noLyrics

  var errorDescription: String? {
    switch self {
    case .requestFailed: return "NetEase request failed."
    case .noLyrics: return "No lyrics found on NetEase."
    }
  }
}

struct NeteaseSearchResponse: Decodable {
  let result: Result

  struct Result: Decodable {
    let songs: [Song]
  }

  struct Song: Decodable {
    let id: Int
    let name: String
    let artists: [Artist]
    let album: Album?
    let duration: Int
  }

  struct Artist: Decodable {
    let name: String
  }

  struct Album: Decodable {
    let name: String
  }
}

struct NeteaseLyricsResponse: Decodable {
  let lrc: LRC?

  struct LRC: Decodable {
    let lyric: String
  }
}
