import Foundation

enum TrackMetadataNormalizer {
  static func normalize(_ identity: TrackIdentity) -> NormalizedTrackIdentity {
    let normalizedTitle = clean(identity.title) ?? clean(FileNameTrackMetadataParser.titleAndArtist(from: fileURL(from: identity)).title) ?? "Unknown Title"
    let normalizedArtist = clean(identity.artist) ?? "Unknown Artist"
    let normalizedAlbum = clean(identity.album)

    return NormalizedTrackIdentity(
      title: normalizedTitle,
      artist: normalizedArtist,
      album: normalizedAlbum,
      duration: identity.duration,
      isrc: clean(identity.isrc)
    )
  }

  static func searchVariants(for identity: NormalizedTrackIdentity) -> [NormalizedTrackIdentity] {
    let titleVariants = variants(forTitle: identity.title)
    let artistVariants = variants(forArtist: identity.artist)
    let albumVariants: [String?] = uniqueOptionalStrings([identity.album, nil])
    let durationVariants: [TimeInterval?] = uniqueOptionalDurations([identity.duration, nil])

    var variants: [NormalizedTrackIdentity] = []

    for title in titleVariants {
      for artist in artistVariants {
        for album in albumVariants {
          for duration in durationVariants {
            variants.append(
              NormalizedTrackIdentity(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                isrc: identity.isrc
              )
            )
          }
        }
      }
    }

    return uniqueIdentities(variants)
  }

  private static func clean(_ value: String?) -> String? {
    guard let value else { return nil }

    let cleaned = value
      .replacingOccurrences(of: #"\((feat|ft|live|remaster|remastered|explicit)[^)]+\)"#, with: "", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"\[(feat|ft|live|remaster|remastered|explicit)[^\]]+\]"#, with: "", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"\s+[-–]\s+(feat|ft)\.?\s+.+$"#, with: "", options: [.regularExpression, .caseInsensitive])
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmedForMetadata

    return cleaned.isEmpty ? nil : cleaned
  }

  private static func variants(forTitle title: String) -> [String] {
    uniqueStrings([
      title,
      title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmedForMetadata,
      title.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: "", options: .regularExpression).trimmedForMetadata
    ].filter { !$0.isEmpty })
  }

  private static func variants(forArtist artist: String) -> [String] {
    var variants = [artist]
    let delimiters = [" feat. ", " ft. ", " & ", ",", ";", "/", " x "]

    for delimiter in delimiters {
      if artist.localizedCaseInsensitiveContains(delimiter) {
        variants.append(artist.components(separatedBy: delimiter).first?.trimmedForMetadata ?? artist)
      }
    }

    return uniqueStrings(variants.filter { !$0.isEmpty })
  }

  private static func fileURL(from identity: TrackIdentity) -> URL {
    URL(fileURLWithPath: "/tmp/\(identity.fileName)")
  }
}

private func uniqueStrings(_ values: [String]) -> [String] {
  var seen = Set<String>()
  return values.filter { seen.insert($0).inserted }
}

private func uniqueOptionalStrings(_ values: [String?]) -> [String?] {
  var seen = Set<String>()
  var result: [String?] = []

  for value in values {
    let key = value ?? "__nil__"
    if seen.insert(key).inserted {
      result.append(value)
    }
  }

  return result
}

private func uniqueOptionalDurations(_ values: [TimeInterval?]) -> [TimeInterval?] {
  var seen = Set<String>()
  var result: [TimeInterval?] = []

  for value in values {
    let key = value.map { String($0) } ?? "__nil__"
    if seen.insert(key).inserted {
      result.append(value)
    }
  }

  return result
}

private func uniqueIdentities(_ values: [NormalizedTrackIdentity]) -> [NormalizedTrackIdentity] {
  var seen = Set<String>()
  var result: [NormalizedTrackIdentity] = []

  for value in values {
    let key = "\(value.title)|\(value.artist)|\(value.album ?? "")|\(value.duration.map { String($0) } ?? "")|\(value.isrc ?? "")"
    if seen.insert(key).inserted {
      result.append(value)
    }
  }

  return result
}
