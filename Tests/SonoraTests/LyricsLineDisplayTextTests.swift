import Testing
@testable import Sonora

struct LyricsLineDisplayTextTests {
  @Test
  func splitsCJKPhrasesSeparatedBySpaces() {
    let text = "和我一起从所有的轨道脱离 飘浮爱情里 滑过最美的天际"

    #expect(LyricsLineDisplayText.format(text) == """
    和我一起从所有的轨道脱离
    飘浮爱情里
    滑过最美的天际
    """)
  }

  @Test
  func preservesEnglishWordSpacing() {
    let text = "You are my shining star, I'll follow you forever"

    #expect(LyricsLineDisplayText.format(text) == text)
  }

  @Test
  func splitsCJKPhrasesSeparatedByPunctuation() {
    let text = "越过了时空，还是我心中唯一"

    #expect(LyricsLineDisplayText.format(text) == """
    越过了时空，
    还是我心中唯一
    """)
  }

  @Test
  func keepsShortCJKPhraseGroupsOnOneLine() {
    let text = "路还长 在心上 总还有希望"

    #expect(LyricsLineDisplayText.format(text) == text)
  }
}
