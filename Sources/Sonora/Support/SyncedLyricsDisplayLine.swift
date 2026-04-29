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
    lines.enumerated().flatMap { index, line in
      let fragments = LyricsLineDisplayText.fragments(line.text)
      let step = estimatedStep(
        from: line.time,
        to: lines.indices.contains(index + 1) ? lines[index + 1].time : nil,
        fragmentCount: fragments.count
      )

      return fragments.enumerated().map { fragmentIndex, fragment in
        SyncedLyricsDisplayLine(
          id: "\(line.id.uuidString)-\(fragmentIndex)",
          sourceLineID: line.id,
          fragmentIndex: fragmentIndex,
          fragmentCount: fragments.count,
          time: line.time + (Double(fragmentIndex) * step),
          text: fragment
        )
      }
    }
  }

  private static func estimatedStep(
    from startTime: TimeInterval,
    to nextTime: TimeInterval?,
    fragmentCount: Int
  ) -> TimeInterval {
    guard fragmentCount > 1 else { return 0 }
    guard let nextTime, nextTime > startTime else { return 1.5 }

    return (nextTime - startTime) / Double(fragmentCount)
  }
}
