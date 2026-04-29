import Foundation

struct SyncedLyricsPayloadID: Hashable {
  var lineIDs: [SyncedLyricsDisplayLine.ID]

  init(lines: [SyncedLyricsDisplayLine]) {
    lineIDs = lines.map(\.id)
  }
}

struct SyncedLyricsScrollState: Hashable {
  var payloadID: SyncedLyricsPayloadID
  var activeLineID: SyncedLyricsDisplayLine.ID?

  init(lines: [SyncedLyricsDisplayLine], currentTime: TimeInterval, lyricsOffset: TimeInterval) {
    payloadID = SyncedLyricsPayloadID(lines: lines)

    let adjustedCurrentTime = LyricsTiming.adjustedCurrentTime(currentTime, offset: lyricsOffset)
    activeLineID = lines.last { $0.time <= adjustedCurrentTime }?.id ?? lines.first?.id
  }
}

enum SyncedLyricsScrollAction: Equatable {
  case initialPlacement(SyncedLyricsDisplayLine.ID)
  case activeLineChange(SyncedLyricsDisplayLine.ID)
}

struct SyncedLyricsScrollPolicy {
  private var previousPayloadID: SyncedLyricsPayloadID?
  private var previousActiveLineID: SyncedLyricsDisplayLine.ID?

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
