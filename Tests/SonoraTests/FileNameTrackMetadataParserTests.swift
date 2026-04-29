import Foundation
import Testing
@testable import Sonora

struct FileNameTrackMetadataParserTests {
  @Test
  func parsesArtistAndTitleFromSeparatedFilename() {
    let url = URL(fileURLWithPath: "/tmp/01 Jay Chou - Qing Tian.mp3")
    let parsed = FileNameTrackMetadataParser.titleAndArtist(from: url)

    #expect(parsed.artist == "Jay Chou")
    #expect(parsed.title == "Qing Tian")
  }

  @Test
  func fallsBackToTitleOnlyWhenSeparatorMissing() {
    let url = URL(fileURLWithPath: "/tmp/晴天.flac")
    let parsed = FileNameTrackMetadataParser.titleAndArtist(from: url)

    #expect(parsed.artist == nil)
    #expect(parsed.title == "晴天")
  }
}
