import Foundation
import Testing
@testable import Sonora

struct NeteaseProviderTests {
  @Test
  func decodesSuggestResponse() throws {
    let json = """
    {
      "result": {
        "songs": [
          {
            "id": 2690548987,
            "name": "让爱再继续",
            "artists": [{"name": "陶喆"}],
            "album": {"name": "STUPID POP SONGS"},
            "duration": 252669
          }
        ]
      },
      "code": 200
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NeteaseSuggestResponse.self, from: json)
    let song = try #require(response.result.songs?.first)
    #expect(song.id == 2690548987)
    #expect(song.name == "让爱再继续")
    #expect(song.artists.first?.name == "陶喆")
    #expect(song.album?.name == "STUPID POP SONGS")
    #expect(song.duration == 252669)
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
    let durationMs = 252669
    let seconds = TimeInterval(durationMs) / 1000.0
    #expect(abs(seconds - 252.669) < 0.01)
  }

  @Test
  func searchBuildsCandidateFromSong() throws {
    let song = NeteaseSuggestResponse.Song(
      id: 2690548987,
      name: "让爱再继续",
      artists: [.init(name: "陶喆")],
      album: .init(name: "STUPID POP SONGS"),
      duration: 252669
    )
    let identity = NormalizedTrackIdentity(title: "讓愛再繼續", artist: "陶喆", duration: 253.0)
    let candidate = try #require(NeteaseProvider.makeCandidate(from: song, identity: identity))
    #expect(candidate.id == "2690548987")
    #expect(candidate.title == "让爱再继续")
    #expect(candidate.artist == "陶喆")
    #expect(candidate.album == "STUPID POP SONGS")
    #expect(candidate.providerName == "netease")
    #expect(candidate.confidence >= 0.5)
  }

  @Test
  func traditionalChineseMatchesSimplified() throws {
    let song = NeteaseSuggestResponse.Song(
      id: 999,
      name: "半晴天",
      artists: [.init(name: "陶喆")],
      album: .init(name: "STUPID POP SONGS"),
      duration: 294773
    )
    // User's metadata uses traditional characters
    let identity = NormalizedTrackIdentity(title: "半晴天", artist: "陶喆", duration: 295.0)
    let candidate = try #require(NeteaseProvider.makeCandidate(from: song, identity: identity))
    #expect(candidate.confidence >= 0.5)
  }

  @Test
  func toSimplifiedChineseConvertsTraditional() {
    #expect(NeteaseProvider.toSimplifiedChinese("讓愛再繼續") == "让爱再继续")
    #expect(NeteaseProvider.toSimplifiedChinese("陶喆") == "陶喆")
    #expect(NeteaseProvider.toSimplifiedChinese("Moonchild") == "Moonchild")
    #expect(NeteaseProvider.toSimplifiedChinese("微塵") == "微尘")
  }
}
