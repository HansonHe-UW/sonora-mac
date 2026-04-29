import Foundation
import Testing
@testable import Sonora

struct LyricsTimingTests {
  @Test
  func positiveOffsetDelaysLyricHighlighting() {
    #expect(LyricsTiming.adjustedCurrentTime(42, offset: 0.5) == 41.5)
  }

  @Test
  func positiveOffsetSeeksLaterIntoPlayback() {
    #expect(LyricsTiming.seekTime(forLyricTime: 42, offset: 0.5) == 42.5)
  }

  @Test
  func offsetHelpersClampNegativeResultsToZero() {
    #expect(LyricsTiming.adjustedCurrentTime(0.2, offset: 0.5) == 0)
    #expect(LyricsTiming.seekTime(forLyricTime: 0.2, offset: -0.5) == 0)
  }
}
