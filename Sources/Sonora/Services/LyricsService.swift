import Combine
import Foundation

protocol LyricsProvider {
  var name: String { get }

  func search(_ identity: NormalizedTrackIdentity) async throws -> [LyricsCandidate]
  func fetchLyrics(for candidate: LyricsCandidate) async throws -> LyricsContent
}

@MainActor
final class LyricsService: ObservableObject {
  @Published private(set) var state: LyricsLookupState = .empty

  func loadPlaceholder(for track: Track?) {
    guard let track else {
      state = .empty
      return
    }

    state = .ready(.synced([
      LyricsLine(time: 0, text: "Ready to match lyrics for \(track.title)."),
      LyricsLine(time: 16, text: "Local LRC, cache, and online providers will plug in here."),
      LyricsLine(time: 32, text: "Synced lyric scrolling is reserved for the next milestone.")
    ]))
  }
}
