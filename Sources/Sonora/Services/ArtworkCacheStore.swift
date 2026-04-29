import Foundation

struct ArtworkCacheStore {
  private let cacheDirectory: URL

  init(cacheDirectory: URL? = nil) {
    self.cacheDirectory = cacheDirectory ?? Self.defaultCacheDirectory()
  }

  func load(for fingerprint: String) -> Data? {
    let fileURL = cacheDirectory.appendingPathComponent(fileName(for: fingerprint))
    return try? Data(contentsOf: fileURL)
  }

  func save(_ data: Data, for fingerprint: String) {
    let fileURL = cacheDirectory.appendingPathComponent(fileName(for: fingerprint))
    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: .atomic)
  }

  private func fileName(for fingerprint: String) -> String {
    fingerprint.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? fingerprint
  }

  private static func defaultCacheDirectory() -> URL {
    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

    return appSupportURL
      .appendingPathComponent("Sonora", isDirectory: true)
      .appendingPathComponent("ArtworkCache", isDirectory: true)
  }
}
