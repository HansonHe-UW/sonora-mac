import AppKit
import AVFoundation
import Combine
import Foundation
import MediaPlayer

@MainActor
final class PlayerCore: ObservableObject {
  @Published private(set) var playbackState: PlaybackState = .stopped
  @Published private(set) var currentTrack: Track?
  @Published private(set) var currentTime: TimeInterval = 0
  @Published private(set) var isShuffleEnabled = false
  @Published private(set) var repeatMode: PlaybackRepeatMode = .off
  @Published var progress: Double = 0
  @Published var volume: Double = 0.8 {
    didSet {
      player.volume = Float(volume)
    }
  }

  private let player = AVPlayer()
  private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
  private let remoteCommandCenter = MPRemoteCommandCenter.shared()
  private var queue: [Track] = []
  private var playOrder: [Int] = []
  private var currentIndex: Int?
  private var orderPosition: Int?
  private var timeObserver: Any?
  private var itemEndObserver: NSObjectProtocol?
  private var accessedPlaybackURL: URL?

  init() {
    player.volume = Float(volume)
    installTimeObserver()
    configureRemoteCommands()
    updateNowPlayingInfo()
  }

  var canPlayPrevious: Bool {
    currentIndex != nil
  }

  var canPlayNext: Bool {
    nextPlayableIndex() != nil
  }

  func updateQueue(_ tracks: [Track]) {
    let previousCurrentIndex = currentIndex
    let shouldResumePlayback = playbackState == .playing
    let currentTrackID = currentTrack?.id
    queue = tracks

    if let currentTrackID, let index = queue.firstIndex(where: { $0.id == currentTrackID }) {
      currentIndex = index
      rebuildPlayOrder(anchoredAt: index)
      currentTrack = queue[index]
      updateNowPlayingInfo()
      return
    }

    if queue.isEmpty {
      rebuildPlayOrder(anchoredAt: nil)
      unloadCurrentTrack()
    } else {
      let fallbackIndex = min(previousCurrentIndex ?? 0, queue.count - 1)
      rebuildPlayOrder(anchoredAt: fallbackIndex)
      prepareTrack(queue[fallbackIndex], autoPlay: shouldResumePlayback)
    }
  }

  func load(_ track: Track?) {
    guard let track else {
      unloadCurrentTrack()
      return
    }

    guard let index = queue.firstIndex(where: { $0.id == track.id }) else {
      let shouldAutoPlay = playbackState == .playing
      prepareTrack(track, autoPlay: shouldAutoPlay)
      return
    }

    let shouldAutoPlay = playbackState == .playing
    rebuildPlayOrder(anchoredAt: index)
    prepareTrack(queue[index], autoPlay: shouldAutoPlay)
  }

  func toggleShuffle() {
    isShuffleEnabled.toggle()
    rebuildPlayOrder(anchoredAt: currentIndex)
    updateNowPlayingInfo()
  }

  func cycleRepeatMode() {
    repeatMode.cycle()
    updateNowPlayingInfo()
  }

  func togglePlayPause() {
    guard currentTrack != nil else { return }

    if playbackState == .playing {
      player.pause()
      playbackState = .paused
      updateNowPlayingInfo()
      return
    }

    if player.currentItem == nil {
      prepareTrack(currentTrack, autoPlay: true)
    } else {
      player.play()
      playbackState = .playing
      updateNowPlayingInfo()
    }
  }

  func playPrevious() {
    guard currentIndex != nil else { return }

    if currentTime > 3 {
      seek(to: 0)
      return
    }

    guard let previousIndex = previousPlayableIndex() else {
      seek(to: 0)
      return
    }

    prepareTrack(queue[previousIndex], autoPlay: playbackState == .playing)
  }

  func playNext() {
    guard currentIndex != nil else { return }
    guard let nextIndex = nextPlayableIndex() else {
      seek(to: 0)
      return
    }

    prepareTrack(queue[nextIndex], autoPlay: playbackState == .playing)
  }

  func seek(to progress: Double) {
    let normalizedProgress = min(max(progress, 0), 1)
    self.progress = normalizedProgress

    guard let duration = currentTrack?.duration else {
      currentTime = 0
      return
    }

    let targetTime = duration * normalizedProgress
    currentTime = targetTime

    guard player.currentItem != nil else { return }
    let cmTime = CMTime(seconds: targetTime, preferredTimescale: 600)
    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    updateNowPlayingInfo()
  }

  private func prepareTrack(_ track: Track?, autoPlay: Bool) {
    guard let track else {
      unloadCurrentTrack()
      return
    }

    currentTrack = track
    currentIndex = queue.firstIndex(where: { $0.id == track.id })
    syncOrderPosition()
    currentTime = 0
    progress = 0

    guard track.accessState == .available else {
      player.pause()
      player.replaceCurrentItem(with: nil)
      playbackState = .paused
      clearItemEndObserver()
      updateNowPlayingInfo()
      return
    }

    if let playbackURL = resolvePlaybackURL(for: track) {
      let item = AVPlayerItem(url: playbackURL)
      player.replaceCurrentItem(with: item)
      installItemEndObserver(for: item)
    } else {
      player.replaceCurrentItem(with: nil)
      clearItemEndObserver()
    }

    if autoPlay, player.currentItem != nil {
      player.play()
      playbackState = .playing
    } else {
      player.pause()
      playbackState = .paused
    }

    updateNowPlayingInfo()
  }

  private func unloadCurrentTrack() {
    player.pause()
    player.replaceCurrentItem(with: nil)
    currentTrack = nil
    currentIndex = nil
    orderPosition = nil
    currentTime = 0
    progress = 0
    playbackState = .stopped
    clearItemEndObserver()
    stopAccessingPlaybackURL()
    clearNowPlayingInfo()
  }

  private func installTimeObserver() {
    // A 250 ms observer is visibly late for dense vocals. Keep the interval tighter,
    // but avoid doing extra work in the callback so the main thread stays responsive.
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] currentTime in
      MainActor.assumeIsolated {
        guard let self else { return }
        let seconds = CMTimeGetSeconds(currentTime)
        self.currentTime = seconds.isFinite ? max(seconds, 0) : 0

        guard let duration = self.currentTrack?.duration, duration > 0 else {
          self.progress = 0
          return
        }

        self.progress = min(max(self.currentTime / duration, 0), 1)
      }
    }
  }

  private func installItemEndObserver(for item: AVPlayerItem) {
    clearItemEndObserver()
    itemEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.advanceAfterCurrentTrack()
      }
    }
  }

  private func clearItemEndObserver() {
    if let itemEndObserver {
      NotificationCenter.default.removeObserver(itemEndObserver)
      self.itemEndObserver = nil
    }
  }

  func advanceAfterCurrentTrack() {
    guard currentIndex != nil else {
      unloadCurrentTrack()
      return
    }

    if repeatMode == .one {
      player.seek(to: .zero)
      currentTime = 0
      progress = 0
      if playbackState == .playing {
        player.play()
      }
      updateNowPlayingInfo()
      return
    }

    guard let nextIndex = nextPlayableIndex() else {
      player.seek(to: .zero)
      player.pause()
      playbackState = .paused
      currentTime = 0
      progress = 0
      updateNowPlayingInfo()
      return
    }

    prepareTrack(queue[nextIndex], autoPlay: true)
  }

  private func resolvePlaybackURL(for track: Track) -> URL? {
    stopAccessingPlaybackURL()

    if let bookmarkData = track.bookmarkData {
      var isStale = false
      if let url = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ) {
        let startedAccessing = url.startAccessingSecurityScopedResource()
        if startedAccessing {
          accessedPlaybackURL = url
        }
        return url
      }
    }

    return track.fileURL
  }

  private func stopAccessingPlaybackURL() {
    if let accessedPlaybackURL {
      accessedPlaybackURL.stopAccessingSecurityScopedResource()
      self.accessedPlaybackURL = nil
    }
  }

  private func rebuildPlayOrder(anchoredAt anchorIndex: Int?) {
    let indices = Array(queue.indices)

    guard !indices.isEmpty else {
      playOrder = []
      orderPosition = nil
      return
    }

    if isShuffleEnabled {
      if let anchorIndex {
        var remaining = indices.filter { $0 != anchorIndex }
        remaining.shuffle()
        playOrder = [anchorIndex] + remaining
        orderPosition = 0
      } else {
        playOrder = indices.shuffled()
        orderPosition = nil
      }
    } else {
      playOrder = indices
      orderPosition = anchorIndex.flatMap { playOrder.firstIndex(of: $0) }
    }
  }

  private func syncOrderPosition() {
    guard let currentIndex else {
      orderPosition = nil
      return
    }

    if isShuffleEnabled {
      if playOrder.count != queue.count || !playOrder.contains(currentIndex) {
        rebuildPlayOrder(anchoredAt: currentIndex)
        return
      }
    } else if playOrder != Array(queue.indices) {
      rebuildPlayOrder(anchoredAt: currentIndex)
      return
    }

    orderPosition = playOrder.firstIndex(of: currentIndex)
  }

  private func previousPlayableIndex() -> Int? {
    guard let orderPosition, orderPosition > 0 else { return nil }
    return playOrder[orderPosition - 1]
  }

  private func nextPlayableIndex() -> Int? {
    guard let orderPosition else { return nil }
    let nextPosition = orderPosition + 1
    guard playOrder.indices.contains(nextPosition) else { return nil }
    return playOrder[nextPosition]
  }

  private func configureRemoteCommands() {
    remoteCommandCenter.playCommand.isEnabled = true
    remoteCommandCenter.pauseCommand.isEnabled = true
    remoteCommandCenter.togglePlayPauseCommand.isEnabled = true
    remoteCommandCenter.nextTrackCommand.isEnabled = true
    remoteCommandCenter.previousTrackCommand.isEnabled = true
    remoteCommandCenter.changePlaybackPositionCommand.isEnabled = true
    remoteCommandCenter.stopCommand.isEnabled = true

    remoteCommandCenter.playCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.playbackState != .playing {
          self.togglePlayPause()
        }
      }
      return .success
    }

    remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.playbackState == .playing {
          self.togglePlayPause()
        }
      }
      return .success
    }

    remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.togglePlayPause()
      }
      return .success
    }

    remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.playNext()
      }
      return .success
    }

    remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.playPrevious()
      }
      return .success
    }

    remoteCommandCenter.stopCommand.addTarget { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.playbackState == .playing {
          self.togglePlayPause()
        }
        self.seek(to: 0)
      }
      return .success
    }

    remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }

      Task { @MainActor [weak self] in
        guard let self, let duration = self.currentTrack?.duration, duration > 0 else { return }
        self.seek(to: event.positionTime / duration)
      }

      return .success
    }
  }

  private func updateNowPlayingInfo() {
    guard let currentTrack else {
      clearNowPlayingInfo()
      return
    }

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: currentTrack.title,
      MPMediaItemPropertyArtist: currentTrack.artist,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
      MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
      MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count,
      MPNowPlayingInfoPropertyPlaybackQueueIndex: currentIndex ?? 0
    ]

    if let album = currentTrack.album, !album.isEmpty {
      info[MPMediaItemPropertyAlbumTitle] = album
    }

    if let duration = currentTrack.duration, duration > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = duration
      info[MPNowPlayingInfoPropertyPlaybackProgress] = min(max(currentTime / duration, 0), 1)
    }

    if let artwork = Self.mediaArtwork(from: currentTrack.artworkData) {
      info[MPMediaItemPropertyArtwork] = artwork
    }

    nowPlayingInfoCenter.nowPlayingInfo = info
    nowPlayingInfoCenter.playbackState = nowPlayingPlaybackState
  }

  private func clearNowPlayingInfo() {
    nowPlayingInfoCenter.nowPlayingInfo = nil
    nowPlayingInfoCenter.playbackState = .stopped
  }

  private var nowPlayingPlaybackState: MPNowPlayingPlaybackState {
    switch playbackState {
    case .stopped:
      return .stopped
    case .paused:
      return .paused
    case .playing:
      return .playing
    }
  }

  nonisolated private static func mediaArtwork(from data: Data?) -> MPMediaItemArtwork? {
    guard let data, let image = NSImage(data: data) else { return nil }
    return MPMediaItemArtwork(boundsSize: image.size) { _ in
      image
    }
  }
}
