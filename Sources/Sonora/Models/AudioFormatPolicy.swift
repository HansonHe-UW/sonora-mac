import Foundation
import UniformTypeIdentifiers

enum AudioFormatPolicy {
  static let supportedExtensions: Set<String> = [
    "mp3",
    "m4a",
    "aac",
    "wav",
    "flac",
    "aiff",
    "aif",
    "caf"
  ]

  static let unsupportedExtensions: Set<String> = [
    "ncm",
    "kgm",
    "mflac0",
    "ogg",
    "opus",
    "ape",
    "wma"
  ]

  static func isSupportedExtension(_ fileExtension: String) -> Bool {
    supportedExtensions.contains(normalizedExtension(fileExtension))
  }

  static func isKnownUnsupportedExtension(_ fileExtension: String) -> Bool {
    let normalized = normalizedExtension(fileExtension)
    return unsupportedExtensions.contains(normalized) || normalized.hasPrefix("qmc")
  }

  static func normalizedExtension(_ fileExtension: String) -> String {
    fileExtension
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingPrefix(".")
      .lowercased()
  }

  static var supportedContentTypes: [UTType] {
    supportedExtensions.compactMap { fileExtension in
      UTType(filenameExtension: fileExtension, conformingTo: .audio)
    }
  }
}
