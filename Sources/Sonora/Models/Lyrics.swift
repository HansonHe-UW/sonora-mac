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

enum LyricsContent: Hashable {
  case synced([LyricsLine])
  case plain(String)
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
}

enum LyricsLookupState: Hashable {
  case empty
  case ready(LyricsContent)
  case unavailable(String)
}
