import Foundation
import Testing
@testable import Sonora

struct SyncedLyricsScrollPolicyTests {
  @Test
  func initialUpdatePlacesCurrentPlaybackLine() {
    let lines = makeDisplayLines()
    var policy = SyncedLyricsScrollPolicy()

    let state = SyncedLyricsScrollState(lines: lines, currentTime: 12, lyricsOffset: 0)

    #expect(policy.update(to: state) == .initialPlacement(lines[1].id))
  }

  @Test
  func repeatedUpdateForSameLineDoesNotScrollAgain() {
    let lines = makeDisplayLines()
    var policy = SyncedLyricsScrollPolicy()
    let state = SyncedLyricsScrollState(lines: lines, currentTime: 12, lyricsOffset: 0)

    _ = policy.update(to: state)

    #expect(policy.update(to: state) == nil)
  }

  @Test
  func activeLineChangeFollowsPlayback() {
    let lines = makeDisplayLines()
    var policy = SyncedLyricsScrollPolicy()
    let initialState = SyncedLyricsScrollState(lines: lines, currentTime: 12, lyricsOffset: 0)
    let nextState = SyncedLyricsScrollState(lines: lines, currentTime: 22, lyricsOffset: 0)

    _ = policy.update(to: initialState)

    #expect(policy.update(to: nextState) == .activeLineChange(lines[2].id))
  }

  @Test
  func changedLyricsPayloadUsesInitialPlacement() {
    let originalLines = makeDisplayLines(idPrefix: 0)
    let replacementLines = makeDisplayLines(idPrefix: 10)
    var policy = SyncedLyricsScrollPolicy()
    let originalState = SyncedLyricsScrollState(lines: originalLines, currentTime: 12, lyricsOffset: 0)
    let replacementState = SyncedLyricsScrollState(lines: replacementLines, currentTime: 12, lyricsOffset: 0)

    _ = policy.update(to: originalState)

    #expect(policy.update(to: replacementState) == .initialPlacement(replacementLines[1].id))
  }

  @Test
  func activeLineCalculationUsesOffsetAdjustedTime() {
    let lines = makeDisplayLines()
    let state = SyncedLyricsScrollState(lines: lines, currentTime: 12, lyricsOffset: 3)

    #expect(state.activeLineID == lines[0].id)
  }

  private func makeDisplayLines(idPrefix: Int = 0) -> [SyncedLyricsDisplayLine] {
    SyncedLyricsDisplayLines.make(from: makeLines(idPrefix: idPrefix))
  }

  private func makeLines(idPrefix: Int = 0) -> [LyricsLine] {
    [
      LyricsLine(id: makeID(idPrefix + 1), time: 0, text: "First"),
      LyricsLine(id: makeID(idPrefix + 2), time: 10, text: "Second"),
      LyricsLine(id: makeID(idPrefix + 3), time: 20, text: "Third")
    ]
  }

  private func makeID(_ value: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
  }
}
