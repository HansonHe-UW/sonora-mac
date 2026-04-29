import Foundation

struct LyricsLine: Identifiable, Hashable {
  let id: UUID
  var time: TimeInterval
  var text: String

  init(id: UUID = UUID(), time: TimeInterval, text: String) {
    self.id = id
    self.time = time
    self.text = text
  }
}

extension LyricsLine: Codable {}

enum LyricsContent: Hashable, Codable {
  case synced([LyricsLine])
  case plain(String)

  private enum CodingKeys: String, CodingKey {
    case kind
    case lines
    case text
  }

  private enum Kind: String, Codable {
    case synced
    case plain
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .synced:
      self = .synced(try container.decode([LyricsLine].self, forKey: .lines))
    case .plain:
      self = .plain(try container.decode(String.self, forKey: .text))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .synced(let lines):
      try container.encode(Kind.synced, forKey: .kind)
      try container.encode(lines, forKey: .lines)
    case .plain(let text):
      try container.encode(Kind.plain, forKey: .kind)
      try container.encode(text, forKey: .text)
    }
  }
}

struct LyricsCandidate: Identifiable, Hashable {
  let id: String
  var providerName: String
  var title: String
  var artist: String
  var album: String?
  var duration: TimeInterval?
  var hasSyncedLyrics: Bool
  var confidence: Double
  var artworkURLString: String?
  var backlinkURLString: String?
}

struct LyricsAttribution: Hashable, Codable {
  var providerName: String
  var displayName: String
  var copyrightText: String?
  var backlinkURLString: String?
  var pixelTrackingURLString: String?
}

struct LyricsResult: Hashable, Codable {
  var content: LyricsContent
  var attribution: LyricsAttribution
  var artworkURLString: String?
}

struct ArtworkSuggestion: Identifiable, Hashable {
  let id: UUID
  var trackID: Track.ID
  var artworkData: Data

  init(id: UUID = UUID(), trackID: Track.ID, artworkData: Data) {
    self.id = id
    self.trackID = trackID
    self.artworkData = artworkData
  }
}

enum LyricsUnavailableReason: Hashable {
  case noMatch
  case networkFailure
  case downloadDisabled
  case providerError(String)

  var displayMessage: String {
    switch self {
    case .noMatch:
      return "No lyrics found for this track."
    case .networkFailure:
      return "Could not reach lyrics provider. Check your connection."
    case .downloadDisabled:
      return "Automatic lyrics download is disabled in Settings."
    case .providerError(let detail):
      return "Lyrics provider error: \(detail)"
    }
  }
}

enum LyricsLookupState: Hashable {
  case empty
  case loading(String)
  case ready(LyricsResult)
  case unavailable(LyricsUnavailableReason)
}
