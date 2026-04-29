import Testing
@testable import Sonora

struct LyricsStatePresentationTests {
  @Test
  func emptyStateUsesNotYetLoadedCopy() {
    let presentation = LyricsStatePresentation.forState(.empty)

    #expect(presentation?.title == "Lyrics Ready When You Are")
    #expect(presentation?.showsReloadAction == false)
  }

  @Test
  func noMatchUsesDistinctCopyAndReloadAction() {
    let presentation = LyricsStatePresentation.forState(.unavailable(.noMatch))

    #expect(presentation?.title == "No Lyrics Match")
    #expect(presentation?.showsReloadAction == true)
  }

  @Test
  func networkFailureUsesDistinctCopyAndReloadAction() {
    let presentation = LyricsStatePresentation.forState(.unavailable(.networkFailure))

    #expect(presentation?.title == "Lyrics Provider Unreachable")
    #expect(presentation?.systemImage == "wifi.exclamationmark")
    #expect(presentation?.showsReloadAction == true)
  }

  @Test
  func downloadDisabledSuppressesReloadAction() {
    let presentation = LyricsStatePresentation.forState(.unavailable(.downloadDisabled))

    #expect(presentation?.title == "Auto-Download Disabled")
    #expect(presentation?.showsReloadAction == false)
  }

  @Test
  func providerErrorUsesDetailText() {
    let presentation = LyricsStatePresentation.forState(.unavailable(.providerError("Provider timeout")))

    #expect(presentation?.title == "Lyrics Provider Error")
    #expect(presentation?.message == "Provider timeout")
    #expect(presentation?.showsReloadAction == true)
  }

  @Test
  func readyStateHasNoPresentation() {
    #expect(LyricsStatePresentation.forState(.ready(sampleResult)) == nil)
  }

  private var sampleResult: LyricsResult {
    LyricsResult(
      content: .plain("lyrics"),
      attribution: LyricsAttribution(
        providerName: "netease",
        displayName: "NetEase",
        copyrightText: nil,
        backlinkURLString: nil,
        pixelTrackingURLString: nil
      ),
      artworkURLString: nil
    )
  }
}
