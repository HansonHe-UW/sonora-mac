import Combine
import Foundation

@MainActor
final class PlayerCore: ObservableObject {
  @Published private(set) var playbackState: PlaybackState = .stopped
  @Published private(set) var currentTrack: Track?
  @Published var progress: Double = 0
  @Published var volume: Double = 0.8

  var currentTime: TimeInterval {
    (currentTrack?.duration ?? 0) * progress
  }

  func load(_ track: Track?) {
    currentTrack = track
    progress = 0
    playbackState = track == nil ? .stopped : .paused
  }

  func togglePlayPause() {
    guard currentTrack != nil else { return }
    playbackState = playbackState == .playing ? .paused : .playing
  }

  func playPrevious() {
    progress = 0
  }

  func playNext() {
    progress = 0
  }

  func seek(to progress: Double) {
    self.progress = min(max(progress, 0), 1)
  }
}
