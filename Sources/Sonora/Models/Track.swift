import Foundation

enum TrackAccessState: String, Codable, Hashable {
  case available
  case missing
  case bookmarkResolutionFailed

  var statusText: String? {
    switch self {
    case .available:
      return nil
    case .missing:
      return "File missing"
    case .bookmarkResolutionFailed:
      return "Permission required"
    }
  }
}

struct Track: Identifiable, Hashable {
  let id: UUID
  var title: String
  var artist: String
  var album: String?
  var duration: TimeInterval?
  var fileExtension: String
  var fileURL: URL?
  var fileFingerprint: String
  var bookmarkData: Data?
  var artworkData: Data?
  var accessState: TrackAccessState
  var identity: TrackIdentity

  init(
    id: UUID = UUID(),
    title: String,
    artist: String,
    album: String? = nil,
    duration: TimeInterval? = nil,
    fileExtension: String,
    fileURL: URL? = nil,
    fileFingerprint: String,
    bookmarkData: Data? = nil,
    artworkData: Data? = nil,
    accessState: TrackAccessState = .available
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.fileExtension = fileExtension
    self.fileURL = fileURL
    self.fileFingerprint = fileFingerprint
    self.bookmarkData = bookmarkData
    self.artworkData = artworkData
    self.accessState = accessState
    self.identity = TrackIdentity(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      isrc: nil,
      fileName: fileURL?.lastPathComponent ?? "\(title).\(fileExtension)",
      fileFingerprint: fileFingerprint,
      fileExtension: fileExtension
    )
  }
}

extension Track: Codable {}

struct TrackIdentity: Hashable {
  var title: String?
  var artist: String?
  var album: String?
  var duration: TimeInterval?
  var isrc: String?
  var fileName: String
  var fileFingerprint: String
  var fileExtension: String
}

extension TrackIdentity: Codable {}

struct NormalizedTrackIdentity: Hashable {
  var title: String
  var artist: String
  var album: String?
  var duration: TimeInterval?
  var isrc: String?
}

struct TrackImportIssue: Identifiable, Hashable {
  let id: UUID
  var fileName: String
  var reason: String

  init(id: UUID = UUID(), fileName: String, reason: String) {
    self.id = id
    self.fileName = fileName
    self.reason = reason
  }
}

struct TrackImportSummary: Identifiable, Hashable {
  let id: UUID
  var importedCount: Int
  var duplicateCount: Int
  var issues: [TrackImportIssue]

  init(
    id: UUID = UUID(),
    importedCount: Int,
    duplicateCount: Int,
    issues: [TrackImportIssue]
  ) {
    self.id = id
    self.importedCount = importedCount
    self.duplicateCount = duplicateCount
    self.issues = issues
  }

  var totalProblemCount: Int {
    duplicateCount + issues.count
  }

  var statusText: String {
    switch (importedCount, totalProblemCount) {
    case (0, 0):
      return "No tracks imported."
    case (_, 0):
      return "Imported \(importedCount) track\(importedCount == 1 ? "" : "s")."
    case (0, _):
      return "No new tracks imported. \(totalProblemCount) issue\(totalProblemCount == 1 ? "" : "s")."
    default:
      return "Imported \(importedCount) track\(importedCount == 1 ? "" : "s"), \(totalProblemCount) issue\(totalProblemCount == 1 ? "" : "s")."
    }
  }
}

struct LibrarySnapshot: Codable, Hashable {
  var tracks: [Track]
  var selectedTrackID: Track.ID?
}
