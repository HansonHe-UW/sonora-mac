import Foundation

enum TimeFormatter {
  static func playbackTime(_ interval: TimeInterval?) -> String {
    guard let interval, interval.isFinite else { return "--:--" }

    let totalSeconds = max(Int(interval.rounded()), 0)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
