import Foundation

struct SyncedLyricsDisplayLine: Identifiable, Hashable {
  var id: String
  var sourceLineID: LyricsLine.ID
  var fragmentIndex: Int
  var fragmentCount: Int
  var time: TimeInterval
  var text: String

  var endsSourceLine: Bool {
    fragmentIndex == fragmentCount - 1
  }
}

enum SyncedLyricsDisplayLines {
  static func make(from lines: [LyricsLine]) -> [SyncedLyricsDisplayLine] {
    lines.map { line in
      SyncedLyricsDisplayLine(
        id: "\(line.id.uuidString)-0",
        sourceLineID: line.id,
        fragmentIndex: 0,
        fragmentCount: 1,
        time: line.time,
        text: line.text
      )
    }
  }
}
