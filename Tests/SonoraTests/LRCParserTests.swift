import Testing
@testable import Sonora

struct LRCParserTests {
  @Test
  func parsesSyncedLyricsWithMultipleTimestamps() {
    let text = """
    [00:12.30]First line
    [00:16.80][00:20.10]Second line
    """

    let lines = LRCParser.parse(text)

    #expect(lines.count == 3)
    #expect(lines[0].text == "First line")
    #expect(lines[0].time == 12.3)
    #expect(lines[1].time == 16.8)
    #expect(lines[2].time == 20.1)
  }

  @Test
  func filtersBlankLinesFromParsedResult() {
    let text = """
    [00:10.00]First line
    [00:15.00]
    [00:20.00]Third line
    """

    let lines = LRCParser.parse(text)

    #expect(lines.count == 2)
    #expect(lines[0].text == "First line")
    #expect(lines[1].text == "Third line")
  }

  @Test
  func filtersMultipleBlankLinesAtSameTimestamp() {
    let text = """
    [00:00.000]
    [00:00.000]Actual lyric
    [00:05.000]Next lyric
    """

    let lines = LRCParser.parse(text)

    #expect(lines.count == 2)
    #expect(lines[0].text == "Actual lyric")
    #expect(lines[1].text == "Next lyric")
  }

  @Test
  func appliesGlobalOffsetMetadataToAllTimestamps() {
    let text = """
    [offset:500]
    [00:12.30]First line
    [00:16.80][00:20.10]Second line
    """

    let lines = LRCParser.parse(text)

    #expect(lines.count == 3)
    #expect(lines[0].time == 11.8)
    #expect(lines[1].time == 16.3)
    #expect(lines[2].time == 19.6)
  }
}
