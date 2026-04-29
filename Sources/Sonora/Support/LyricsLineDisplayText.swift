import Foundation

enum LyricsLineDisplayText {
  private static let maxCompactCJKLength = 12

  static func format(_ text: String) -> String {
    fragments(text).joined(separator: "\n")
  }

  static func fragments(_ text: String) -> [String] {
    let normalized = text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard containsCJK(in: normalized) else { return [normalized] }

    return normalized
      .components(separatedBy: .newlines)
      .flatMap(splitCJKPhrases)
      .filter { !$0.isEmpty }
  }

  private static func splitCJKPhrases(_ text: String) -> [String] {
    let whitespaceSplit = splitCJKPhrasesSeparatedByWhitespace(text)
    let punctuationSplit = splitCJKPhrasesSeparatedByPunctuation(whitespaceSplit)

    guard punctuationSplit.count > 1 else { return punctuationSplit }
    guard compactLength(of: text) > maxCompactCJKLength else {
      return [normalizeInlineWhitespace(in: text)]
    }

    return punctuationSplit
  }

  private static func splitCJKPhrasesSeparatedByWhitespace(_ text: String) -> [String] {
    let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
    guard tokens.count > 1 else { return [text] }

    var lines: [String] = []
    var currentLine = tokens[0]

    for token in tokens.dropFirst() {
      if containsCJK(in: currentLine), containsCJK(in: token) {
        lines.append(currentLine)
        currentLine = token
      } else {
        currentLine += " " + token
      }
    }

    lines.append(currentLine)
    return lines
  }

  private static func splitCJKPhrasesSeparatedByPunctuation(_ lines: [String]) -> [String] {
    lines.flatMap { line in
      var fragments: [String] = []
      var currentFragment = ""

      for character in line {
        currentFragment.append(character)

        if isCJKPhrasePunctuation(character) {
          fragments.append(currentFragment.trimmingCharacters(in: .whitespacesAndNewlines))
          currentFragment = ""
        }
      }

      let remaining = currentFragment.trimmingCharacters(in: .whitespacesAndNewlines)
      if !remaining.isEmpty {
        fragments.append(remaining)
      }

      return fragments
    }
  }

  private static func compactLength(of text: String) -> Int {
    text.reduce(into: 0) { count, character in
      if !character.isWhitespace {
        count += 1
      }
    }
  }

  private static func normalizeInlineWhitespace(in text: String) -> String {
    text
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  private static func containsCJK(in text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
      switch scalar.value {
      case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
        return true
      default:
        return false
      }
    }
  }

  private static func isCJKPhrasePunctuation(_ character: Character) -> Bool {
    switch character {
    case "，", "。", "、", "；", "：", "？", "！":
      return true
    default:
      return false
    }
  }
}
