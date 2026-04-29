import Foundation

enum LyricsTiming {
  static func adjustedCurrentTime(_ currentTime: TimeInterval, offset: TimeInterval) -> TimeInterval {
    max(0, currentTime - offset)
  }

  static func seekTime(forLyricTime lyricTime: TimeInterval, offset: TimeInterval) -> TimeInterval {
    max(0, lyricTime + offset)
  }
}
