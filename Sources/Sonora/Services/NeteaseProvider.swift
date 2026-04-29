import Foundation

struct NeteaseProvider: LyricsProvider {
  let name = "netease"

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate] {
    let simplifiedTitle = Self.toSimplifiedChinese(identity.title)
    let simplifiedArtist = Self.toSimplifiedChinese(identity.artist)
    let query = [simplifiedTitle, simplifiedArtist].joined(separator: " ")
    guard !query.isEmpty else { return [] }

    var components = URLComponents()
    components.scheme = "https"
    components.host = "music.163.com"
    components.path = "/api/search/suggest/web"
    components.queryItems = [
      URLQueryItem(name: "s", value: query),
      URLQueryItem(name: "limit", value: "10")
    ]

    guard let url = components.url else { return [] }

    var request = URLRequest(url: url)
    request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw NeteaseProviderError.requestFailed
    }

    let searchResponse: NeteaseSuggestResponse
    do {
      searchResponse = try JSONDecoder().decode(NeteaseSuggestResponse.self, from: data)
    } catch {
      return []
    }
    return searchResponse.result.songs?.compactMap { Self.makeCandidate(from: $0, identity: identity) } ?? []
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
      } else {
        return LyricsResult(content: .plain(lrcText), attribution: attribution, artworkURLString: nil)
      }
    }

    throw NeteaseProviderError.noLyrics
  }

  // MARK: - Scoring

  static func makeCandidate(from song: NeteaseSuggestResponse.Song, identity: NormalizedTrackIdentity) -> LyricsCandidate? {
    let simplifiedIdentityTitle = toSimplifiedChinese(identity.title)
    let simplifiedIdentityArtist = toSimplifiedChinese(identity.artist)
    let simplifiedSongName = toSimplifiedChinese(song.name)
    let songArtist = song.artists.first?.name ?? ""
    let simplifiedSongArtist = toSimplifiedChinese(songArtist)

    var titleConfidence = 0.0
    if simplifiedSongName.compare(simplifiedIdentityTitle, options: .caseInsensitive) == .orderedSame {
      titleConfidence = 1.0
    } else if simplifiedSongName.localizedCaseInsensitiveContains(simplifiedIdentityTitle) || simplifiedIdentityTitle.localizedCaseInsensitiveContains(simplifiedSongName) {
      titleConfidence = 0.5
    }

    var artistConfidence = 0.0
    if simplifiedSongArtist.compare(simplifiedIdentityArtist, options: .caseInsensitive) == .orderedSame {
      artistConfidence = 1.0
    } else if simplifiedSongArtist.localizedCaseInsensitiveContains(simplifiedIdentityArtist) || simplifiedIdentityArtist.localizedCaseInsensitiveContains(simplifiedSongArtist) {
      artistConfidence = 0.5
    }

    var durationConfidence = 1.0
    if let expectedDuration = identity.duration {
      let songDurationSeconds = TimeInterval(song.duration) / 1000.0
      let delta = abs(expectedDuration - songDurationSeconds)
      if delta <= 15 {
        durationConfidence = max(0, 1.0 - (delta / 15.0))
      } else {
        durationConfidence = -1.0
      }
    }

    let rawConfidence = (titleConfidence + artistConfidence + durationConfidence) / 3.0

    guard rawConfidence >= 0.5 else { return nil }

    return LyricsCandidate(
      id: String(song.id),
      providerName: "netease",
      title: song.name,
      artist: songArtist,
      album: song.album?.name,
      duration: TimeInterval(song.duration) / 1000.0,
      hasSyncedLyrics: true,
      confidence: max(0.0, min(1.0, rawConfidence)),
      artworkURLString: nil,
      backlinkURLString: nil
    )
  }

  // MARK: - Chinese Conversion

  /// Converts Traditional Chinese characters to Simplified Chinese using macOS ICU transforms.
  /// Non-Chinese text passes through unchanged.
  static func toSimplifiedChinese(_ text: String) -> String {
    let mutable = NSMutableString(string: text)
    CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
    return mutable as String
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

struct NeteaseSuggestResponse: Decodable {
  let result: Result

  struct Result: Decodable {
    let songs: [Song]?
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
