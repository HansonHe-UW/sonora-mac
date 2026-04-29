import Foundation
import Testing
@testable import Sonora

struct ImportSourceCollectorTests {
  @Test
  func collectsSupportedFilesInsideFolders() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let albumDirectory = tempDirectory.appendingPathComponent("Album", isDirectory: true)
    try FileManager.default.createDirectory(at: albumDirectory, withIntermediateDirectories: true)

    let songFile = albumDirectory.appendingPathComponent("Track 01.mp3")
    let coverFile = albumDirectory.appendingPathComponent("cover.jpg")
    let unsupportedAudioFile = albumDirectory.appendingPathComponent("Track 02.ncm")

    try Data("audio".utf8).write(to: songFile)
    try Data("image".utf8).write(to: coverFile)
    try Data("private".utf8).write(to: unsupportedAudioFile)

    defer {
      try? FileManager.default.removeItem(at: tempDirectory)
    }

    let collected = ImportSourceCollector.collectCandidateFiles(from: [albumDirectory])

    #expect(collected.contains(songFile.standardizedFileURL))
    #expect(collected.contains(unsupportedAudioFile.standardizedFileURL))
    #expect(!collected.contains(coverFile.standardizedFileURL))
  }
}
