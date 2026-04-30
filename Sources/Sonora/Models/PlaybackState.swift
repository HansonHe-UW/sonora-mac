import Foundation

enum PlaybackState: String {
  case stopped
  case paused
  case playing
}

enum PlaybackRepeatMode: String {
  case off
  case one

  mutating func cycle() {
    switch self {
    case .off:
      self = .one
    case .one:
      self = .off
    }
  }
}
