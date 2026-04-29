import AVFoundation
import CoreMedia
import Foundation

struct TrackImportBatch {
  var importedTracks: [Track]
  var issues: [TrackImportIssue]
}

enum TrackImporterError: LocalizedError {
  case unsupportedFormat(String)
  case encryptedOrPrivateFormat(String)
  case unreadableAsset
  case unplayableAsset
  case bookmarkCreationFailed

  var errorDescription: String? {
    switch self {
    case .unsupportedFormat(let fileExtension):
      return "Unsupported audio format: .\(fileExtension)"
    case .encryptedOrPrivateFormat(let fileExtension):
      return "Private or encrypted format is not supported: .\(fileExtension)"
    case .unreadableAsset:
      return "The file metadata could not be read."
    case .unplayableAsset:
      return "AVFoundation cannot play this file."
    case .bookmarkCreationFailed:
      return "Security-scoped bookmark creation failed."
    }
  }
}

struct TrackImporter {
  func importTracks(from urls: [URL]) async -> TrackImportBatch {
    var importedTracks: [Track] = []
    var issues: [TrackImportIssue] = []

    for url in urls {
      do {
        let track = try await makeTrack(from: url)
        importedTracks.append(track)
      } catch {
        issues.append(
          TrackImportIssue(
            fileName: url.lastPathComponent,
            reason: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
          )
        )
      }
    }

    return TrackImportBatch(importedTracks: importedTracks, issues: issues)
  }

  private func makeTrack(from url: URL) async throws -> Track {
    let fileExtension = AudioFormatPolicy.normalizedExtension(url.pathExtension)

    if AudioFormatPolicy.isKnownUnsupportedExtension(fileExtension) {
      throw TrackImporterError.encryptedOrPrivateFormat(fileExtension)
    }

    guard AudioFormatPolicy.isSupportedExtension(fileExtension) else {
      throw TrackImporterError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
    }

    let startedAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if startedAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let asset = AVURLAsset(url: url)
    let isPlayable = try await asset.load(.isPlayable)
    guard isPlayable else {
      throw TrackImporterError.unplayableAsset
    }

    let commonMetadata = try await asset.load(.commonMetadata)
    let duration = try await asset.load(.duration)

    let filenameMetadata = FileNameTrackMetadataParser.titleAndArtist(from: url)
    let title = try await metadataValue(for: .commonIdentifierTitle, in: commonMetadata) ?? filenameMetadata.title
    let artist = try await metadataValue(for: .commonIdentifierArtist, in: commonMetadata) ?? filenameMetadata.artist ?? "Unknown Artist"
    let album = try await metadataValue(for: .commonIdentifierAlbumName, in: commonMetadata)
    let artworkData = try await metadataDataValue(for: .commonIdentifierArtwork, in: commonMetadata)
    let bookmarkData =
      (try? url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: [.contentModificationDateKey, .fileSizeKey],
        relativeTo: nil
      )) ??
      (try? url.bookmarkData(
        options: [.minimalBookmark],
        includingResourceValuesForKeys: [.contentModificationDateKey, .fileSizeKey],
        relativeTo: nil
      ))

    let resolvedDuration = seconds(from: duration)
    let fingerprint = try fileFingerprint(for: url)

    return Track(
      title: title,
      artist: artist,
      album: album,
      duration: resolvedDuration,
      fileExtension: fileExtension,
      fileURL: url,
      fileFingerprint: fingerprint,
      bookmarkData: bookmarkData,
      artworkData: artworkData
    )
  }

  private func metadataValue(
    for identifier: AVMetadataIdentifier,
    in items: [AVMetadataItem]
  ) async throws -> String? {
    for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier) {
      let value = try await item.load(.stringValue)?.trimmedForMetadata
      if let value, !value.isEmpty {
        return value
      }
    }

    return nil
  }

  private func metadataDataValue(
    for identifier: AVMetadataIdentifier,
    in items: [AVMetadataItem]
  ) async throws -> Data? {
    for item in AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier) {
      if let data = try await item.load(.dataValue) {
        return data
      }
    }

    return nil
  }

  private func seconds(from time: CMTime) -> TimeInterval? {
    guard time.isNumeric else { return nil }

    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite, seconds > 0 else { return nil }
    return seconds
  }

  private func fileFingerprint(for url: URL) throws -> String {
    let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    let sizeComponent = values.fileSize.map(String.init) ?? "unknown-size"
    let dateComponent = values.contentModificationDate?.timeIntervalSince1970.description ?? "unknown-date"
    return "\(url.standardizedFileURL.path)|\(sizeComponent)|\(dateComponent)"
  }
}
