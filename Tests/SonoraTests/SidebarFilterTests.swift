import Foundation
import Testing
@testable import Sonora

struct SidebarFilterTests {
  @Test
  func returnsAllTracksWhenQueryIsEmpty() {
    let tracks = [
      makeTrack(title: "Song A", artist: "Artist 1"),
      makeTrack(title: "Song B", artist: "Artist 2")
    ]
    #expect(SidebarView.filterTracks(tracks, query: "") == tracks)
    #expect(SidebarView.filterTracks(tracks, query: "   ") == tracks)
  }

  @Test
  func filtersByTitle() {
    let tracks = [
      makeTrack(title: "望春風", artist: "陶喆"),
      makeTrack(title: "Airport", artist: "陶喆")
    ]
    let result = SidebarView.filterTracks(tracks, query: "airport")
    #expect(result.count == 1)
    #expect(result[0].title == "Airport")
  }

  @Test
  func filtersByArtist() {
    let tracks = [
      makeTrack(title: "Song", artist: "David Tao"),
      makeTrack(title: "Song", artist: "Jay Chou")
    ]
    let result = SidebarView.filterTracks(tracks, query: "jay")
    #expect(result.count == 1)
    #expect(result[0].artist == "Jay Chou")
  }

  @Test
  func filtersByAlbum() {
    let tracks = [
      makeTrack(title: "Song", artist: "Artist", album: "Blue Rain"),
      makeTrack(title: "Song", artist: "Artist", album: "Planet")
    ]
    let result = SidebarView.filterTracks(tracks, query: "blue")
    #expect(result.count == 1)
    #expect(result[0].album == "Blue Rain")
  }

  @Test
  func isCaseInsensitive() {
    let tracks = [makeTrack(title: "望春風", artist: "陶喆")]
    #expect(SidebarView.filterTracks(tracks, query: "陶喆").count == 1)
    #expect(SidebarView.filterTracks(tracks, query: "zzz").count == 0)
  }
}

private func makeTrack(title: String, artist: String, album: String? = nil) -> Track {
  Track(
    title: title,
    artist: artist,
    album: album,
    fileExtension: "mp3",
    fileFingerprint: UUID().uuidString
  )
}
