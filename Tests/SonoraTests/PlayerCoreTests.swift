import Foundation
import Testing
@testable import Sonora

@MainActor
struct PlayerCoreTests {
  @Test
  func updatesCurrentTrackWhenNavigatingQueue() {
    let tracks = [
      Track(title: "First", artist: "Artist", duration: 120, fileExtension: "mp3", fileFingerprint: "1"),
      Track(title: "Second", artist: "Artist", duration: 140, fileExtension: "m4a", fileFingerprint: "2"),
      Track(title: "Third", artist: "Artist", duration: 160, fileExtension: "flac", fileFingerprint: "3")
    ]

    let playerCore = PlayerCore()
    playerCore.updateQueue(tracks)
    playerCore.load(tracks[0])

    playerCore.playNext()
    #expect(playerCore.currentTrack?.id == tracks[1].id)

    playerCore.playPrevious()
    #expect(playerCore.currentTrack?.id == tracks[0].id)
  }

  @Test
  func seekUpdatesPlaybackProgressWithoutLoadedPlayerItem() {
    let track = Track(title: "First", artist: "Artist", duration: 200, fileExtension: "mp3", fileFingerprint: "1")
    let playerCore = PlayerCore()

    playerCore.updateQueue([track])
    playerCore.load(track)
    playerCore.seek(to: 0.25)

    #expect(playerCore.currentTime == 50)
    #expect(playerCore.progress == 0.25)
  }

  @Test
  func shuffleModeAdvancesToDifferentTrack() {
    let tracks = [
      Track(title: "First", artist: "Artist", duration: 120, fileExtension: "mp3", fileFingerprint: "1"),
      Track(title: "Second", artist: "Artist", duration: 140, fileExtension: "m4a", fileFingerprint: "2"),
      Track(title: "Third", artist: "Artist", duration: 160, fileExtension: "flac", fileFingerprint: "3")
    ]

    let playerCore = PlayerCore()
    playerCore.updateQueue(tracks)
    playerCore.load(tracks[0])
    playerCore.toggleShuffle()

    #expect(playerCore.isShuffleEnabled)

    playerCore.playNext()

    #expect(playerCore.currentTrack?.id != tracks[0].id)
    #expect(tracks.dropFirst().contains { $0.id == playerCore.currentTrack?.id })
  }

  @Test
  func repeatOneRestartsCurrentTrackWhenPlaybackEnds() {
    let track = Track(title: "First", artist: "Artist", duration: 200, fileExtension: "mp3", fileFingerprint: "1")
    let playerCore = PlayerCore()

    playerCore.updateQueue([track])
    playerCore.load(track)
    playerCore.seek(to: 0.5)
    playerCore.cycleRepeatMode()

    #expect(playerCore.repeatMode == .one)

    playerCore.advanceAfterCurrentTrack()

    #expect(playerCore.currentTrack?.id == track.id)
    #expect(playerCore.currentTime == 0)
    #expect(playerCore.progress == 0)
  }
}
