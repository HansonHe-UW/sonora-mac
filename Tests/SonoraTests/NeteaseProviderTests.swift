import Foundation
import Testing
@testable import Sonora

struct NeteaseProviderTests {
  @Test
  func decodesSearchResponse() throws {
    let json = """
    {
      "result": {
        "songs": [
          {
            "id": 123456,
            "name": "望春風",
            "artists": [{"name": "陶喆"}],
            "album": {"name": "黑色柳丁"},
            "duration": 213470
          }
        ]
      },
      "code": 200
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NeteaseSearchResponse.self, from: json)
    let song = try #require(response.result.songs.first)
    #expect(song.id == 123456)
    #expect(song.name == "望春風")
    #expect(song.artists.first?.name == "陶喆")
    #expect(song.album?.name == "黑色柳丁")
    #expect(song.duration == 213470)
  }

  @Test
  func decodesLyricsResponse() throws {
    let json = """
    {
      "lrc": {
        "lyric": "[00:01.00]望春風\\n[00:05.00]等待春的消息\\n"
      },
      "code": 200
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NeteaseLyricsResponse.self, from: json)
    #expect(response.lrc?.lyric.contains("[00:01.00]") == true)
  }

  @Test
  func decodesLyricsResponseWithoutLRC() throws {
    let json = """
    { "code": 200 }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NeteaseLyricsResponse.self, from: json)
    #expect(response.lrc == nil)
  }

  @Test
  func convertsDurationMillisecondsToSeconds() {
    let durationMs = 213470
    let seconds = TimeInterval(durationMs) / 1000.0
    #expect(abs(seconds - 213.47) < 0.01)
  }

  @Test
  func searchBuildsCandidateFromSong() throws {
    let song = NeteaseSearchResponse.Song(
      id: 999,
      name: "Airport",
      artists: [.init(name: "陶喆")],
      album: .init(name: "黑色柳丁"),
      duration: 240000
    )
    let candidate = NeteaseProvider.makeCandidate(from: song)
    #expect(candidate.id == "999")
    #expect(candidate.title == "Airport")
    #expect(candidate.artist == "陶喆")
    #expect(candidate.album == "黑色柳丁")
    #expect(abs(candidate.duration! - 240.0) < 0.01)
    #expect(candidate.providerName == "netease")
  }
}
