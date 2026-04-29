import Foundation

struct LibraryPersistenceStore {
  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? Self.defaultFileURL()

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder = encoder

    self.decoder = JSONDecoder()
  }

  func loadSnapshot() -> LibrarySnapshot {
    guard let data = try? Data(contentsOf: fileURL) else {
      return LibrarySnapshot(tracks: [], selectedTrackID: nil)
    }

    return (try? decoder.decode(LibrarySnapshot.self, from: data))
      ?? LibrarySnapshot(tracks: [], selectedTrackID: nil)
  }

  func saveSnapshot(_ snapshot: LibrarySnapshot) throws {
    let data = try encoder.encode(snapshot)
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
  }

  private static func defaultFileURL() -> URL {
    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

    return appSupportURL
      .appendingPathComponent("Sonora", isDirectory: true)
      .appendingPathComponent("library.json", isDirectory: false)
  }
}
