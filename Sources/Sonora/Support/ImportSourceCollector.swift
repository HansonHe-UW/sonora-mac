import Foundation

enum ImportSourceCollector {
  static func collectCandidateFiles(from urls: [URL]) -> [URL] {
    var collected = Set<URL>()

    for url in urls {
      let startedAccessing = url.startAccessingSecurityScopedResource()
      defer {
        if startedAccessing {
          url.stopAccessingSecurityScopedResource()
        }
      }

      let standardizedURL = url.standardizedFileURL

      if isDirectory(standardizedURL) {
        collectFilesRecursively(in: standardizedURL, into: &collected)
      } else if isCandidateAudioFile(standardizedURL) {
        collected.insert(standardizedURL)
      }
    }

    return collected.sorted {
      $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
    }
  }

  private static func collectFilesRecursively(in directoryURL: URL, into collected: inout Set<URL>) {
    guard let enumerator = FileManager.default.enumerator(
      at: directoryURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
      return
    }

    for case let fileURL as URL in enumerator {
      if isCandidateAudioFile(fileURL) {
        collected.insert(fileURL.standardizedFileURL)
      }
    }
  }

  private static func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
  }

  private static func isCandidateAudioFile(_ url: URL) -> Bool {
    guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
      return false
    }

    let fileExtension = AudioFormatPolicy.normalizedExtension(url.pathExtension)
    return AudioFormatPolicy.isSupportedExtension(fileExtension) || AudioFormatPolicy.isKnownUnsupportedExtension(fileExtension)
  }
}
