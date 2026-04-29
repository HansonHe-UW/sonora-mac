import Foundation

struct Track: Identifiable, Hashable {
  let id: UUID
  var title: String
  var artist: String
  var album: String?
  var duration: TimeInterval?
  var fileExtension: String
  var fileURL: URL?
  var fileFingerprint: String
  var identity: TrackIdentity

  init(
    id: UUID = UUID(),
    title: String,
    artist: String,
    album: String? = nil,
    duration: TimeInterval? = nil,
    fileExtension: String,
    fileURL: URL? = nil,
    fileFingerprint: String
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.fileExtension = fileExtension
    self.fileURL = fileURL
    self.fileFingerprint = fileFingerprint
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

struct NormalizedTrackIdentity: Hashable {
  var title: String
  var artist: String
  var album: String?
  var duration: TimeInterval?
  var isrc: String?
}
