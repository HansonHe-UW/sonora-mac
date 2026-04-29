import Foundation

struct LyricsCacheStore {
  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? Self.defaultFileURL()
  }

  func load(for fingerprint: String) -> LyricsResult? {
    let cache = loadAll()
    return cache[fingerprint]
  }

  func save(_ result: LyricsResult, for fingerprint: String) throws {
    var cache = loadAll()
    cache[fingerprint] = result
    let data = try encoder.encode(cache)
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
  }

  private func loadAll() -> [String: LyricsResult] {
    guard let data = try? Data(contentsOf: fileURL) else {
      return [:]
    }

    return (try? decoder.decode([String: LyricsResult].self, from: data)) ?? [:]
  }

  private static func defaultFileURL() -> URL {
    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

    return appSupportURL
      .appendingPathComponent("Sonora", isDirectory: true)
      .appendingPathComponent("lyrics-cache.json", isDirectory: false)
  }
}
