import Foundation
import Testing
@testable import Sonora

struct SyncedLyricsDisplayLinesTests {
  @Test
  func preservesOriginalLyricsLinesWithoutFragmentation() {
    let sourceLineID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let lines = [
      LyricsLine(
        id: sourceLineID,
        time: 10,
        text: "和我一起从所有的轨道脱离 飘浮爱情里 滑过最美的天际"
      )
    ]

    let displayLines = SyncedLyricsDisplayLines.make(from: lines)

    #expect(displayLines.count == 1)
    #expect(displayLines[0].sourceLineID == sourceLineID)
    #expect(displayLines[0].fragmentIndex == 0)
    #expect(displayLines[0].fragmentCount == 1)
    #expect(displayLines[0].time == 10)
    #expect(displayLines[0].text == lines[0].text)
    #expect(displayLines[0].endsSourceLine)
  }

  @Test
  func preservesOriginalTimingAcrossMultipleLines() {
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

    #expect(displayLines.map(\.time) == [10, 19])
    #expect(displayLines.map(\.text) == lines.map(\.text))
  }
}
