import Foundation

enum FileNameTrackMetadataParser {
  static func titleAndArtist(from url: URL) -> (title: String, artist: String?) {
    let stem = cleanedStem(from: url.deletingPathExtension().lastPathComponent)

    guard let separatorRange = stem.range(of: " - ") else {
      return (title: stem, artist: nil)
    }

    let leading = String(stem[..<separatorRange.lowerBound]).trimmedForMetadata
    let trailing = String(stem[separatorRange.upperBound...]).trimmedForMetadata

    guard !leading.isEmpty, !trailing.isEmpty else {
      return (title: stem, artist: nil)
    }

    return (title: trailing, artist: leading)
  }

  private static func cleanedStem(from value: String) -> String {
    let withoutTrackNumber = value.replacingOccurrences(
      of: #"^\s*\d{1,3}[\s._-]+"#,
      with: "",
      options: .regularExpression
    )

    return withoutTrackNumber
      .replacingOccurrences(of: "_", with: " ")
      .trimmedForMetadata
  }
}
