import Foundation

enum LRCParser {
  static func parse(_ text: String) -> [LyricsLine] {
    let lines = text.components(separatedBy: .newlines)
    var parsedLines: [LyricsLine] = []

    for rawLine in lines {
      let timestamps = timestampsAndContent(from: rawLine)
      guard !timestamps.times.isEmpty else { continue }

      for time in timestamps.times {
        parsedLines.append(LyricsLine(time: time, text: timestamps.content))
      }
    }

    return parsedLines.sorted { $0.time < $1.time }
  }

  private static func timestampsAndContent(from line: String) -> (times: [TimeInterval], content: String) {
    let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return ([], "")
    }

    let nsLine = line as NSString
    let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
    guard !matches.isEmpty else {
      return ([], "")
    }

    let times = matches.compactMap { match -> TimeInterval? in
      guard match.numberOfRanges >= 3 else { return nil }
      let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
      let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
      let fractionRange = match.range(at: 3)
      let fractionText = fractionRange.location == NSNotFound ? nil : nsLine.substring(with: fractionRange)
      let fraction = fractionValue(from: fractionText)
      return (minutes * 60) + seconds + fraction
    }

    let content = regex.stringByReplacingMatches(
      in: line,
      range: NSRange(location: 0, length: nsLine.length),
      withTemplate: ""
    )
    .trimmedForMetadata

    return (times, content)
  }

  private static func fractionValue(from text: String?) -> TimeInterval {
    guard let text, !text.isEmpty else { return 0 }

    switch text.count {
    case 1:
      return (Double(text) ?? 0) / 10
    case 2:
      return (Double(text) ?? 0) / 100
    default:
      return (Double(text) ?? 0) / 1000
    }
  }
}
