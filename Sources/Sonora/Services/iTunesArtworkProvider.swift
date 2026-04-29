import Foundation

struct iTunesArtworkProvider: ArtworkProvider {
  private static let minimumArtworkMatchScore = 1.0

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchArtwork(for identity: NormalizedTrackIdentity) async throws -> Data? {
    guard let searchURL = buildSearchURL(for: identity) else { return nil }

    let (data, response) = try await session.data(from: searchURL)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      return nil
    }

    guard let artworkURLString = bestArtworkURLString(from: data, identity: identity) else { return nil }

    let highResURLString = artworkURLString
      .replacingOccurrences(of: "100x100bb", with: "600x600bb")
    guard let artworkURL = URL(string: highResURLString) else { return nil }

    let (artworkData, artworkResponse) = try await session.data(from: artworkURL)
    guard let artworkHTTP = artworkResponse as? HTTPURLResponse,
          artworkHTTP.statusCode == 200,
          !artworkData.isEmpty else {
      return nil
    }

    return artworkData
  }

  private func buildSearchURL(for identity: NormalizedTrackIdentity) -> URL? {
    var components = URLComponents(string: "https://itunes.apple.com/search")
    let term: String
    if let album = identity.album, !album.isEmpty {
      term = "\(identity.artist) \(album)"
    } else {
      term = "\(identity.artist) \(identity.title)"
    }
    components?.queryItems = [
      URLQueryItem(name: "term", value: term),
      URLQueryItem(name: "entity", value: "album"),
      URLQueryItem(name: "limit", value: "10")
    ]
    return components?.url
  }

  /// Picks the best matching album artwork from iTunes results by comparing
  /// album name and artist against the track's metadata.
  private func bestArtworkURLString(from data: Data, identity: NormalizedTrackIdentity) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let results = json["results"] as? [[String: Any]] else {
      return nil
    }

    guard !results.isEmpty else { return nil }

    let expectedAlbum = normalize(identity.album ?? identity.title)
    let expectedArtist = normalize(identity.artist)

    var bestResult: [String: Any]?
    var bestScore = -1.0

    for result in results {
      guard result["artworkUrl100"] is String else { continue }

      var score = 0.0
      if let collectionName = result["collectionName"] as? String {
        let normalizedCollection = normalize(collectionName)
        if normalizedCollection == expectedAlbum {
          score += 2.0
        } else if normalizedCollection.contains(expectedAlbum) || expectedAlbum.contains(normalizedCollection) {
          score += 1.0
        }
      }

      if let artistName = result["artistName"] as? String {
        let normalizedArtist = normalize(artistName)
        if normalizedArtist == expectedArtist {
          score += 1.0
        } else if normalizedArtist.contains(expectedArtist) || expectedArtist.contains(normalizedArtist) {
          score += 0.5
        }
      }

      if score > bestScore {
        bestScore = score
        bestResult = result
      }
    }

    guard bestScore >= Self.minimumArtworkMatchScore else { return nil }
    return bestResult?["artworkUrl100"] as? String
  }

  /// Lowercases and converts Traditional Chinese to Simplified for comparison.
  private func normalize(_ text: String) -> String {
    let mutable = NSMutableString(string: text.lowercased())
    CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
    return mutable as String
  }
}
