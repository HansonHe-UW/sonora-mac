import Foundation

enum TrackAccessResolver {
  static func refresh(_ track: Track) -> Track {
    var updatedTrack = track

    if let bookmarkData = track.bookmarkData {
      var isStale = false
      if let resolvedURL = try? URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ) {
        updatedTrack.fileURL = resolvedURL
        updatedTrack.accessState = fileExists(at: resolvedURL) ? .available : .missing
        return updatedTrack
      }

      if let fileURL = track.fileURL {
        updatedTrack.fileURL = fileURL
        updatedTrack.accessState = fileExists(at: fileURL) ? .available : .missing
      } else {
        updatedTrack.accessState = .bookmarkResolutionFailed
      }
      return updatedTrack
    }

    if let fileURL = track.fileURL {
      updatedTrack.accessState = fileExists(at: fileURL) ? .available : .missing
      return updatedTrack
    }

    updatedTrack.accessState = .missing
    return updatedTrack
  }

  private static func fileExists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }
}
