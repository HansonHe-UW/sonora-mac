import Foundation

struct LocalLRCProvider {
  func loadLyrics(for track: Track) -> LyricsResult? {
    guard let trackURL = track.fileURL else { return nil }
    let lrcURL = trackURL.deletingPathExtension().appendingPathExtension("lrc")
    guard let text = try? String(contentsOf: lrcURL, encoding: .utf8) else { return nil }

    let lines = LRCParser.parse(text)
    let content: LyricsContent = lines.isEmpty ? .plain(text.trimmedForMetadata) : .synced(lines)

    return LyricsResult(
      content: content,
      attribution: LyricsAttribution(
        providerName: "local-lrc",
        displayName: "Local LRC",
        copyrightText: nil,
        backlinkURLString: nil,
        pixelTrackingURLString: nil
      ),
      artworkURLString: nil
    )
  }
}
