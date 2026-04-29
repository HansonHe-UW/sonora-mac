import Foundation
import Testing
@testable import Sonora

struct LRCLIBProviderTests {
  @Test
  func decodesResponseWithFloatDuration() throws {
    let json = """
    {
      "id": 42,
      "trackName": "Song",
      "artistName": "Artist",
      "albumName": "Album",
      "duration": 213.47,
      "plainLyrics": "some lyrics",
      "syncedLyrics": null
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(LRCLIBLyricsResponse.self, from: json)

    #expect(response.id == 42)
    #expect(abs(response.duration - 213.47) < 0.001)
  }

  @Test
  func decodesResponseWithIntegerDuration() throws {
    let json = """
    {
      "id": 7,
      "trackName": "Track",
      "artistName": "Band",
      "albumName": null,
      "duration": 180,
      "plainLyrics": null,
      "syncedLyrics": "[00:01.00]Hello"
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(LRCLIBLyricsResponse.self, from: json)

    #expect(response.duration == 180)
  }
}
