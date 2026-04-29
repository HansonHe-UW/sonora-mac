import Foundation

struct MusixmatchProvider: LyricsProvider {
  let name = "musixmatch"

  private let apiKey: String
  private let session: URLSession

  init(apiKey: String, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate] {
    var parameters = [
      URLQueryItem(name: "apikey", value: apiKey),
      URLQueryItem(name: "q_track", value: identity.title),
      URLQueryItem(name: "q_artist", value: identity.artist)
    ]

    if let isrc = identity.isrc, !isrc.isEmpty {
      parameters.append(URLQueryItem(name: "track_isrc", value: isrc))
    }

    let response: MusixmatchMatcherTrackResponse = try await performRequest(
      path: "matcher.track.get",
      queryItems: parameters
    )

    guard response.message.header.statusCode == 200 else {
      throw MusixmatchProviderError.requestFailed(response.message.header.statusCode)
    }

    guard let track = response.message.body.track, track.restricted == 0 else {
      return []
    }

    let artworkURLString = track.albumCoverArt500
      ?? track.albumCoverArt350
      ?? track.albumCoverArt100

    let confidence = min(Double(response.message.header.confidence ?? 0) / 1000, 1.0)
    let candidate = LyricsCandidate(
      id: String(track.trackID),
      providerName: name,
      title: track.trackName,
      artist: track.artistName,
      album: track.albumName,
      duration: TimeInterval(track.trackLength),
      hasSyncedLyrics: track.hasSubtitles == 1,
      confidence: confidence,
      artworkURLString: artworkURLString,
      backlinkURLString: track.trackShareURL
    )

    return [candidate]
  }

  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsResult {
    let trackID = candidate.id

    if candidate.hasSyncedLyrics,
       let subtitleResponse: MusixmatchSubtitleResponse = try? await performRequest(
        path: "track.subtitle.get",
        queryItems: [
          URLQueryItem(name: "apikey", value: apiKey),
          URLQueryItem(name: "track_id", value: trackID),
          URLQueryItem(name: "subtitle_format", value: "lrc")
        ]
       ),
       subtitleResponse.message.header.statusCode == 200,
       let subtitle = subtitleResponse.message.body.subtitle?.subtitleBody,
       !subtitle.trimmedForMetadata.isEmpty {
      let parsedLines = LRCParser.parse(subtitle)
      if !parsedLines.isEmpty {
        return LyricsResult(
          content: .synced(parsedLines),
          attribution: LyricsAttribution(
            providerName: name,
            displayName: "Musixmatch",
            copyrightText: nil,
            backlinkURLString: candidate.backlinkURLString,
            pixelTrackingURLString: subtitleResponse.message.body.subtitle?.pixelTrackingURL
          ),
          artworkURLString: candidate.artworkURLString
        )
      }
    }

    let lyricsResponse: MusixmatchLyricsResponse = try await performRequest(
      path: "track.lyrics.get",
      queryItems: [
        URLQueryItem(name: "apikey", value: apiKey),
        URLQueryItem(name: "track_id", value: trackID)
      ]
    )

    guard lyricsResponse.message.header.statusCode == 200 else {
      throw MusixmatchProviderError.requestFailed(lyricsResponse.message.header.statusCode)
    }

    guard let lyrics = lyricsResponse.message.body.lyrics else {
      throw MusixmatchProviderError.noLyricsFound
    }

    let cleanedBody = cleanLyricsBody(lyrics.lyricsBody)
    guard !cleanedBody.isEmpty else {
      throw MusixmatchProviderError.noLyricsFound
    }

    return LyricsResult(
      content: .plain(cleanedBody),
      attribution: LyricsAttribution(
        providerName: name,
        displayName: "Musixmatch",
        copyrightText: lyrics.lyricsCopyright,
        backlinkURLString: lyrics.backlinkURL ?? candidate.backlinkURLString,
        pixelTrackingURLString: lyrics.pixelTrackingURL
      ),
      artworkURLString: candidate.artworkURLString
    )
  }

  private func performRequest<Response: Decodable>(
    path: String,
    queryItems: [URLQueryItem]
  ) async throws -> Response {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.musixmatch.com"
    components.path = "/ws/1.1/\(path)"
    components.queryItems = queryItems

    guard let url = components.url else {
      throw MusixmatchProviderError.invalidRequest
    }

    let (data, response) = try await session.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw MusixmatchProviderError.invalidResponse
    }

    return try JSONDecoder().decode(Response.self, from: data)
  }

  private func cleanLyricsBody(_ lyricsBody: String) -> String {
    lyricsBody
      .replacingOccurrences(of: #"\*{7} This Lyrics is NOT for Commercial use \*{7}.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
      .trimmedForMetadata
  }
}

enum MusixmatchProviderError: LocalizedError {
  case invalidRequest
  case invalidResponse
  case requestFailed(Int)
  case noLyricsFound

  var errorDescription: String? {
    switch self {
    case .invalidRequest:
      return "Could not build the Musixmatch request."
    case .invalidResponse:
      return "Musixmatch returned an invalid response."
    case .requestFailed(let statusCode):
      return "Musixmatch request failed with status \(statusCode)."
    case .noLyricsFound:
      return "No lyrics were returned for this track."
    }
  }
}

private struct MusixmatchMatcherTrackResponse: Decodable {
  struct Message: Decodable {
    struct Header: Decodable {
      let statusCode: Int
      let confidence: Int?

      private enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case confidence
      }
    }

    struct Body: Decodable {
      struct Track: Decodable {
        let trackID: Int
        let trackName: String
        let artistName: String
        let albumName: String?
        let trackLength: Int
        let hasSubtitles: Int
        let restricted: Int
        let trackShareURL: String?
        let albumCoverArt100: String?
        let albumCoverArt350: String?
        let albumCoverArt500: String?

        private enum CodingKeys: String, CodingKey {
          case trackID = "track_id"
          case trackName = "track_name"
          case artistName = "artist_name"
          case albumName = "album_name"
          case trackLength = "track_length"
          case hasSubtitles = "has_subtitles"
          case restricted
          case trackShareURL = "track_share_url"
          case albumCoverArt100 = "album_coverart_100x100"
          case albumCoverArt350 = "album_coverart_350x350"
          case albumCoverArt500 = "album_coverart_500x500"
        }
      }

      let track: Track?
    }

    let header: Header
    let body: Body
  }

  let message: Message
}

private struct MusixmatchSubtitleResponse: Decodable {
  struct Message: Decodable {
    struct Header: Decodable {
      let statusCode: Int

      private enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
      }
    }

    struct Body: Decodable {
      struct Subtitle: Decodable {
        let subtitleBody: String?
        let pixelTrackingURL: String?

        private enum CodingKeys: String, CodingKey {
          case subtitleBody = "subtitle_body"
          case pixelTrackingURL = "pixel_tracking_url"
        }
      }

      let subtitle: Subtitle?
    }

    let header: Header
    let body: Body
  }

  let message: Message
}

private struct MusixmatchLyricsResponse: Decodable {
  struct Message: Decodable {
    struct Header: Decodable {
      let statusCode: Int

      private enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
      }
    }

    struct Body: Decodable {
      struct Lyrics: Decodable {
        let lyricsBody: String
        let lyricsCopyright: String?
        let backlinkURL: String?
        let pixelTrackingURL: String?

        private enum CodingKeys: String, CodingKey {
          case lyricsBody = "lyrics_body"
          case lyricsCopyright = "lyrics_copyright"
          case backlinkURL = "backlink_url"
          case pixelTrackingURL = "pixel_tracking_url"
        }
      }

      let lyrics: Lyrics?
    }

    let header: Header
    let body: Body
  }

  let message: Message
}
