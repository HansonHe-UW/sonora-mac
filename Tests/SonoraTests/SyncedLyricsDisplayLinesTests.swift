import Foundation
import Testing
@testable import Sonora

struct SyncedLyricsDisplayLinesTests {
  @Test
  func splitsCJKFragmentsIntoIndependentDisplayLines() {
    let lines = [
      LyricsLine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        time: 10,
        text: "和我一起从所有的轨道脱离 飘浮爱情里 滑过最美的天际"
      ),
      LyricsLine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        time: 19,
        text: "下一句"
      )
    ]

    let displayLines = SyncedLyricsDisplayLines.make(from: lines)

    #expect(displayLines.map(\.text) == [
      "和我一起从所有的轨道脱离",
      "飘浮爱情里",
      "滑过最美的天际",
      "下一句"
    ])
  }

  @Test
  func estimatesFragmentTimingBeforeNextLyricLine() {
    let lines = [
      LyricsLine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        time: 10,
        text: "第一句很漫长 第二句也很漫长 第三句还是很漫长"
      ),
      LyricsLine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        time: 19,
        text: "下一句"
      )
    ]

    let displayLines = SyncedLyricsDisplayLines.make(from: lines)

    #expect(displayLines[0].time == 10)
    #expect(displayLines[1].time == 13)
    #expect(displayLines[2].time == 16)
    #expect(displayLines[3].time == 19)
  }

  @Test
  func tracksSourceLineFragmentBoundaries() {
    let sourceLineID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let lines = [
      LyricsLine(
        id: sourceLineID,
        time: 10,
        text: "第一句很漫长 第二句也很漫长 第三句还是很漫长"
      )
    ]

    let displayLines = SyncedLyricsDisplayLines.make(from: lines)

    #expect(displayLines.map(\.sourceLineID) == [sourceLineID, sourceLineID, sourceLineID])
    #expect(displayLines.map(\.fragmentIndex) == [0, 1, 2])
    #expect(displayLines.map(\.fragmentCount) == [3, 3, 3])
    #expect(displayLines.map(\.endsSourceLine) == [false, false, true])
  }

  @Test
  func keepsShortCJKGroupsAsSingleDisplayLine() {
    let lines = [
      LyricsLine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        time: 10,
        text: "路还长 在心上 总还有希望"
      )
    ]

    let displayLines = SyncedLyricsDisplayLines.make(from: lines)

    #expect(displayLines.count == 1)
    #expect(displayLines[0].text == "路还长 在心上 总还有希望")
  }
}
