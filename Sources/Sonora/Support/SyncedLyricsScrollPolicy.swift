import Foundation

struct SyncedLyricsPayloadID: Hashable {
  var lineIDs: [LyricsLine.ID]

  init(lines: [LyricsLine]) {
    lineIDs = lines.map(\.id)
  }
}

struct SyncedLyricsScrollState: Hashable {
  var payloadID: SyncedLyricsPayloadID
  var activeLineID: LyricsLine.ID?

  init(lines: [LyricsLine], currentTime: TimeInterval, lyricsOffset: TimeInterval) {
    payloadID = SyncedLyricsPayloadID(lines: lines)

    let adjustedCurrentTime = LyricsTiming.adjustedCurrentTime(currentTime, offset: lyricsOffset)
    activeLineID = lines.last { $0.time <= adjustedCurrentTime }?.id ?? lines.first?.id
  }
}

enum SyncedLyricsScrollAction: Equatable {
  case initialPlacement(LyricsLine.ID)
  case activeLineChange(LyricsLine.ID)
}

struct SyncedLyricsScrollPolicy {
  private var previousPayloadID: SyncedLyricsPayloadID?
  private var previousActiveLineID: LyricsLine.ID?

  mutating func update(to state: SyncedLyricsScrollState) -> SyncedLyricsScrollAction? {
    defer {
      previousPayloadID = state.payloadID
      previousActiveLineID = state.activeLineID
    }

    guard let activeLineID = state.activeLineID else { return nil }

    if previousPayloadID != state.payloadID {
      return .initialPlacement(activeLineID)
    }

    if previousActiveLineID != activeLineID {
      return .activeLineChange(activeLineID)
    }

    return nil
  }
}
